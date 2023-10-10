music {

    ubyte[256] buffer

    sub init(str musicfile) {
        cx16.VERA_AUDIO_RATE = 0                ; halt playback
        cx16.VERA_AUDIO_CTRL = %10101100        ; mono 16 bit, volume 12
        repeat 1024
            cx16.VERA_AUDIO_DATA = 0            ; fill buffer with short silence
        cx16.VERA_IEN |= %00001000              ; enable AFLOW irq too

        void diskio.f_open(musicfile)
        void diskio.f_read(buffer, 256)
    }

    sub start() {
        cx16.VERA_AUDIO_RATE = 52               ; start playback at 19836 Hz

        ; NOTE: on real hardware, rate 63 (24032 Hz) also still works (and maybe even higher),
        ;       but on the emulators anything above 20 kHz seems to be problematic when loading from sdcard image.
    }

    sub stop() {
        diskio.f_close()
        cx16.VERA_AUDIO_RATE = 0
        cx16.VERA_AUDIO_CTRL = %10100000
        cx16.VERA_IEN = %00000001               ; enable only VSYNC irq
    }

    sub load_next_block() {
        void diskio.f_read(buffer, 256)
    }

    sub decode_adpcm_block() {
        ; refill the fifo buffer with one decoded adpcm block (1010 bytes of pcm data)
        uword @requirezp nibblesptr = &buffer
        adpcm.init(peekw(nibblesptr), @(nibblesptr+2))
        cx16.VERA_AUDIO_DATA = lsb(adpcm.predict)
        cx16.VERA_AUDIO_DATA = msb(adpcm.predict)
        nibblesptr += 4
        ; slightly unrolled:
        ubyte @zp nibble
        repeat 252/2 {
            unroll 2 {
                nibble = @(nibblesptr)
                adpcm.decode_nibble(nibble & 15)     ; first word
                cx16.VERA_AUDIO_DATA = lsb(adpcm.predict)
                cx16.VERA_AUDIO_DATA = msb(adpcm.predict)
                adpcm.decode_nibble(nibble>>4)       ; second word
                cx16.VERA_AUDIO_DATA = lsb(adpcm.predict)
                cx16.VERA_AUDIO_DATA = msb(adpcm.predict)
                nibblesptr++
            }
        }
    }
}


adpcm {

    ; IMA ADPCM decoder.  Supports mono and stereo streams.
    ; https://wiki.multimedia.cx/index.php/IMA_ADPCM
    ; https://wiki.multimedia.cx/index.php/Microsoft_IMA_ADPCM

    ; IMA ADPCM encodes two 16-bit PCM audio samples in 1 byte (1 word per nibble)
    ; thus compressing the audio data by a factor of 4.
    ; The encoding precision is about 13 bits per sample so it's a lossy compression scheme.
    ;
    ; HOW TO CREATE IMA-ADPCM ENCODED AUDIO? Use sox or ffmpeg like so (example):
    ; $ sox --guard source.mp3 -r 8000 -c 1 -e ima-adpcm out.wav trim 01:27.50 00:09
    ; $ ffmpeg -i source.mp3 -ss 00:01:27.50 -to 00:01:36.50  -ar 8000 -ac 1 -c:a adpcm_ima_wav -block_size 256 -map_metadata -1 -bitexact out.wav
    ; And/or use a tool such as https://github.com/dbry/adpcm-xq  (make sure to set the correct block size, -b8)


    ; IMA-ADPCM file data stream format:
    ; If the IMA data is mono, an individual chunk of data begins with the following preamble:
    ; bytes 0-1:   initial predictor (in little-endian format)
    ; byte 2:      initial index
    ; byte 3:      unknown, usually 0 and is probably reserved
    ; If the IMA data is stereo, a chunk begins with two preambles, one for the left audio channel and one for the right channel.
    ; (so we have 8 bytes of preamble).
    ; The remaining bytes in the chunk are the IMA nibbles. The first 4 bytes, or 8 nibbles,
    ; belong to the left channel and -if it's stereo- the next 4 bytes belong to the right channel.


    ubyte[] t_index = [ -1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]
    uword[] @split t_step = [
            7, 8, 9, 10, 11, 12, 13, 14,
            16, 17, 19, 21, 23, 25, 28, 31,
            34, 37, 41, 45, 50, 55, 60, 66,
            73, 80, 88, 97, 107, 118, 130, 143,
            157, 173, 190, 209, 230, 253, 279, 307,
            337, 371, 408, 449, 494, 544, 598, 658,
            724, 796, 876, 963, 1060, 1166, 1282, 1411,
            1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024,
            3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484,
            7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
            15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
            32767]

    uword @requirezp predict       ; decoded 16 bit pcm sample for first channel.
    uword @requirezp predict_2     ; decoded 16 bit pcm sample for second channel.
    ubyte @requirezp index
    ubyte @requirezp index_2
    uword @zp pstep
    uword @zp pstep_2

    sub init(uword startPredict, ubyte startIndex) {
        ; initialize first decoding channel.
        predict = startPredict
        index = startIndex
        pstep = t_step[index]
    }

    sub init_second(uword startPredict_2, ubyte startIndex_2) {
        ; initialize second decoding channel.
        predict_2 = startPredict_2
        index_2 = startIndex_2
        pstep_2 = t_step[index_2]
    }

    sub decode_nibble(ubyte nibble) {
        ; decoder for nibbles for the first channel.
        ; this is the hotspot of the decoder algorithm!
        cx16.r0s = 0                ; difference
        if nibble & %0100
            cx16.r0s += pstep
        pstep >>= 1
        if nibble & %0010
            cx16.r0s += pstep
        pstep >>= 1
        if nibble & %0001
            cx16.r0s += pstep
        pstep >>= 1
        cx16.r0s += pstep
        if nibble & %1000
            predict -= cx16.r0s
        else
            predict += cx16.r0s

        ; NOTE: the original C/Python code uses a 32 bits prediction value and clips it to a 16 bit word
        ;       but for speed reasons we only work with 16 bit words here all the time (with possible clipping error?)
        ; if predicted > 32767:
        ;    predicted = 32767
        ; elif predicted < -32767:
        ;    predicted = - 32767

        index += t_index[nibble]
        if_neg              ; was:  if index & 128
            index = 0
        else if index > len(t_step)-1
            index = len(t_step)-1
        pstep = t_step[index]
    }

    sub decode_nibble_second(ubyte nibble_2) {
        ; decoder for nibbles for the second channel.
        ; this is the hotspot of the decoder algorithm!
        cx16.r0s = 0                ; difference
        if nibble_2 & %0100
            cx16.r0s += pstep_2
        pstep_2 >>= 1
        if nibble_2 & %0010
            cx16.r0s += pstep_2
        pstep_2 >>= 1
        if nibble_2 & %0001
            cx16.r0s += pstep_2
        pstep_2 >>= 1
        cx16.r0s += pstep_2
        if nibble_2 & %1000
            predict_2 -= cx16.r0s
        else
            predict_2 += cx16.r0s

        ; NOTE: the original C/Python code uses a 32 bits prediction value and clips it to a 16 bit word
        ;       but for speed reasons we only work with 16 bit words here all the time (with possible clipping error?)
        ; if predicted > 32767:
        ;    predicted = 32767
        ; elif predicted < -32767:
        ;    predicted = - 32767

        index_2 += t_index[nibble_2]
        if_neg              ; was:  if index & 128
            index_2 = 0
        else if index_2 > len(t_step)-1
            index_2 = len(t_step)-1
        pstep_2 = t_step[index_2]
    }
}

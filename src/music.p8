music {

    ubyte[256] buffer

    sub init(str musicfile) {
        cx16.VERA_AUDIO_RATE = 0                ; halt playback
        cx16.VERA_AUDIO_CTRL = %10101111        ; mono 16 bit
        repeat 1024
            cx16.VERA_AUDIO_DATA = 0            ; fill buffer with short silence
        cx16.VERA_IEN |= %00001000              ; enable AFLOW irq too

        void diskio.f_open(musicfile)
        void diskio.f_read(buffer, 256)
    }

    sub start() {
        cx16.VERA_AUDIO_RATE = 42               ; start playback at 16021 Hz
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
        repeat 252 {
           ubyte @zp nibble = @(nibblesptr)
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


adpcm {

    ; IMA ADPCM decoder.
    ; https://wiki.multimedia.cx/index.php/IMA_ADPCM
    ; https://wiki.multimedia.cx/index.php/Microsoft_IMA_ADPCM

    ; IMA ADPCM encodes two 16-bit PCM audio samples in 1 byte (1 word per nibble)
    ; thus compressing the audio data by a factor of 4.
    ; The encoding precision is about 13 bits per sample so it's a lossy compression scheme.
    ;
    ; HOW TO CREATE IMA-ADPCM ENCODED AUDIO? Use sox or ffmpeg:
    ; $ sox --guard source.mp3 -r 8000 -c 1 -e ima-adpcm out.wav trim 01:27.50 00:09
    ; $ ffmpeg -i source.mp3 -ss 00:01:27.50 -to 00:01:36.50  -ar 8000 -ac 1 -c:a adpcm_ima_wav -block_size 256 -map_metadata -1 -bitexact out.wav
    ; Or use a tool such as https://github.com/dbry/adpcm-xq  (make sure to set the correct block size)


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

    uword @zp predict
    ubyte @requirezp index
    uword @zp pstep

    sub init(uword startPredict, ubyte startIndex) {
        predict = startPredict
        index = startIndex
        pstep = t_step[index]
    }

    sub decode_nibble(ubyte nibble) {
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
            cx16.r0s = -cx16.r0s
        predict += cx16.r0s as uword
        index += t_index[nibble]
        if_neg              ; was:  if index & 128
            index = 0
        else if index > len(t_step)-1
            index = len(t_step)-1
        pstep = t_step[index]
    }
}

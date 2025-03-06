.PHONY:  all clean zip run-me run-ds sdcard

PROG8C ?= prog8c       # if that fails, try this alternative (point to the correct jar file location): java -jar $(PROG8C).jar
PYTHON ?= python
ZIP ?= zip
SOX ?= sox
ADPCMXQ ?= adpcm-xq
FFMPEG ?= ffmpeg


all:  MEDEMO.PRG  DSDEMO.PRG

sdcard: all
	# mmd -D s x:MEDEMO x:DSDEMO
	mcopy -D o MEDEMO.PRG ME-* x:MEDEMO
	mcopy -D o DSDEMO.PRG DS-* x:DSDEMO

clean:
	rm -f *.prg *.PRG *.asm *.vice-* *.BIN *.PAL *.ADPCM *.zip *.7z *.zip src/melyrics.p8 src/dslyrics.p8

run-me:  MEDEMO.PRG
	# PULSE_LATENCY_MSEC=20 box16 -scale 2 -run -prg $<
	PULSE_LATENCY_MSEC=20 x16emu -abufs 16 -scale 2 -quality best -run -prg $<

run-ds:  DSDEMO.PRG
	# PULSE_LATENCY_MSEC=20 box16 -scale 2 -run -prg $<
	PULSE_LATENCY_MSEC=20 x16emu -abufs 16 -scale 2 -quality best -run -prg $<

MEDEMO.PRG: src/medemo.p8 src/music.p8 src/demo_engine.p8 ME-TITLESCREEN.BIN ME-TITLESCREEN.PAL ME-DEMOSCREEN.BIN ME-DEMOSCREEN.PAL ME-FONT.BIN ME-MUSIC.ADPCM src/melyrics.p8
	$(PROG8C) $< -target cx16 
	@mv medemo.prg MEDEMO.PRG

DSDEMO.PRG: src/dsdemo.p8 src/music.p8 src/demo_engine.p8 DS-TITLESCREEN.BIN DS-TITLESCREEN.PAL DS-DEMOSCREEN.BIN DS-DEMOSCREEN.PAL DS-FONT.BIN DS-MUSIC.ADPCM src/dslyrics.p8
	$(PROG8C) $< -target cx16 
	@mv dsdemo.prg DSDEMO.PRG

ME-DEMOSCREEN.BIN ME-DEMOSCREEN.PAL ME-TITLESCREEN.BIN ME-TITLESCREEN.PAL ME-FONT.BIN: images/title-hires.png images/demo-lores.png src/convertimages.py
	$(PYTHON) src/convertimages.py

DS-DEMOSCREEN.BIN DS-DEMOSCREEN.PAL DS-TITLESCREEN.BIN DS-TITLESCREEN.PAL DS-FONT.BIN: images/dstitle-hires.png images/dsdemo-lores.png src/convertimages.py
	$(PYTHON) src/convertimages.py

src/melyrics.p8: src/convertlyrics.py src/melyrics.txt ME-MUSIC.ADPCM
	$(PYTHON) src/convertlyrics.py src/melyrics.txt $@ ME-MUSIC.ADPCM

src/dslyrics.p8: src/convertlyrics.py src/dslyrics.txt DS-MUSIC.ADPCM
	$(PYTHON) src/convertlyrics.py src/dslyrics.txt $@ DS-MUSIC.ADPCM

ME-MUSIC.ADPCM: music/chvrches-warning-call.mp3
	$(SOX) $< -c 1 -r 19836 music.temp.wav
	$(ADPCMXQ) -y -b8 -4 -r music.temp.wav $@
	@rm music.temp.wav

DS-MUSIC.ADPCM: music/chvrches-deathstranding.mp3
	$(SOX) $< -c 1 -r 19836 music.temp.wav
	$(ADPCMXQ) -y -b8 -4 -r music.temp.wav $@
	@rm music.temp.wav

zip: all
	@rm -f medemo.zip dsdemo.zip
	@$(ZIP) medemo.zip MEDEMO.PRG ME-TITLESCREEN.* ME-DEMOSCREEN.* ME-FONT.* ME-MUSIC.ADPCM
	@$(ZIP) dsdemo.zip DSDEMO.PRG DS-TITLESCREEN.* DS-DEMOSCREEN.* DS-FONT.* DS-MUSIC.ADPCM

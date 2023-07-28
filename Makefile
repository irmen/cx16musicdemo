.PHONY:  all clean zip run-me run-ds sdcard

all:  MEDEMO.PRG  DSDEMO.PRG

sdcard: all
	# mmd -D s x:MEDEMO x:DSDEMO
	mcopy -D o MEDEMO.PRG ME-* x:MEDEMO
	mcopy -D o DSDEMO.PRG DS-* x:DSDEMO

clean:
	rm -f *.prg *.PRG *.asm *.vice-* *.BIN *.PAL *.ADPCM *.zip *.7z *.zip src/melyrics.p8 src/dslyrics.p8

run-me:  MEDEMO.PRG
	# PULSE_LATENCY_MSEC=20 box16 -scale 2 -run -prg $<
	PULSE_LATENCY_MSEC=20 x16emu -scale 2 -quality best -run -prg $<

run-ds:  DSDEMO.PRG
	# PULSE_LATENCY_MSEC=20 box16 -scale 2 -run -prg $<
	PULSE_LATENCY_MSEC=20 x16emu -scale 2 -quality best -run -prg $<

MEDEMO.PRG: src/medemo.p8 src/music.p8 src/demo_engine.p8 ME-TITLESCREEN.BIN ME-TITLESCREEN.PAL ME-DEMOSCREEN.BIN ME-DEMOSCREEN.PAL ME-FONT.BIN ME-MUSIC.ADPCM src/melyrics.p8
	p8compile $< -target cx16 
	@mv medemo.prg MEDEMO.PRG

DSDEMO.PRG: src/dsdemo.p8 src/music.p8 src/demo_engine.p8 DS-TITLESCREEN.BIN DS-TITLESCREEN.PAL DS-DEMOSCREEN.BIN DS-DEMOSCREEN.PAL DS-FONT.BIN DS-MUSIC.ADPCM src/dslyrics.p8
	p8compile $< -target cx16 
	@mv dsdemo.prg DSDEMO.PRG

ME-DEMOSCREEN.BIN ME-DEMOSCREEN.PAL ME-TITLESCREEN.BIN ME-TITLESCREEN.PAL ME-FONT.BIN: images/title-hires.png images/demo-lores.png src/convertimages.py
	python src/convertimages.py

DS-DEMOSCREEN.BIN DS-DEMOSCREEN.PAL DS-TITLESCREEN.BIN DS-TITLESCREEN.PAL DS-FONT.BIN: images/dstitle-hires.png images/dsdemo-lores.png src/convertimages.py
	python src/convertimages.py

src/melyrics.p8: src/convertlyrics.py src/melyrics.txt ME-MUSIC.ADPCM
	python src/convertlyrics.py src/melyrics.txt $@ ME-MUSIC.ADPCM

src/dslyrics.p8: src/convertlyrics.py src/dslyrics.txt DS-MUSIC.ADPCM
	python src/convertlyrics.py src/dslyrics.txt $@ DS-MUSIC.ADPCM

ME-MUSIC.ADPCM: music/chvrches-warning-call.mp3
	sox $< -c 1 -r 16021 music.temp.wav
	adpcm-xq -y -b8 -4 -r music.temp.wav $@
	@rm music.temp.wav

DS-MUSIC.ADPCM: music/chvrches-deathstranding.mp3
	sox $< -c 1 -r 16021 music.temp.wav
	adpcm-xq -y -b8 -4 -r music.temp.wav $@
	@rm music.temp.wav

zip: all
	@rm -f medemo.zip dsdemo.zip
	@7z a medemo.zip MEDEMO.PRG ME-TITLESCREEN.* ME-DEMOSCREEN.* ME-FONT.* ME-MUSIC.ADPCM
	@7z a dsdemo.zip DSDEMO.PRG DS-TITLESCREEN.* DS-DEMOSCREEN.* DS-FONT.* DS-MUSIC.ADPCM

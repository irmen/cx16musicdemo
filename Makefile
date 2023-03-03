.PHONY:  all clean emu zip

all:  MEDEMO.PRG

clean:
	rm -f *.prg *.PRG *.asm *.vice-* *.BIN *.PAL *.ADPCM *.zip *.7z *.zip src/lyrics.p8

emu:  MEDEMO.PRG
	# PULSE_LATENCY_MSEC=20 box16 -scale 2 -run -prg $<
	PULSE_LATENCY_MSEC=20 x16emu -scale 2 -quality best -run -prg $<

MEDEMO.PRG: src/medemo.p8 src/adpcm.p8 src/lyrics.p8 ME-TITLESCREEN.BIN ME-TITLESCREEN.PAL ME-DEMOSCREEN.BIN ME-DEMOSCREEN.PAL ME-FONT.BIN ME-MUSIC.ADPCM
	p8compile $< -target cx16
	mv medemo.prg MEDEMO.PRG

ME-DEMOSCREEN.BIN ME-DEMOSCREEN.PAL ME-TITLESCREEN.BIN ME-TITLESCREEN.PAL ME-FONT.BIN: images/title-hires.png images/demo-lores.png src/convertimages.py
	python src/convertimages.py

src/lyrics.p8: src/convertlyrics.py src/lyrics.txt
	python src/convertlyrics.py > $@

ME-MUSIC.ADPCM: music/chvrches-warning-call.mp3
	sox $< -c 1 -r 16021 music.temp.wav
	adpcm-xq -y -b8 -4 -r music.temp.wav $@
	rm music.temp.wav

zip: all
	rm -f medemo.zip
	7z a medemo.zip MEDEMO.PRG ME-TITLESCREEN.* ME-DEMOSCREEN.* ME-FONT.* ME-MUSIC.ADPCM

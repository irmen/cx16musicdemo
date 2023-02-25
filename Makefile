.PHONY:  all clean emu zip

all:  MEDEMO.PRG

clean:
	rm -f *.prg *.PRG *.asm *.vice-* *.BIN *.PAL *.zip *.7z lyrics.p8

emu:  MEDEMO.PRG
	PULSE_LATENCY_MSEC=20 box16 -scale 2 -run -prg $<
	# PULSE_LATENCY_MSEC=20 x16emu -scale 2 -quality best -run -prg $<

MEDEMO.PRG: src/medemo.p8 src/lyrics.p8 ME-TITLESCREEN.BIN ME-TITLESCREEN.PAL ME-DEMOSCREEN.BIN ME-DEMOSCREEN.PAL
	p8compile $< -target cx16
	mv medemo.prg MEDEMO.PRG

ME-DEMOSCREEN.BIN ME-DEMOSCREEN.PAL ME-TITLESCREEN.BIN ME-TITLESCREEN.PAL: images/title-hires.png images/demo-lores.png src/convertimages.py
	python src/convertimages.py

src/lyrics.p8: src/convertlyrics.py src/lyrics.txt
	python src/convertlyrics.py > $@

zip: all
	rm -f medemo.7z
	7z a medemo.7z MEDEMO.PRG ME-TITLESCREEN* ME-DEMOSCREEN*

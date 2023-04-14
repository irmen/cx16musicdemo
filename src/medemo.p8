%import textio
%import cx16diskio
%import diskio
%import melyrics
%import demo_engine

; Demo: CHVRCHES - Mirror's Edge Catalyst


; NOTE: there is no error handling for missing data files.
;       everything is supposed to be there on the sd card with proper names.


main {

    sub start() {

        sys.set_irqd()
        cx16.CINV = &interrupts.handler     ; cannot use cx16.set_irq() because we're dealing with AFLOW irqs as well
        sys.clear_irqd()

        prepare_title()
        screen.fade_in(16)
        repeat 240 screen.waitvsync()
        screen.fade_out(16)

        prepare_demo()
        music.init("me-music.adpcm")
        screen.fade_in(0)
        music.start()
        demo_engine.play_demo()
        screen.fade_out(0)
        music.stop()

        show_thanks()

        repeat {
        }
    }

    sub prepare_title() {
        palette.set_all_black()
        screen.clear_vram()
        screen.highres16()
        void cx16diskio.vload_raw("me-titlescreen.bin", 8, 0, 0)
        void diskio.load_raw(8, "me-titlescreen.pal", screen.palette_ptr)
        screen.init_fade_palette()
    }

    sub prepare_demo() {
        palette.set_all_black()
        screen.clear_vram()
        screen.lores256()
        void cx16diskio.vload_raw("me-demoscreen.bin", 8, 0, 0)
        void diskio.load_raw(8, "me-demoscreen.pal", screen.palette_ptr)
        void cx16diskio.vload_raw("me-font.bin", 8, 1, $f000)
        screen.text_colors = [$f00, $d02, $b13, $924, $635, $347]     ; set demo-specific text tiles fade in/out palette
        screen.init_fade_palette()
    }

    sub show_thanks() {
        screen.reset_video()
        void cx16.screen_mode(1, false)   ; 80x30  text mode
        ; don't set palette yet, we'll fade it in later
        ;palette.set_color(0, $000)
        ;palette.set_color(1, $fff)
        ;palette.set_color(2, $f00)
        txt.lowercase()
        txt.color2(2,1)     ; red on white
        txt.clear_screen()
        txt.plot(10,6)
        txt.print("You have been listening to")
        txt.plot(15, 11)
        txt.print("'Warning Call' by CHVRCHES")
        txt.plot(15, 13)
        txt.print("from the Mirror's Edge Catalyst game")
        txt.plot(18, 20)
        txt.print("(music format 16 kHz mono adpcm)")
        txt.color2(1,2)     ; white on red
        txt.plot(0, 0)
        repeat 80*3 {
            txt.spc()
        }
        txt.plot(0, 25)
        repeat 80*4 {
            txt.spc()
        }
        txt.plot(30, 26)
        txt.print("created by DesertFish in Prog8")
        txt.plot(30, 27)
        txt.print("inspired by:  https://youtu.be/fB4gjiMVKFI")

        pokew(screen.palette_ptr, $000)
        pokew(screen.palette_ptr+2, $fff)
        pokew(screen.palette_ptr+4, $f00)
        screen.init_fade_palette()
        screen.fade_in(3)
    }

}

%import cx16diskio
%import diskio
%import palette
%import string
%import music
%import melyrics

; NOTE: there is no error handling for missing data files.
;       everything is supposed to be there on the sd card with proper names.


main {

    sub start() {

        sys.set_irqd()
        cx16.CINV = &interrupts.handler     ; cannot use cx16.set_irq() because we're dealing with AFLOW irqs as well
        sys.clear_irqd()

        screen.prepare_title()
        screen.fade_in(16)
        repeat 180 screen.waitvsync()
        screen.fade_out(16)

        screen.prepare_demo()
        music.init("me-music.adpcm")
        screen.fade_in(0)
        music.start()
        play_demo()
        screen.fade_out(0)
        music.stop()

        screen.thanks()

        repeat {
        }
    }

    sub play_demo() {
        ubyte line_idx
        interrupts.vsync_counter=0
        interrupts.text_scroll_enabled = true

        repeat {
            uword timestamp = lyrics.timestamps[line_idx]
            if timestamp==$ffff
                break  ; end of lyrics sequence.

            uword text = lyrics.lines[line_idx]
            uword length = string.length(text)
            uword timestamp_off = interrupts.vsync_counter + 60 + length*12

            while interrupts.vsync_counter < timestamp  {
                if timestamp_off {
                    if interrupts.vsync_counter >= timestamp_off {
                        timestamp_off=0
                        interrupts.text_color = 0
                        interrupts.text_fade_direction = 1
                    }
                }

                if interrupts.aflow_semaphore==0 {
                    interrupts.aflow_semaphore++
                    music.load_next_block()
                }
            }

            screen.clear_lyrics_text_screen()
            palette.set_color(127, screen.text_colors[len(screen.text_colors)-1])
            cx16.VERA_L1_HSCROLL_L = 0
            cx16.VERA_L1_VSCROLL_L = 120
            screen.text_at(4,10,text)
            interrupts.text_color = len(screen.text_colors)-1
            interrupts.text_fade_direction = 2
            line_idx++
        }

        interrupts.text_scroll_enabled = false
    }
}


interrupts {
    const ubyte FADE_SPEED = 2
    const ubyte HSCROLL_SPEED = 3
    const ubyte VSCROLL_SPEED = 6
    uword vsync_counter
    ubyte vsync_semaphore = 1
    ubyte aflow_semaphore = 1
    ubyte text_color
    ubyte text_fade_direction = 0      ; 1=fade out (++), 2=fade in (--)
    ubyte hscroll_cnt = 0
    ubyte vscroll_cnt = 0
    ubyte fade_count = FADE_SPEED
    bool text_scroll_enabled = false

    sub handler() {
        if cx16.VERA_ISR & %00001000 {
            ; AFLOW irq occurred, refill buffer
            aflow_semaphore=0
            music.decode_adpcm_block()
        } else if cx16.VERA_ISR & %00000001 {
            vsync_semaphore=0
            vsync_counter++
            cx16.push_vera_context()
            when text_fade_direction {
                1 -> {
                    palette.set_color(127, screen.text_colors[text_color])
                    fade_count--
                    if_neg {
                        fade_count = FADE_SPEED
                        text_color++
                        if text_color==len(screen.text_colors) {
                            text_fade_direction=0
                            screen.clear_lyrics_text_screen()
                        }
                    }
                }
                2 -> {
                    palette.set_color(127, screen.text_colors[text_color])
                    fade_count--
                    if_neg {
                        fade_count = FADE_SPEED
                        text_color--
                        if_neg
                            text_fade_direction=0
                    }
                }
            }

            if text_scroll_enabled {
                hscroll_cnt--
                if_neg {
                    hscroll_cnt = HSCROLL_SPEED
                    cx16.VERA_L1_HSCROLL_L++
                }
                vscroll_cnt--
                if_neg {
                    vscroll_cnt = VSCROLL_SPEED
                    if cx16.VERA_L1_VSCROLL_L
                        cx16.VERA_L1_VSCROLL_L--
                }
            }

            cx16.pop_vera_context()

            cx16.VERA_ISR = %00000001
        }

        %asm {{
            ply
            plx
            pla
            rti
        }}
    }
}


screen {
    uword palette_ptr = memory("palette", 256*2, 0)

    uword[6] text_colors = [$f00, $d02, $b13, $924, $635, $347]
    ubyte[256] reds
    ubyte[256] greens
    ubyte[256] blues
    ubyte[256] reds_target
    ubyte[256] greens_target
    ubyte[256] blues_target
    ubyte @zp color

    sub prepare_title() {
        palette.set_all_black()
        clear_vram()
        highres16()
        void cx16diskio.vload_raw("me-titlescreen.bin", 8, 0, 0)
        void diskio.load_raw(8, "me-titlescreen.pal", palette_ptr)
        init_fade_palette()
    }

    sub prepare_demo() {
        palette.set_all_black()
        clear_vram()
        lores256()
        void cx16diskio.vload_raw("me-demoscreen.bin", 8, 0, 0)
        void diskio.load_raw(8, "me-demoscreen.pal", palette_ptr)
        void cx16diskio.vload_raw("me-font.bin", 8, 1, $f000)
        init_fade_palette()
    }

    sub reset_video() {
        cx16.r15L = cx16.VERA_DC_VIDEO & %00000111 ; retain chroma + output mode
        c64.CINT()
        cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11111000) | cx16.r15L
    }

    sub clear_lyrics_text_screen() {
        uword @zp vaddr = $b000
        cx16.vaddr(1, $b000, 0, true)
        repeat 32*32 {
            cx16.VERA_DATA0 = sc:' '
            cx16.VERA_DATA0 = 127     ; 127 is the text color RED
        }
    }

    sub text_at(ubyte col, ubyte row, str text) {
        sub get_vaddr() -> uword {
            return $b000 + col*2 + row*$0040
        }
        cx16.vaddr(1, get_vaddr(), 0, true)
        while @(text) {
            if @(text)==sc:'|' {
                text++
                row+=2
                cx16.vaddr(1, get_vaddr(), 0, true)
            }
            cx16.VERA_DATA0 = @(text)
            cx16.VERA_DATA0 = 127        ; 127 is text color RED
            text++
        }
    }

    sub thanks() {
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

        pokew(palette_ptr, $000)
        pokew(palette_ptr+2, $fff)
        pokew(palette_ptr+4, $f00)
        init_fade_palette()
        fade_in(3)
    }

    sub init_fade_palette() {
        for color in 0 to 255 {
            reds[color] = 0
            greens[color] = 0
            blues[color] = 0
            cx16.r0 = peekw(palette_ptr + color*$0002)
            reds_target[color] = cx16.r0H
            greens_target[color] = cx16.r0L >> 4
            blues_target[color] = cx16.r0L & %1111
        }
    }

    sub fade_in(ubyte num_colors) {
        repeat 16 {
            waitvsync()
            waitvsync()
            waitvsync()
            for color in 0 to num_colors-1 {
                update_palette_entry()
                if reds[color]!=reds_target[color]
                    reds[color]++
                if greens[color]!=greens_target[color]
                    greens[color]++
                if blues[color]!=blues_target[color]
                    blues[color]++
            }
        }
    }

    sub fade_out(ubyte num_colors) {
        repeat 16 {
            waitvsync()
            waitvsync()
            waitvsync()
            for color in 0 to num_colors-1 {
                update_palette_entry()
                if reds[color]
                    reds[color]--
                if greens[color]
                    greens[color]--
                if blues[color]
                    blues[color]--
            }
        }
    }

    sub update_palette_entry() {
        palette.set_color(color, mkword(reds[color], greens[color]<<4 | blues[color]))
    }

    sub clear_vram() {
        cx16.VERA_CTRL=0
        cx16.VERA_ADDR_L=0
        cx16.VERA_ADDR_M=0
        cx16.VERA_ADDR_H=%00010000  ; autoincrement
        cx16.memory_fill(&cx16.VERA_DATA0, 65535, 0)    ; first clear screen
        cx16.memory_fill(&cx16.VERA_DATA0, 64000, 0)    ; first clear screen second half
    }

    sub highres16() {
        ; 640x400 16 colors
        cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11001111) | %00100000      ; enable only layer 1
        cx16.VERA_DC_HSCALE = 128
        cx16.VERA_DC_VSCALE = 128
        cx16.VERA_CTRL = %00000010
        cx16.VERA_DC_VSTART = 20
        cx16.VERA_DC_VSTOP = 400 /2 -1 + 20 ; clip off screen that overflows vram
        cx16.VERA_L1_CONFIG = %00000110     ; 16 colors bitmap mode
        cx16.VERA_L1_MAPBASE = 0
        cx16.VERA_L1_TILEBASE = %00000001   ; hires
    }

    sub lores256() {
        ; 320x240 256 colors + text layer
        screen.reset_video()
        void cx16.screen_mode($80, false)
        screen.clear_lyrics_text_screen()
        cx16.VERA_L1_CONFIG |= %00001000    ; enable T256C
        cx16.VERA_L1_TILEBASE = %11111011   ; 16x16 tiles
        cx16.VERA_L1_CONFIG &= %00001111    ; 32x32 tile map
    }

    asmsub waitvsync() {
        %asm {{
-           wai
            lda  interrupts.vsync_semaphore
            bne  -
            inc  interrupts.vsync_semaphore
            rts
        }}
    }
}

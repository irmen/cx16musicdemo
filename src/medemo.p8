%import cx16diskio
%import diskio
%import palette
%import lyrics
%import string

%zeropage basicsafe

main {

    sub start() {
        txt.print_uw(lyrics.LINECOUNT)
        txt.print_uw(lyrics.timestamps)
        txt.print_uw(lyrics.lines)

;        screen.prepare_title()
;        screen.fade_in(16)
;        sys.wait(180)
;        screen.fade_out(16)

        screen.prepare_demo()
        screen.fade_in(0)
        play_song()
        sys.wait(180)
        screen.fade_out(0)

        screen.thanks()

        repeat {
        }
    }

    sub play_song() {
        c64.SETTIM(0,0,0)
        ubyte line_idx

        repeat {
            uword timestamp = lyrics.timestamps[line_idx]
            if timestamp==$ffff
                break
            uword text = lyrics.lines[line_idx]
            uword length = string.length(text)
            uword timestamp_off = c64.RDTIM16() + 60 + length*12
            while c64.RDTIM16() != timestamp  {
                if c64.RDTIM16() == timestamp_off {
                    timestamp_off=0
                    txt.clear_screen()
                }
                ; wait till the timestamp hits
            }

            txt.clear_screen()
            txt.plot(10,10)
            txt.print(text)
            line_idx++
        }

    }
}


screen {
    uword palette_ptr = memory("palette", 256*2, 0)

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
        init_fade_palette()
    }

    sub thanks() {
        c64.CINT()  ; restore video and charset
        void cx16.screen_mode(1, false)   ; 80x30  text mode
        ; don't set palette yet, we'll fade it in later
        ;palette.set_color(0, $000)
        ;palette.set_color(1, $fff)
        ;palette.set_color(2, $f00)
        txt.lowercase()
        txt.color2(2,1)     ; red on white
        txt.clear_screen()
        txt.plot(5,6)
        txt.print("You have been listening to")
        txt.plot(10, 11)
        txt.print("'Warning Call' by CHVRCHES")
        txt.plot(10, 13)
        txt.print("from the Mirror's Edge Catalyst game")
        txt.color2(1,2)     ; white on red
        txt.plot(0, 0)
        repeat 160 {
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
            sys.waitvsync()
            sys.waitvsync()
            sys.waitvsync()
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
            sys.waitvsync()
            sys.waitvsync()
            sys.waitvsync()
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
        ; 320x240 256 colors
        c64.CINT()
        void cx16.screen_mode($80, false)
        cx16.VERA_L1_CONFIG |= %00001000     ; enable T256C
        txt.color2(%1111, %0111)    ; select text color %01111111 = 127

;        cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11001111) | %00100000      ; enable only layer 1
;        cx16.VERA_DC_HSCALE = 64
;        cx16.VERA_DC_VSCALE = 64
;        cx16.VERA_CTRL = %00000010
;        cx16.VERA_DC_VSTART = 0
;        cx16.VERA_DC_VSTOP = 480 /2
;        cx16.VERA_L1_CONFIG = %00000111
;        cx16.VERA_L1_MAPBASE = 0
;        cx16.VERA_L1_TILEBASE = 0   ; lores
    }
}
%import palette
%import strings
%import music

; This file contains the generic routines to play the actual demo.
; It also needs a module imported that defines the lyrics,
; but that is done in the main program.


demo_engine {

    ubyte lyrics_speed          ; depends on how fast the lyrics in the song are sung
    ubyte lyrics_base_delay     ; depends on how fast the lyrics in the song are sung


    sub play_demo() {
        ubyte line_idx
        uword blocks_counter = 0
        ; interrupts.vsync_counter = 0    ; not used anymore, lyrics timings are now synced on audio block counter
        interrupts.text_scroll_enabled = true

        repeat {
            uword timestamp_next = lyrics.timestamps[line_idx]
            uword timestamp_off

            if timestamp_next==$ffff
                break  ; hard end of lyrics sequence.

            ; wait until it is time to show the line
            while blocks_counter < timestamp_next  {
                if timestamp_off!=0 {
                    if blocks_counter >= timestamp_off {
                        timestamp_off = 0
                        interrupts.text_color = 0
                        interrupts.text_fade_direction = 1
                    }
                }

                if interrupts.aflow_semaphore==0 {
                    interrupts.aflow_semaphore++
                    music.load_next_block()
                    blocks_counter++
                }
            }

            ; show next line of text
            uword text = lyrics.lines[line_idx]
            uword length = strings.length(text)
            timestamp_off = blocks_counter + length*lyrics_speed + lyrics_base_delay
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


screen {
    uword palette_ptr = memory("palette", 256*2, 0)

    uword[6] @nosplit text_colors        ; these have to be set in the main demo program  (nosplit because an array literal gets copied into it)

    sub reset_video() {
        ; not calling cbm.CINT() because that resets (flashes!) the palette
        cx16.VERA_CTRL = %00000010
        cx16.VERA_DC_VSTART = 0
        cx16.VERA_DC_VSTOP = 480/2
        cx16.VERA_DC_HSTART = 0
        cx16.VERA_DC_HSTOP = 160
        cx16.VERA_CTRL = 0
        cx16.VERA_L0_CONFIG = 0
        cx16.VERA_L0_MAPBASE = 0
        cx16.VERA_L0_TILEBASE = 0
        cx16.VERA_L1_CONFIG = $60
        cx16.VERA_L1_MAPBASE = $d8
        cx16.VERA_L1_TILEBASE = $f8
        cx16.VERA_DC_HSCALE = 128
        cx16.VERA_DC_VSCALE = 128
        cx16.VERA_L0_HSCROLL_L = 0
        cx16.VERA_L0_HSCROLL_H = 0
        cx16.VERA_L0_VSCROLL_L = 0
        cx16.VERA_L0_VSCROLL_H = 0
        cx16.VERA_L1_HSCROLL_L = 0
        cx16.VERA_L1_HSCROLL_H = 0
        cx16.VERA_L1_VSCROLL_L = 0
        cx16.VERA_L1_VSCROLL_H = 0
    }

    sub clear_lyrics_text_screen() {
        cx16.vaddr(1, $b000, 0, 1)
        repeat 32*32 {
            cx16.VERA_DATA0 = sc:' '
            cx16.VERA_DATA0 = 127     ; 127 is the text color RED
        }
    }

    sub text_at(ubyte col, ubyte row, str text) {
        sub get_vaddr() -> uword {
            return $b000 + col*2 + row*$0040
        }
        cx16.vaddr(1, get_vaddr(), 0, 1)
        while @(text) !=0 {
            if @(text)==sc:'|' {
                text++
                row+=2
                cx16.vaddr(1, get_vaddr(), 0, 1)
            }
            cx16.VERA_DATA0 = @(text)
            cx16.VERA_DATA0 = 127        ; 127 is text color RED
            text++
        }
    }

    sub init_fade_palette() {
        palette.set_all_black()
    }

    sub fade_in(ubyte last_col_index) {
        do {
            waitvsync()
            waitvsync()
            waitvsync()
            bool changed = palette.fade_step_colors(0, last_col_index, palette_ptr)
        } until not changed
    }

    sub fade_out(ubyte last_col_index) {
        do {
            waitvsync()
            waitvsync()
            waitvsync()
            bool changed = palette.fade_step_multi(0, last_col_index, $000)
        } until not changed
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
            lda  p8b_interrupts.p8v_vsync_semaphore
            bne  -
            inc  p8b_interrupts.p8v_vsync_semaphore
            rts
        }}
    }
}


interrupts {
    const ubyte FADE_SPEED = 2
    const ubyte HSCROLL_SPEED = 3
    const ubyte VSCROLL_SPEED = 5
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
        if cx16.VERA_ISR & %00001000 !=0 {
            ; AFLOW irq occurred, refill buffer
            aflow_semaphore=0
            music.decode_adpcm_block()
        } else if cx16.VERA_ISR & %00000001 !=0 {
            vsync_semaphore=0
            vsync_counter++
            cx16.save_vera_context()
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
                    if cx16.VERA_L1_VSCROLL_L!=0
                        cx16.VERA_L1_VSCROLL_L--
                }
            }

            cx16.restore_vera_context()

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

;
; geoplay-asm1.s - GeoPlayer assembler core (revised / optimized version)
;
; Based on util.s - Some utility functions
;
; (c) 2009 Thomas 'skoe' Giesel
;
; This software is provided 'as-is', without any express or implied
; warranty.  In no event will the authors be held liable for any damages
; arising from the use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
;
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;
; NOTE: this is an ALTERED source version (GeoPlayer, revised).
;
; GeoRAM window: $de00-$deff, $dffe = page (6 bit), $dfff = block (16K).
; Sample data lives in GeoRAM from page 0 upwards (8 bit unsigned mono, or
; 4 bit pre-shifted for SID output at 16/22 kHz).
; The last 16 bytes of the GeoRAM are reserved for metadata:
;   $def6 sample rate index, $def7 output (0 SID / 1 DigiMax),
;   $def8-$defb byte rate, $defc-$deff data size.
;

.segment "LOADADDR"
        .byte 01,08

; BASIC stub: 10 SYS 16384 -> RUN starts the player at $4000
.segment "BASICSTUB"
        .word   * + 12          ; link -> end-of-program marker
        .word   10              ; line number
        .byte   $9e, " 16384"   ; SYS 16384
        .byte   0               ; end of line
        .word   0               ; end of program

.segment "MUSIC"
        .incbin "ILoveDMC.sid",$7e

.export _TITLEMAP
.segment "TITLEMAP"
_TITLEMAP:      .incbin "geoPlayerLogo.bin"

.export _ATTRIBUTES
.segment "ATTRIBUTES"
_ATTRIBUTES:    .incbin "geoPlayerLogoAttrib.bin"

.segment "INSTRUCTIONS"
instructions:   .incbin "instructions.txt"
                .byte 0                 ; text terminator

.segment "SUPERMON"
supermon:       .incbin "supermon+3400.prg",2

.export _SIDINIT
.export _SIDPLAY
.export _STOPSIDP

DITHER     = 1              ; 1 = dither 8 bit -> 4 bit samples when loading
                            ; 0 = plain truncation (slightly faster upload)
SIDLOADPOS = $1000
SIDPLAYPOS = $1003

.importzp       ptr1, ptr2, ptr3, tmp1
.import         popax
.import         _utilStr

.export buffer_start_hi: absolute
.export buffer_len_hi: absolute
buffer_start_hi   = $68             ; see buffer.h
buffer_len_hi     = 16              ; see EASY_SPLIT_MAX_EXO_OFFSET and buffer.h

; zero page used by the player (BASIC FAC area, free while BASIC is off)
playidx  = $61     ; 32 bit byte position: +0 index in page, +1/+2 page number
lobyte   = $65
pageflag = $66
geopglo  = $67     ; GeoRAM registers for the NEXT page (prepared by main loop)
geopghi  = $68

chrin     = $FFCF
getin     = $FFE4
plot      = $FFF0
chrout    = $FFD2
readst    = $FFB7
chkin     = $FFC6
close     = $FFC3
clrchn    = $FFCC

colorData = $e000
screenRam = $0400
colorRam  = $d800

ST        = $90             ; Kernal I/O status word

.rodata
hexDigits:
        .byte "0123456789ABCDEF"

.code

; =============================================================================
; variables
; =============================================================================
xpos:       .byte 0
dotchar:    .byte $fb
cnt:        .res 2
partsz:     .byte 0
needshift:  .byte 0
cvtmp:      .byte 0
saved01:    .byte 0
lastidx:    .byte 0
srcpg:      .byte 0
oldborder:  .byte 0
oldbg:      .byte 0
curpage:    .word 0
playing:    .byte 1         ; playing state
repeat:     .byte 0         ; repeat state
scopetick:  .byte 0
_lastblk:   .byte $7f       ; last 16K block of the detected GeoRAM

.export _maxmem             ; max sample bytes: bytes 0-2 (24 bit), byte 3 free
_maxmem:    .byte $f0,$ff,$1f,$00
.export _byterate
_byterate:  .res 4
.export _subchnk
_subchnk:   .res 4          ; "fmt " or "data"
.export _subchsz
_subchsz:   .res 4
datasz:     .res 4
.export _sidDigimax
_sidDigimax: .byte 0
.export _sampleRate
_sampleRate: .byte 0
.export _koalaFlag
_koalaFlag: .byte 0         ; set when the bitmap area ($2000-$3fff) is in use
koalaFlag = _koalaFlag
.export _georam
_georam:    .byte 0

; =============================================================================
; file / string helpers
; =============================================================================

.export _utilReadByte
_utilReadByte:
        jsr     chrin
        rts

; -----------------------------------------------------------------------------
; Like cbm_read, but without calling CHKIN/CLRCH. The caller must have
; redirected the input already.
;
; int __fastcall__ utilReadNormalFile(void* buffer, unsigned int size);
; -----------------------------------------------------------------------------
.export _utilReadNormalFile
_utilReadNormalFile:
        eor     #$FF
        sta     ptr1
        txa
        eor     #$FF
        sta     ptr1 + 1        ; Save -size-1

        jsr     popax
        sta     ptr2
        stx     ptr2 + 1        ; Save buffer

        lda     #$00
        sta     ptr3
        sta     ptr3 + 1
        beq     utilRead3       ; Branch always

utilRead1:
        lda     ST              ; Status ok?
        bne     utilRead4

        jsr     chrin           ; Read next char from file
        sta     tmp1            ; Save it for later

        lda     ST
        and     #$BF
        bne     utilRead4

        lda     tmp1
        ldy     #0
        sta     (ptr2),y        ; Save read byte

        inc     ptr2
        bne     utilRead2
        inc     ptr2+1          ; ++buffer;

utilRead2:
        inc     ptr3
        bne     utilRead3
        inc     ptr3 + 1        ; ++bytesread;
utilRead3:
        inc     ptr1
        bne     utilRead1
        inc     ptr1 + 1
        bne     utilRead1

utilRead4:
        lda     ptr3
        ldx     ptr3 + 1        ; return bytesread;

        rts

; -----------------------------------------------------------------------------
; void __fastcall__ utilAppendHex1(uint8_t n);   append one hex digit
; -----------------------------------------------------------------------------
.export _utilAppendHex1
_utilAppendHex1:
        pha             ; remember n

        jsr _utilGetStringEnd
        sta ptr1
        stx ptr1 + 1
        pla
        pha

        ldy #0
utilAppendHex1_:
        pla
        and #$0f
        tax
        lda hexDigits, x
        sta (ptr1), y

        lda #0          ; 0-termination
        iny
        sta (ptr1), y

        rts

; -----------------------------------------------------------------------------
; void __fastcall__ utilAppendHex2(uint8_t n);   append two hex digits
; -----------------------------------------------------------------------------
.export _utilAppendHex2
_utilAppendHex2:
        pha             ; remember n

        jsr _utilGetStringEnd
        sta ptr1
        stx ptr1 + 1
        pla

        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda hexDigits, x
        ldy #0
        sta (ptr1), y

        iny
        bne utilAppendHex1_ ; always

; -----------------------------------------------------------------------------
; void __fastcall__ utilAppendChar(char c);
; -----------------------------------------------------------------------------
.export _utilAppendChar
_utilAppendChar:
        pha             ; remember c

        jsr _utilGetStringEnd
        sta ptr1
        stx ptr1 + 1

        ldy #0
        pla
        sta (ptr1), y

        tya             ; 0-termination
        iny
        sta (ptr1), y

        rts

; -----------------------------------------------------------------------------
; Return the address of the end of utilStr in AX (changes Y, C).
; -----------------------------------------------------------------------------
_utilGetStringEnd:
        lda #<_utilStr
        ldx #>_utilStr
        sta ptr1
        stx ptr1 + 1

        ldy #0
gseNext:
        lda (ptr1), y
        beq gseEnd

        iny
        bne gseNoHi
        inc ptr1 + 1
        inx
gseNoHi:
        bne gseNext         ; always (as long as the string doesn't wrap to ZP)

gseEnd:
        clc
        tya                 ; update low-byte
        adc ptr1
        bcc gseEndNoHi
        inx
gseEndNoHi:
        rts

; -----------------------------------------------------------------------------
; supermon+  (not available once the Koala bitmap has overwritten $3400)
; -----------------------------------------------------------------------------
.export _goSupermon
_goSupermon:
        lda koalaFlag
        bne @ret
        jsr $e544
        jsr $3400
@ret:   rts

.export _utilReset
_utilReset:
        jmp $fce2

; =============================================================================
; GeoRAM detection
;
; The detection writes marker bytes into GeoRAM; the bytes it clobbers are
; saved and restored, so data already stored in GeoRAM survives.
; On return _georam = 1..4 (512K, 1M, 2M, 4M) or 5 (none), _lastblk and the
; 24 bit limit _maxmem are set. A = _georam.
; =============================================================================
.export _utilGeoram
_utilGeoram:
        lda #$00
        sta $dffe
        ldx #4
@sv:    lda blkTab,x
        sta $dfff
        lda $de00
        sta saveTab,x
        dex
        bpl @sv
        lda #$00
        sta $dfff
        lda $de01
        sta save1
        lda $defe
        sta save2
        lda $deff
        sta save3

        jsr geoDetect

        lda #$00                ; restore what the detection overwrote
        sta $dffe
        ldx #4
@rs:    lda blkTab,x
        sta $dfff
        lda saveTab,x
        sta $de00
        dex
        bpl @rs
        lda #$00
        sta $dfff
        lda save1
        sta $de01
        lda save2
        sta $defe
        lda save3
        sta $deff

        ldx _georam
        cpx #5
        bcs @none
        lda lastBlkTab-1,x
        sta _lastblk
        lda maxHiTab-1,x
        sta _maxmem+2
        lda #$ff
        sta _maxmem+1
        lda #$f0                ; keep the last 16 bytes for the metadata
        sta _maxmem+0
        lda _georam
        rts
@none:  lda #$00
        sta _maxmem+0
        sta _maxmem+1
        sta _maxmem+2
        lda #5
        rts

blkTab:      .byte $00,$1f,$3f,$7f,$ff
lastBlkTab:  .byte $1f,$3f,$7f,$ff      ; 512K, 1M, 2M, 4M
maxHiTab:    .byte $07,$0f,$1f,$3f
saveTab:     .res 5
save1:       .byte 0
save2:       .byte 0
save3:       .byte 0

geoDetect:
        lda #$00
        sta $dffe

        lda #%11111111
        sta $dfff
        lda #$04                ; 4MB marker
        sta $de00

        lda #%01111111
        sta $dfff
        lda #$03                ; 2MB marker
        sta $de00

        lda #%00111111
        sta $dfff
        lda #$02                ; 1MB marker
        sta $de00

        lda #%00011111
        sta $dfff
        lda #$01                ; 512KB marker
        sta $de00

        lda #%00000000
        sta $dfff

        lda #$01                ; 4 byte magic marker
        sta $de00
        lda #$02
        sta $de01
        lda #$03
        sta $defe
        lda #$04
        sta $deff

        lda $de00               ; confirm magic
        cmp #$01
        bne @nomem
        lda $de01
        cmp #$02
        bne @nomem
        lda $defe
        cmp #$03
        bne @nomem
        lda $deff
        cmp #$04
        beq @store

@nomem: lda #$05                ; GeoRAM not detected
        sta _georam
        rts

@store: lda #%11111111
        sta $dfff
        lda $de00
        sta _georam
        rts

; =============================================================================
; GeoRAM metadata (byte rate, data size, sample rate index, output)
; =============================================================================
metapage:                       ; select the metadata page (last page)
        lda _lastblk
        sta $dfff
        lda #$3f
        sta $dffe
        rts

homepage:                       ; window back to page 0 of block 0
        lda #$00
        sta $dffe
        sta $dfff
        rts

.export _checkSize
_checkSize:
        jsr metapage
        ldy #3
@a:     lda $def8,y
        sta _byterate,y
        dey
        bpl @a
        ldy #3
@b:     lda $defc,y
        sta _subchsz,y
        sta datasz,y
        dey
        bpl @b
        lda $def6
        and #3
        sta _sampleRate
        cmp #2
        bcc @keep               ; < 2: output can be chosen freely
        lda $def7               ; >= 2: data format depends on the output
        and #1                  ; used when the file was uploaded
        sta _sidDigimax
@keep:  jsr homepage
        ldx #0
        txa
        jmp cnframpg

.export _saveSize
_saveSize:
        jsr metapage
        lda _sampleRate
        sta $def6
        lda _sidDigimax
        sta $def7
        ldy #3
@a:     lda _byterate,y
        sta $def8,y
        dey
        bpl @a
        ldy #3
@b:     lda _subchsz,y
        sta $defc,y
        dey
        bpl @b
        jmp homepage

; =============================================================================
; GeoRAM page handling
; =============================================================================
setrampg:                       ; X = page lo, A = page hi
        stx lobyte
        asl lobyte
        rol a
        asl lobyte
        rol a
        sta $dfff               ; block = page >> 6
        txa
        and #$3f
        sta $dffe               ; page in block = page & $3f
        rts

cnframpg:                       ; configure start page: X lo, A hi
        stx curpage
        sta curpage+1
        jmp setrampg

incrampg:                       ; next page
        inc curpage
        bne @n
        inc curpage+1
@n:     ldx curpage
        lda curpage+1
        jmp setrampg

; Prepare geopghi/geopglo for page (playidx+1/+2) + 1
calcnext:
        ldy playidx+2
        ldx playidx+1
        inx
        bne @n
        iny
@n:     stx pageflag
        tya
        asl pageflag
        rol a
        asl pageflag
        rol a
        sta geopghi
        txa
        and #$3f
        sta geopglo
        rts

; =============================================================================
; loading of samples into GeoRAM
; =============================================================================

; clamp _subchsz (32 bit) to _maxmem (24 bit)
clampsize:
        lda _subchsz+3
        bne @over
        lda _subchsz+2
        cmp _maxmem+2
        bcc @ok
        bne @over
        lda _subchsz+1
        cmp _maxmem+1
        bcc @ok
        bne @over
        lda _subchsz+0
        cmp _maxmem+0
        bcc @ok
        beq @ok
@over:  lda _maxmem+0
        sta _subchsz+0
        lda _maxmem+1
        sta _subchsz+1
        lda _maxmem+2
        sta _subchsz+2
        lda #0
        sta _subchsz+3
@ok:    rts

copytodatasz:
        ldx #3
@l:     lda _subchsz,x
        sta datasz,x
        dex
        bpl @l
        rts

; decide the sample format and enable the SID noise used for dithering
setupload:
        lda #0
        sta needshift
        lda _sidDigimax
        bne @n
        lda _sampleRate
        cmp #2
        bcc @n
        inc needshift           ; SID at 16/22 kHz: store 4 bit samples
@n:     lda #$ff
        sta $d40e
        sta $d40f
        lda #%10000000
        sta $d412               ; noise, silent
        rts

; 8 bit unsigned sample -> 4 bit with dithering (only if needshift)
convsample:
        ldx needshift
        beq @ret
        sta cvtmp
        lda $d41b               ; noise
        and #$0f
        clc
        adc cvtmp
        bcc @s
        lda #$ff
@s:     lsr
        lsr
        lsr
        lsr
@ret:   rts

; fill the rest of the last page with silence (Y = first free index)
padsilence:
        lda #$80
        ldx needshift
        beq @f
        lda #$08
@f:     sta $de00,y
        iny
        bne @f
        rts

getsample16:                    ; 16 bit signed LE -> 8 bit unsigned, dithered
        jsr chrin               ; low byte
        clc
        adc $d41b               ; carry = dither bit
        php
        jsr chrin               ; high byte
        eor #$80                ; signed -> unsigned
        plp
        adc #0
        bcc @ok
        lda #$ff                ; clip instead of wrapping around
@ok:    rts

initcount:                      ; cnt = number of full pages, init progress
        lda _subchsz+1
        sta cnt
        lda _subchsz+2
        sta cnt+1
        clc
        ldx #3
        stx xpos
        ldy #1
        jmp plot

declcnt:
        lda cnt
        bne @a
        dec cnt+1
@a:     dec cnt
        rts

progress:                       ; one hash every 4 pages (1 KB)
        lda cnt
        and #%00000011
        bne @ret
        lda dotchar
        jsr chrout
        sec
        jsr plot
        cpy #39
        bcc @ret
        inc xpos
        ldx xpos
        cpx #22
        bcc @pos
        ldx #3
        stx xpos
        lda dotchar
        eor #1
        sta dotchar
@pos:   ldy #1
        clc
        jsr plot
@ret:   rts

; Page loader. The per-byte loops (body*) are selected once per load through
; the operand of 'body' below, so that the raw 8 bit loop stays as tight as
; possible (the speed of the upload is limited by the serial bus, every cycle
; spent between two CHRIN calls delays the next byte).
;   in: Y = 0, partsz = number of bytes (0 = 256)   out: Y = partsz
body:   jmp body8raw            ; operand modified by load8bit/load16bit

body8raw:                       ; 8 bit samples, stored as they are
@b:     jsr chrin
        sta $de00,y
        iny
        cpy partsz
        bne @b
        rts

body8shift:                     ; 8 bit -> 4 bit (SID at 16/22 kHz)
@b:     jsr chrin
.if DITHER
        sta cvtmp
        lda $d41b               ; noise: unbiased rounding
        and #$0f
        clc
        adc cvtmp
        bcc @s
        lda #$ff
.endif
@s:     lsr
        lsr
        lsr
        lsr
        sta $de00,y
        iny
        cpy partsz
        bne @b
        rts

body16:                         ; 16 bit signed -> 8 bit (-> 4 bit)
@b:     jsr getsample16
        jsr convsample
        sta $de00,y
        iny
        cpy partsz
        bne @b
        rts

; read the chunk (full pages, then the partial last page) into GeoRAM
loadstream:
        jsr initcount
@page:  lda cnt
        ora cnt+1
        beq @part
        lda #0                  ; 256 bytes
        sta partsz
        tay
        jsr body
        jsr progress
        jsr incrampg
        jsr declcnt
        jmp @page
@part:  lda _subchsz+0
        beq @tail
        sta partsz
        ldy #0
        jsr body
        jsr padsilence
        jsr incrampg            ; window on the page after the data
@tail:  lda _lastblk            ; silence in that page too (if it exists and
        lsr                     ; is not the metadata page): the SEI player
        lsr                     ; needs a few samples to notice the end
        cmp curpage+1
        bcc @ret
        bne @sil
        lda _lastblk
        and #3
        asl
        asl
        asl
        asl
        asl
        asl
        ora #$3f                ; last page = metadata page
        cmp curpage
        bcc @ret
        beq @ret
@sil:   ldy #0
        jmp padsilence
@ret:   rts

setbody:                        ; A/X = address of the byte loop
        sta body+1
        stx body+2
        rts

.export _load8bit
_load8bit:
        jsr clampsize
        jsr copytodatasz
        jsr _saveSize
        jsr setupload
        lda needshift
        beq @raw
        lda #<body8shift
        ldx #>body8shift
        bne @set                ; always
@raw:   lda #<body8raw
        ldx #>body8raw
@set:   jsr setbody
        ldx #0
        txa
        jsr cnframpg
        jmp loadstream

.export _load16bit
_load16bit:
        lsr _subchsz+3          ; chunk size / 2
        ror _subchsz+2
        ror _subchsz+1
        ror _subchsz+0
        jsr clampsize
        jsr copytodatasz
        lsr _byterate+3         ; byte rate / 2
        ror _byterate+2
        ror _byterate+1
        ror _byterate+0
        jsr _saveSize
        jsr setupload
        lda #<body16
        ldx #>body16
        jsr setbody
        ldx #0
        txa
        jsr cnframpg
        jmp loadstream

; -----------------------------------------------------------------------------
; skip a chunk of _subchsz bytes (plus the pad byte of odd sized chunks)
; -----------------------------------------------------------------------------
.export _skip
_skip:
        lda _subchsz+1
        sta cnt
        lda _subchsz+2
        sta cnt+1
@page:  lda cnt
        ora cnt+1
        beq @part
        ldy #0
@b:     jsr chrin
        iny
        bne @b
        jsr declcnt
        jmp @page
@part:  lda _subchsz+0
        beq @pad
        sta partsz
        ldy #0
@c:     jsr chrin
        iny
        cpy partsz
        bne @c
@pad:   lda _subchsz+0
        and #1
        beq @ret
        jsr chrin
@ret:   rts

; =============================================================================
; SID helpers
; =============================================================================
clearSID:
        lda #0
        ldy #24
@l:     sta $d400,y
        dey
        bpl @l
        rts

; Boost SID 8580 for digis
boost:
        lda #$ff
        sta $d406
        sta $d40d
        sta $d414
        lda #$49
        sta $d404
        sta $d40b
        sta $d412
        rts

.export _detectSID
_detectSID:                     ; A = 1 for 8580, 0 for 6581
        ldx #24
        lda #0
@clr:   sta $d400,x
        dex
        bpl @clr

        lda #$02
        sta $d40f
        lda #$30
        sta $d412
        ldy #$00
        ldx #$00
@sl3:   lda $d41b
        bmi @is8580
        dex
        bne @sl3
        dey
        bne @sl3
        lda #0                  ; 6581
        beq @end
@is8580:
        lda #1                  ; 8580
@end:   pha
        lda #0
        sta $d412
        sta $d40f
        pla
        rts

; =============================================================================
; sample rate
;
; CIA period = latch + 1 cycles:
;   rate    NTSC  PAL
;   8000    128   123.2
;   11025    93    89.4
;   16000    64    61.6
;   22050    46    44.7
; =============================================================================
sampleRatePAL:  .byte $7a,$58,$3d,$2c
sampleRateNTSC: .byte $7f,$5c,$3f,$2d

setSamplerate:
        lda _sampleRate
        and #3
        tax
        lda $02a6               ; 0 = NTSC, 1 = PAL
        bne @pal
        lda sampleRateNTSC,x
        bne @set                ; always
@pal:   lda sampleRatePAL,x
@set:   sta $dd04               ; timer A, count lo
        rts

; =============================================================================
; RAM vectors under the KERNAL ROM: valid vectors for the moments in which
; the ROM is banked out (an NMI from RESTORE must not crash the machine)
; =============================================================================
initramvec:
        lda #<nmirti
        sta $fffa
        lda #>nmirti
        sta $fffb
        lda #<$fce2
        sta $fffc
        lda #>$fce2
        sta $fffd
        lda #<nmirti
        sta $fffe
        lda #>nmirti
        sta $ffff
        rts

nmirti: rti

; =============================================================================
; Playback with the KERNAL NMI vector ($0318), IRQs stay on: 8 and 11 kHz
; =============================================================================
.export _playData
_playData:
        jsr pause
        jsr boost

        lda #%11111111          ; CIA2 for Digimax out
        sta $dd02
        sta $dd03
        lda #$00
        sta $dd05               ; timer A, count hi
        jsr setSamplerate
        lda #%00010001          ; force load, continuous, start
        sta $dd0e
        lda #%00001011          ; screen off
        sta $d011

        lda _sidDigimax
        beq @sid
        ldx #<play1chn
        ldy #>play1chn
        jmp @setv
@sid:   ldx #<playSIDchn
        ldy #>playSIDchn
@setv:  stx $0318               ; KERNAL NMI vector
        sty $0319
        jsr rewind
        jsr resume

; keyboard / main loop
;  Space -> Pause/Resume    F1 -> Back 5s       F7 -> Forward 10s
;  <-    -> Rewind          s  -> Stop          +  -> Screen On
;  -     -> Screen Off      r  -> Repeat On/Off F2 -> Quit
@iloop:
        jsr calcnext            ; prefetch GeoRAM registers for the next page

        lda playidx+2           ; end of data? (playidx >= datasz)
        cmp datasz+2
        bcc @key
        bne @end
        lda playidx+1
        cmp datasz+1
        bcc @key
        bne @end
        lda playidx+0
        cmp datasz+0
        bcc @key
@end:   lda repeat
        beq @stopit
        jsr rewind
        jmp @key
@stopit:
        jsr dostop

@key:   jsr getin
        beq @iloop

        cmp #$20                ; space
        bne @n1
        lda playing
        beq @res
        jsr pause
        jmp @iloop
@res:   jsr resume
        jmp @iloop

@n1:    cmp #$53                ; s
        bne @n2
        jsr dostop
        jmp @iloop
@n2:    cmp #$5f                ; arrow left
        bne @n3
        jsr rewind
        jmp @iloop
@n3:    cmp #$85                ; F1
        bne @n4
        jsr back5
        jmp @iloop
@n4:    cmp #$88                ; F7
        bne @n5
        jsr fwrd10
        jmp @iloop
@n5:    cmp #$2b                ; +
        bne @n6
        lda #%00011011          ; screen on
        sta $d011
        jmp @iloop
@n6:    cmp #$2d                ; -
        bne @n7
        lda #%00001011          ; screen off
        sta $d011
        jmp @iloop
@n7:    cmp #$52                ; r
        bne @n8
        lda repeat
        eor #1
        sta repeat
        jmp @iloop
@n8:    cmp #$89                ; F2
        beq @quit
        jmp @iloop

@quit:  lda #0
        sta playing
        lda #%00011011          ; screen on
        sta $d011
        lda #%00011111          ; clear all CIA2 interrupts
        sta $dd0d
        lda $dd0d
        jsr LAB_FDA3            ; initialize I/O devices
        jmp _STOPSIDP           ; restore vectors, silence SID

; =============================================================================
; Playback with the NMI vector in RAM under the KERNAL, IRQs off: 16 / 22 kHz
;
; The NMI handler only outputs the sample and, every 256 samples, switches the
; GeoRAM page. Page counting, end of data and keyboard are handled by the main
; loop (the CPU has only a few cycles per sample left).
; =============================================================================
.export _playDataSEI
_playDataSEI:
        sei
        jsr initramvec          ; (KERNAL ROM still visible: writes go to RAM)
        lda #<play22Khz
        sta $fffa
        lda #>play22Khz
        sta $fffb
        lda $01
        sta saved01
        lda #$35                ; I/O + RAM everywhere
        sta $01

        jsr boost

        lda #%00011111          ; clear all CIA2 interrupts
        sta $dd0d
        lda $dd0d
        lda #%11111111          ; CIA2 ports: all outputs (Digimax)
        sta $dd02
        sta $dd03
        lda #$00
        sta $dd05               ; timer A, count hi
        jsr setSamplerate

        lda _sidDigimax         ; output register of the handler
        beq @sid
        lda #<$dd01
        sta label+1
        lda #>$dd01
        sta label+2
        lda #%00000011          ; Left channel
        sta $dd00
        bne @go
@sid:   lda #<$d418
        sta label+1
        lda #>$d418
        sta label+2

@go:    lda #$7f                ; keyboard column of the space key
        sta $dc00
@rel:   lda $dc01               ; wait until space is released
        cmp #$ef
        beq @rel

        lda #0
        sta playidx+0
        sta playidx+1
        sta playidx+2
        sta playidx+3
        sta probe+1             ; index in page
        sta lastidx
        tax
        jsr setrampg            ; window on page 0
        jsr calcnext            ; registers for page 1

        lda #%00001011          ; screen off (no badlines)
        sta $d011
        lda #%00010001          ; force load, continuous, start
        sta $dd0e
        lda $dd0d
        lda #%10000001          ; enable timer A NMI
        sta $dd0d

@hold:  lda probe+1             ; page wrapped since last look?
        cmp lastidx
        sta lastidx
        bcs @same
        inc playidx+1           ; yes: next page, prepare the one after
        bne @c
        inc playidx+2
@c:     jsr calcnext
@same:  lda playidx+2           ; end of data? (position >= datasz)
        cmp datasz+2
        bcc @key
        bne @end
        lda playidx+1
        cmp datasz+1
        bcc @key
        bne @end
        lda probe+1
        cmp datasz+0
        bcc @key
@end:   lda repeat
        beq @stop
        lda #%00011111          ; restart from the beginning
        sta $dd0d
        lda $dd0d
        lda #0
        sta playidx+1
        sta playidx+2
        sta probe+1
        sta lastidx
        tax
        jsr setrampg
        jsr calcnext
        lda #%10000001
        sta $dd0d
        jmp @hold
@key:   lda $dc01               ; space = stop
        cmp #$ef
        bne @hold

@stop:  lda #%00011111          ; clear all CIA2 interrupts
        sta $dd0d
        lda $dd0d
        jsr clearSID
        lda #%00011011          ; screen on
        sta $d011
        jsr LAB_FDA3            ; initialize I/O devices (also $01 = $e6)
        cli
        rts

; NMI handler, 33 cycles (+7 NMI entry) per sample, 48 on a page change.
; The sample index is the operand of the lda below (self modifying).
play22Khz:
        bit $dd0d               ; ready for next NMI                  4
        pha                     ;                                     3
probe:  lda $de00               ; A <- sample                         4
label:  sta $d418               ; output ($d418 or $dd01)             4
        inc probe+1             ;                                     6
        beq @newpage            ;                                     2
        pla                     ;                                     4
        rti                     ;                                     6
@newpage:
        lda geopghi             ; page complete: GeoRAM registers     3
        sta $dfff               ; prepared by the main loop           4
        lda geopglo             ;                                     3
        sta $dffe               ;                                     4
        pla
        rti

; =============================================================================
; NMI handlers for the KERNAL vector (7 + 7 cycles overhead before the code)
; =============================================================================

; DigiMax, mono sample on both channels: 76 cycles
play1chn:
        bit $dd0d               ; ready for next NMI
        pha
        txa
        pha
        ldx playidx
        lda $de00,x             ; A <- sample
        ldx #%00000011          ; left channel
        stx $dd00
        sta $dd01
        ldx #%00000111          ; right channel
        stx $dd00
        sta $dd01
        inc playidx
        beq nmipage
        pla
        tax
        pla
        rti

; SID volume register, 8 bit sample -> 4 bit: 68 cycles
playSIDchn:
        bit $dd0d
        pha
        txa
        pha
        ldx playidx
        lda $de00,x             ; A <- sample
        lsr
        lsr
        lsr
        lsr
        sta $d418
        inc playidx
        beq nmipage
        pla
        tax
        pla
        rti

nmipage:                        ; page complete, update the RAM page
        inc playidx+1
        bne @n
        inc playidx+2
@n:     lda geopghi
        ldx geopglo
        sta $dfff
        stx $dffe
        pla
        tax
        pla
        rti

; =============================================================================
; Playback control
;
;  resume - Resume Playback        pause  - Pause Playback
;  dostop - Pause and Rewind       rewind - Reset Play Index
;  back5  - Skip Back 5 Seconds    fwrd10 - Skip Forward 10 Seconds
; =============================================================================
resume:
        lda playing
        bne @ret                ; already playing
        lda #1
        sta playing
        lda #%00001011          ; screen off
        sta $d011
        ldx playidx+1           ; set current GeoRAM page
        lda playidx+2
        jsr setrampg
        lda $dd0d               ; drop a pending NMI
        lda #%10000001          ; enable timer A NMI
        sta $dd0d
@ret:   rts

pause:
        lda playing
        beq @ret                ; already paused
        lda #0
        sta playing
        lda #%00011111          ; prevent CIA2 timer A NMI
        sta $dd0d
@ret:   rts

dostop:
        jsr pause
        lda #%00011011          ; screen on
        sta $d011
        jmp rewind

rewind:
        lda playing
        pha
        jsr pause
        lda #$00
        sta playidx+0
        sta playidx+1
        sta playidx+2
        sta playidx+3
        pla
        beq @ret
        jmp resume
@ret:   rts

back5:                          ; playidx -= byterate * 5
        lda playing
        pha
        jsr pause
        ldx #4
@next:  sec
        lda playidx+0
        sbc _byterate+0
        sta playidx+0
        lda playidx+1
        sbc _byterate+1
        sta playidx+1
        lda playidx+2
        sbc _byterate+2
        sta playidx+2
        lda playidx+3
        sbc _byterate+3
        sta playidx+3
        dex
        bpl @next

        lda playidx+3           ; if playidx > datasz it underflowed
        cmp datasz+3
        bcc @valid
        bne @under
        lda playidx+2
        cmp datasz+2
        bcc @valid
        bne @under
        lda playidx+1
        cmp datasz+1
        bcc @valid
        bne @under
        lda playidx+0
        cmp datasz+0
        bcc @valid
        beq @valid
@under: lda #0
        sta playidx+0
        sta playidx+1
        sta playidx+2
        sta playidx+3
@valid: pla
        beq @ret
        jmp resume
@ret:   rts

fwrd10:                         ; playidx += byterate * 10
        lda playing
        pha
        jsr pause
        ldx #9
@next:  clc
        lda playidx+0
        adc _byterate+0
        sta playidx+0
        lda playidx+1
        adc _byterate+1
        sta playidx+1
        lda playidx+2
        adc _byterate+2
        sta playidx+2
        lda playidx+3
        adc _byterate+3
        sta playidx+3
        dex
        bpl @next

        lda playidx+3           ; if playidx > datasz: playidx = datasz
        cmp datasz+3
        bcc @valid
        bne @over
        lda playidx+2
        cmp datasz+2
        bcc @valid
        bne @over
        lda playidx+1
        cmp datasz+1
        bcc @valid
        bne @over
        lda playidx+0
        cmp datasz+0
        bcc @valid
        beq @valid
@over:  lda datasz+0            ; the main loop sees the end and stops
        sta playidx+0
        lda datasz+1
        sta playidx+1
        lda datasz+2
        sta playidx+2
        lda datasz+3
        sta playidx+3
        pla
        rts                     ; don't resume
@valid: pla
        beq @ret
        jmp resume
@ret:   rts

; =============================================================================
; SID player (tune loaded at $1000, init $1000, play $1003)
; =============================================================================
_SIDINIT:
        lda #0
        tax
        tay
        jmp SIDLOADPOS

_SIDPLAY:
        sei
        ldx #<sidirq
        ldy #>sidirq
        stx $0314
        sty $0315
        lda #$00                ; raster line 0
        sta $d012
        lda #$7f                ; no CIA1 interrupts, raster IRQ only
        sta $dc0d
        lda #$1b
        sta $d011
        lda $dc0d
        lda #$ff
        sta $d019
        lda #$01
        sta $d01a               ; raster interrupt on
        cli
        rts

sidirq:
        lda #$01
        sta $d019               ; acknowledge raster IRQ
        jsr SIDPLAYPOS
        jmp $ea31               ; KERNAL standard IRQ (keyboard...)

; Restore the default interrupt setup and silence the SID
_STOPSIDP:
        sei
        lda #$7f
        sta $dd0d               ; CIA2: no interrupts (KERNAL default)
        lda #$81
        sta $dc0d               ; CIA1: timer A IRQ (KERNAL default)
        lda #$00
        sta $d01a               ; raster interrupt off
        lda #$ff
        sta $d019
        lda #<$ea31
        sta $0314               ; IRQ vector
        lda #>$ea31
        sta $0315
        lda #<$fe47
        sta $0318               ; NMI vector
        lda #>$fe47
        sta $0319
        jsr clearSID
        cli
        rts

; =============================================================================
; Koala images
;
; The bitmap ($2000-$3f3f) overwrites TITLEMAP, ATTRIBUTES, INSTRUCTIONS and
; SUPERMON: koalaFlag disables the routines that need them.
; Image layout (GeoRAM and loadKoala): bitmap 8000, screen RAM 1000, color
; RAM 1000, background 1 -> color data block $e000-$e7d0 (2001 bytes).
; =============================================================================
setbitmap:
        lda #$3b                ; bitmap mode
        sta $d011
        lda #$18                ; screen $0400, bitmap $2000
        sta $d018
        sta $d016               ; multicolor
        lda $dd00               ; VIC bank 0, serial lines untouched
        ora #$03
        sta $dd00
        rts

settext:
        lda #$1b
        sta $d011
        lda #$17
        sta $d018
        lda #$c8
        sta $d016
        lda oldborder
        sta $d020
        lda oldbg
        sta $d021
        rts

savecolors:
        lda $d020
        sta oldborder
        lda $d021
        sta oldbg
        rts

; color data at $e000 (RAM under the KERNAL) -> screen RAM and color RAM
copyColor:
        php
        sei
        jsr initramvec
        lda $01
        sta saved01
        lda #$35                ; RAM at $e000, I/O visible
        sta $01
        ldx #$00
@loop:  lda colorData,x
        sta screenRam,x
        lda colorData+$100,x
        sta screenRam+$100,x
        lda colorData+$200,x
        sta screenRam+$200,x
        lda colorData+$2e8,x
        sta screenRam+$2e8,x
        lda colorData+$3e8,x
        sta colorRam,x
        lda colorData+$4e8,x
        sta colorRam+$100,x
        lda colorData+$5e8,x
        sta colorRam+$200,x
        lda colorData+$6d0,x
        sta colorRam+$2e8,x
        inx
        bne @loop
        lda colorData+$7d0      ; background colour
        sta $d021
        sta $d020
        lda saved01
        sta $01
        plp
        rts

; read the color data of a Koala file (after the 8000 bitmap bytes)
.export _copyDataColor
_copyDataColor:
        lda #1
        sta koalaFlag
        lda #<colorData
        sta ptr2
        lda #>colorData
        sta ptr2+1
        ldx #7                  ; 7 full pages + 209 bytes = 2001
@page:  ldy #0
@b:     jsr chrin
        sta (ptr2),y
        iny
        bne @b
        inc ptr2+1
        dex
        bne @page
@last:  jsr chrin
        sta (ptr2),y
        iny
        cpy #209
        bne @last
        rts

.export _showKoala
_showKoala:
        lda #1
        sta koalaFlag
        jsr savecolors
        jsr copyColor
        jsr setbitmap
@fl:    jsr getin               ; flush the keyboard buffer
        bne @fl
@w:     jsr getin               ; any key to leave
        beq @w
        jmp settext

; copy N bytes (cnt) from the GeoRAM window (index X, page srcpg) to (ptr2)
copyN:
        ldy #0
@lp:    lda $de00,x
        sta (ptr2),y
        inc ptr2
        bne @a
        inc ptr2+1
@a:     inx
        bne @b
        inc srcpg
        lda srcpg
        sta $dffe
@b:     lda cnt
        bne @c
        dec cnt+1
@c:     dec cnt
        lda cnt
        ora cnt+1
        bne @lp
        rts

; image of the block selected in $dfff -> $2000 (bitmap) and $e000 (colors)
loadimage:
        lda #0
        sta srcpg
        sta $dffe
        tax                     ; source index
        sta ptr2
        lda #$20
        sta ptr2+1
        lda #<8000
        sta cnt
        lda #>8000
        sta cnt+1
        jsr copyN
        lda #<colorData         ; colors follow in the same stream
        sta ptr2
        lda #>colorData
        sta ptr2+1
        lda #<2001
        sta cnt
        lda #>2001
        sta cnt+1
        jmp copyN


; Slide show: SPACE = next image, q = exit early
; Exits after the last image; with 0 or 1 images SPACE returns immediately.

.export _koalaCount
_koalaCount: .byte 0

.export _downloadKoala
_downloadKoala:
        lda #1
        sta koalaFlag
        jsr savecolors
        jsr setbitmap

        lda #0
        sta $dfff              ; first image: block 0

@start:
        jsr loadimage
        jsr copyColor

@check:
        jsr getin
        beq @check

        cmp #$20               ; SPACE
        beq @next
        cmp #$51               ; q
        beq @quit
        bne @check

@next:
        lda _koalaCount
        cmp #2
        bcc @quit              ; 0 or 1 image: return

        inc $dfff              ; next GeoRAM block

        lda $dfff
        cmp _koalaCount
        bcc @start             ; more images to show

                               ; all images shown: fall through to exit

@quit:
        jmp settext

; =============================================================================
; Text viewers (40 columns, 22 lines per page, q = quit at -MORE-)
; =============================================================================
pgmode:     .byte 0             ; 0 = memory ($fb/$fc), 1 = file #2
linecount:  .byte 0
charcount:  .byte 0
moretext:   .byte "-MORE-"

; A = next character, carry set at the end of the text
getnext:
        lda pgmode
        bne @file
        ldy #0
        lda ($fb),y
        beq @end                ; 0 terminated
        inc $fb
        bne @ok
        inc $fc
@ok:    clc
        rts
@file:  jsr readst
        bne @end
        jsr getin
        clc
        rts
@end:   sec
        rts

; end of a line: carry set if the user quit at the -MORE- prompt
newline:
        lda #$0d
        jsr chrout
        lda #0
        sta charcount
        inc linecount
        lda linecount
        cmp #22
        bcc @done
        ldx #0
@m:     lda moretext,x
        jsr chrout
        inx
        cpx #6
        bne @m
        jsr clrchn              ; keyboard input
@key:   jsr getin
        beq @key
        cmp #$51                ; q
        beq @q
        ldx #0                  ; erase -MORE-
@e:     lda #$14
        jsr chrout
        inx
        cpx #6
        bne @e
        lda #0
        sta linecount
        lda pgmode
        beq @done
        ldx #2                  ; back to the file
        jsr chkin
@done:  clc
        rts
@q:     sec
        rts

pager:
        lda #0
        sta linecount
        sta charcount
@loop:  jsr getnext
        bcs @eof
        cmp #$0a
        beq @nl
        cmp #$0d
        beq @nl
        tax
        and #$7f                ; control codes -> '.'
        cmp #$20
        txa
        bcs @chk
        lda #$2e
@chk:   ldy charcount
        cpy #39
        bcc @print
        pha                     ; line full: wrap
        jsr newline
        pla
        bcs @quit
@print: jsr chrout
        inc charcount
        jmp @loop
@nl:    jsr newline
        bcc @loop
@quit:  rts
@eof:   jsr clrchn
@wait:  jsr getin
        beq @wait
        clc
        rts

.export _showINFO
_showINFO:
        lda koalaFlag
        bne @ret
        lda #<instructions
        sta $fb
        lda #>instructions
        sta $fc
        lda #0
        sta pgmode
        jsr $e544               ; clear screen
        jmp pager
@ret:   rts

.export _showSEQ
_showSEQ:
        lda #1
        sta pgmode
        jsr $e544
        ldx #2                  ; file number 2
        jsr chkin
        jsr pager
        lda #2
        jsr close
        jmp clrchn

; =============================================================================
; Oscilloscope (IRQ), only used with the KERNAL NMI player
; =============================================================================
base = $07c0-160+(40/2)-(16/2)

.export _setScopeIRQ
_setScopeIRQ:
        sei
        ldx #<scopeIRQ
        ldy #>scopeIRQ
        stx $0314
        sty $0315
        lda #0
        sta scopetick
        cli
        rts

scopeIRQ:
        asl $d019
        lda scopetick
        clc
        adc #$40                ; delay
        sta scopetick
        beq @shift
        ldx playidx             ; current sample from the GeoRAM window
        lda $de00,x
        lsr
        lsr
        lsr
        lsr
        tax
        lda #97                 ; graphic symbol
        sta base-240,x
        sta base-200,x
        sta base-160,x
        sta base-120,x
        sta base-80,x
        sta base-40,x
        sta base,x
        jmp $ea31
@shift: ldx #15                 ; number of columns
@loop:  lda base-40,x
        sta base,x
        lda base-80,x
        sta base-40,x
        lda base-120,x
        sta base-80,x
        lda base-160,x
        sta base-120,x
        lda base-200,x
        sta base-160,x
        lda base-240,x
        sta base-200,x
        lda #$20
        sta base-240,x
        dex
        bpl @loop
        jmp $ea31

; =============================================================================
; Copy of the KERNAL IOINIT ($FDA3) keeping BASIC switched off ($01 = $e6)
; =============================================================================
LAB_FDA3:
        LDA     #$7F                    ; disable all interrupts
        STA     $DC0D
        STA     $DD0D
        STA     $DC00                   ; keyboard column drive
        LDA     #$08                    ; set timer single shot
        STA     $DC0E
        STA     $DD0E
        STA     $DC0F
        STA     $DD0F
        LDX     #$00                    ; set all inputs
        STX     $DC03
        STX     $DD03
        STX     $D418                   ; clear volume and filter select
        DEX                             ; X = $FF
        STX     $DC02
        LDA     #$07                    ; DATA/CLK/ATN out high, video bank 0
        STA     $DD00
        LDA     #$3F                    ; serial DATA/CLK inputs
        STA     $DD02
        LDA     #$E6                    ; motor off, I/O, KERNAL, BASIC off
        STA     $01
        LDA     #$2F
        STA     $00
        LDA     $02A6                   ; PAL/NTSC flag
        BEQ     @ntsc
        LDA     #$25                    ; PAL timing
        STA     $DC04
        LDA     #$40
        JMP     @set
@ntsc:  LDA     #$95
        STA     $DC04
        LDA     #$42
@set:   STA     $DC05
        LDA     #$81                    ; enable timer A interrupt
        STA     $DC0D
        LDA     $DC0E
        AND     #$80                    ; keep TOD clock bit
        ORA     #$11                    ; load and start timer A
        STA     $DC0E
        JMP     $EE8E                   ; serial clock out low and return

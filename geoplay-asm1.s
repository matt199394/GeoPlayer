;
; util.s - Some utility functions
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
.segment "LOADADDR"
		.byte 01,08
		
			.segment "MUSIC"
			.incbin "ILoveDMC.sid",$7e

.export _TITLEMAP			
			.segment "TITLEMAP"
_TITLEMAP:	.incbin "geoPlayerLogo.bin"

.export  _ATTRIBUTES
			.segment "ATTRIBUTES"
_ATTRIBUTES:	.incbin "geoPlayerLogoAttrib.bin"


                        .segment "INSTRUCTIONS"
instructions:    .incbin "instructions.txt"

.segment "SUPERMON"
supermon:    .incbin "supermon+3400.prg",2
			
.export _SIDINIT
.export _SIDPLAY
.export _STOPSIDP

SCREENRAM = $0400
COLORRAM = $d800
SIDLOADPOS = $1000;
SIDPLAYPOS = $1003;


.import         BASIN
.importzp       ptr1, ptr2, ptr3, tmp1, tmp2
.import         popax, popa


.import         _utilStr


.export buffer_start_hi: absolute
.export buffer_len_hi: absolute
buffer_start_hi   = $68             ; see buffer.h
buffer_len_hi     = 16              ; see EASY_SPLIT_MAX_EXO_OFFSET and buffer.h



playidx  = $61     ;In-Page Index
         ; $62,$63 ;GeoRAM Page
         ; $64     ;Should stay zero.

lobyte   = $65 ;part of BASIC FAC

pageflag = $66

geopglo  = $67
geopghi  = $68

storeA  = $69
storeX  = $6a
exitNMI = $6b

ptr      = $fb  ;$fc
xpos: .byte 0
;ypos .byte 0

.export _maxmem			;3f  	 ;4Mb
_maxmem:   .byte $f8,$ff,$1f,$00 ;2Mb ;.byte $00,$00,$20,$00
						;0f	     ;1MB
						;07      ;512 Kb
.export _byterate
_byterate: .res 4

.export _subchnk
_subchnk:  .res 4 ;"fmt " or "data"
.export _subchsz 
_subchsz: .res 4

datasz:   .byte 0,0,0,0

.export _sidDigimax
_sidDigimax: .byte 0

.export _sampleRate
_sampleRate: .byte 0

chrin = $FFCF
getin = $FFE4
plot = $FFF0  
chrout = $FFD2
colorData = $e000
screenRam = $0400
colorRam = $d800


; Kernal I/O Status Word ST
ST                = $90

; =============================================================================
; hex digits
; =============================================================================
.rodata
hexDigits:
        .byte "0123456789ABCDEF"



.code

; =============================================================================

.export _utilReadByte
_utilReadByte:
        jsr     BASIN 
        rts


; =============================================================================
;
; Like cbm_read, but without calling CHKIN/CLRCH. The caller must have
; redirected the input already.
;
; int __fastcall__ utilReadNormalFile(void* buffer, unsigned int size);
;
; Reads up to "size" bytes from a file to "buffer".
; Returns the number of actually read bytes, 0 if there are no bytes left
; (EOF).
;
; =============================================================================
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

; bytesread = 0;

        lda     #$00
        sta     ptr3
        sta     ptr3 + 1
        beq     utilRead3       ; Branch always

; Loop

utilRead1:
        lda     ST              ; Status ok?
        bne     utilRead4

        jsr     BASIN           ; Read next char from file
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
   
; =============================================================================
;
; Append a single digit hex number to the string utilStr.
;
; void __fastcall__ utilAppendHex1(uint8_t n);
;
; parameters:
;       value n in A
;       address on cc65-stack
;
; return:
;       -
;
; =============================================================================
.export _utilAppendHex1
_utilAppendHex1:
        pha             ; remember n

        ; get string end
        jsr _utilGetStringEnd
        sta ptr1
        stx ptr1 + 1
        pla
        pha

        ldy #0
utilAppendHex1_:
        ; get low nibble
        pla
        and #$0f
        tax
        lda hexDigits, x
        sta (ptr1), y

        ; 0-termination
        lda #0
        iny
        sta (ptr1), y

        rts


; =============================================================================
;
; Append a two digit hex number to the string utilStr.
;
; void __fastcall__ utilAppendHex2(uint8_t n);
;
; parameters:
;       value n in A
;
; return:
;       -
;
; =============================================================================
.export _utilAppendHex2
_utilAppendHex2:
        pha             ; remember n

        ; get string end
        jsr _utilGetStringEnd
        sta ptr1
        stx ptr1 + 1
        pla

        ; get high nibble
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

; =============================================================================
;
; Append a character to the string utilStr.
;
; void __fastcall__ utilAppendChar(char c);
;
; parameters:
;       character c in A
;
; return:
;       -
;
; =============================================================================
.export _utilAppendChar
_utilAppendChar:
        pha             ; remember c

        ; get string end
        jsr _utilGetStringEnd
        sta ptr1
        stx ptr1 + 1

        ldy #0
        pla
        sta (ptr1), y

        ; 0-termination
        tya
        iny
        sta (ptr1), y

        rts

; =============================================================================
;
; Return the address of end of utilStr.
;
; parameters:
;       -
;
; return:
;       address of 0-termination of string in AX
;
; changes:
;       Y, C
;
; =============================================================================
;.export _utilGetStringEnd
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



; =============================================================================
;
; supermon+
;
; =============================================================================
.export _goSupermon
_goSupermon:
		.scope 
		lda koalaFlag
		beq:+
		rts
:	   jsr $e544
       jsr $3400
	   rts
	   .endscope
; =============================================================================
;
; Reset.
;
; =============================================================================
.export _utilReset
_utilReset:
        jmp $fce2


;==================Detect GeoRAM=======================
.export _utilGeoram
_utilGeoram:
         .scope
								;TODO: write _maxmem in according to GeoRam size  <--NB
								
         lda #$00
         sta $dffe

         lda #%11111111
         sta $dfff
         lda #$04   ;4MB Marker
         sta $de00

         lda #%01111111
         sta $dfff
         lda #$03   ;2MB Marker
         sta $de00

         lda #%00111111
         sta $dfff
         lda #$02   ;1MB Marker
         sta $de00

         lda #%00011111
         sta $dfff
         lda #$01   ;512KB Marker
         sta $de00

         lda #%00000000
         sta $dfff

         lda #$01  ;4 Byte Magic Marker
         sta $de00
         lda #$02
         sta $de01
         lda #$03
         sta $defe
         lda #$04
         sta $deff

         lda $de00 ;Confirm 4 Byte Magic
         cmp #$01
         bne nomem
         lda $de01
         cmp #$02
         bne nomem
         lda $defe
         cmp #$03
         bne nomem
         lda $deff
         cmp #$04
         beq store

nomem:    lda #$05   ;GeoRAM Not Detected
          sta _georam
          rts


         ;Config _maxmem from Marker Code

 store:  lda #%11111111
         sta $dfff
         lda $de00
         sta _georam
         rts
         .endscope
.export _georam
_georam: .byte 0  

;----------data done-----------------------------

;==========playData 16KHz Digimax==========================
.export _playDataSEI
_playDataSEI:
		.scope
		sei
		dec $01
		jsr boost
		 ;lda #$00
         ;sta playidx+0
         ;sta playidx+1
         ;sta playidx+2
         ;sta playidx+3
		 
		 lda _sidDigimax
		 beq :+
		 lda #$01
		 sta label+1
		 lda #$dd
		 sta label+2
		 bne :++
:		 lda #$18
		 sta label+1
		 lda #$d4
		 sta label+2
         ;Prevent Timer A NMI

:     	 lda #%00011111 ;Clear All
         sta $dd0d

         ;Configure CIA2 for Digimax Out

         lda #%11111111
         sta $dd02 ;Port A: All Outputs
         sta $dd03 ;Port B: All Outputs


         ;Configure CIA2 (NMI) Timer A

         lda #$00
         sta $dd05 ;Timer A, Count Hi
		 sta exitNMI
		 sta playidx+0
         sta playidx+1
         sta playidx+2
		
         jsr setSamplerate
		 
         ;Force load
         ;Continous Fire Mode
         ;PortB Ouput Off
         ;Start the Timer

         lda #%00010001
         sta $dd0e         ;CIA2 Timer A

         ;Configure NMI Handler
		 
		 ;Turn off the screen.
         lda #%00001011
         sta $d011
		 
		 
		 
		 ldx #<play22Khz
         ldy #>play22Khz
		 stx $fffa  ;KERNAL NMI Vector
         sty $fffb
		 
		  ;Set current GeoRAM Page
         ;ldx playidx+1
         ;lda playidx+2
         ;jsr setrampg

         ;Leave playidx unchanged
		 
		 ldx #%00000011 ;Left Channel
         stx $dd00

         ;Enable CIA2 Timer A NMI
		
         lda #%10000001 ;Enable Timer A
         sta $dd0d
hold:    
		  ;--- TEST: Keep testing this---

         ldy playidx+2

         ldx playidx+1
         inx
         stx pageflag

         bne :+
         iny

:        tya

         asl pageflag
         rol a
         asl pageflag
         rol a

         sta geopghi
         stx geopglo

         ;---- End -----
		 lda exitNMI
		 beq hold
		 inc $01
		 jsr LAB_FDA3
		 ;Turn on the screen.
         lda #%00011011
         sta $d011
		 cli
		 rts
		 
		 .endscope
		 
;playidx  = $61     ;In-Page Index
         ; $62,$63 ;GeoRAM Page
         ; $64     ;Should stay zero.

;lobyte   = $65 ;part of BASIC FAC

;pageflag = $66

;geopglo  = $67
;geopghi  = $68

;storeA  = $69
;storeX  = $6a
		 
;================================================================================================

;Boost SID 8580 for Digis
boost:
.if 1
		LDA #$FF
		STA $D406
		LDA #$49
		STA $D404

		LDA #$FF
		STA $D406
		STA $D406+7
		STA $D406+14
		LDA #$49
		STA $D404
		STA $D404+7
		STA $D404+14
		rts
.endif	
	
.if 0
		lda #$0f ;Setup attack=0 and decay=15
		sta $d405
		sta $d40c
		sta $d413
		lda #$ff ;Setup all sustain&release to 15
		sta $d406
		sta $d40d
		sta $d414
		lda #$49 ;Waveform is square, test bit set
		sta $d404
		sta $d40b
		sta $d412
		lda #$ff ;Filter cutoff as high as possible
		sta $d415
		sta $d416
		lda #$03 ;Enable voice 1 and 2 through filter
		sta $d417
		rts
.endif	
;===========================================================

	
;---------playData8-11KHz-------------------------
;Sample Rate Table

;NTSC Clock Rate: 1022727Hz
; PAL Clock Rate:  985248Hz

;Rate      NTSC     PAL
;22050Hz   46.38c   44.68c
;16000Hz   63.92c   61.58c
;11025Hz   92.76c   89.36c
; 8000Hz  127.84c  123.16c

					;      lo  lmi  hmi hi ntsc pal
;sampleRateTable:    .byte $22,$56,$00,$00,$2e,$2d
					;.byte <str22rat,>str22rat

					;.byte $80,$3e,$00,$00,$40,$3e
					;.byte <str16rat,>str16rat

					;.byte $11,$2b,$00,$00,$5d,$59
					;.byte <str11rat,>str11rat

					;.byte $40,$1f,$00,$00,$80,$7b
					;.byte <str80rat,>str80rat
					
sampleRatePAL:	.byte $7b,$59,$3e,$2d
sampleRateNTSC: .byte $80,$5d,$40,$2e

.export _playData
_playData:
		.scope
         ;Prevent Timer A NMI

         jsr pause

         jsr boost
		
		

         ;Configure CIA2 for Digimax Out

         lda #%11111111
         sta $dd02 ;Port A: All Outputs
         sta $dd03 ;Port B: All Outputs


         ;Configure CIA2 (NMI) Timer A

         lda #$00
         sta $dd05 ;Timer A, Count Hi

		 jsr setSamplerate
		 
         ;Force load
         ;Continous Fire Mode
         ;PortB Ouput Off
         ;Start the Timer

         lda #%00010001
         sta $dd0e         ;CIA2 Timer A

         ;Configure NMI Handler
		 

		 ;Turn off the screen.
         lda #%00001011
         sta $d011
 		 lda _sidDigimax
		 bne :+
		
		
		 ldx #<playSIDchn
         ldy #>playSIDchn
      
         stx $0318  ;KERNAL NMI Vector
         sty $0319

         jsr rewind
         jsr resume

         jmp iloop

 :       ldx #<play1chn
         ldy #>play1chn
      
         stx $0318  ;KERNAL NMI Vector
         sty $0319

         ;Rewind and Resume!

         jsr rewind
         jsr resume
		 
		 ;jmp iloop
		 

;Keyboard Scanning Loop

iloop:
		 
         ;--- TEST: Keep testing this---

         ldy playidx+2

         ldx playidx+1
         inx
         stx pageflag

         bne :+
         iny

:         tya

         asl pageflag
         rol a
         asl pageflag
         rol a

         sta geopghi
         stx geopglo

         ;---- End -----


         lda playidx+2
         cmp datasz+2
         bcc continue
         bne doend

         lda playidx+1
         cmp datasz+1
         bcc continue
         bne doend

         lda playidx+0
         cmp datasz+0
         bcc continue
         beq continue

doend:    ;Playback hit end, wrap around
         lda repeat
         beq *+8

         jsr rewind
         clc
         bcc *+5

         jsr dostop

         ;Keyboard Controls:
         ; Space -> Pause/Resume
         ; F1    -> Back     5 Seconds
         ; F7    -> Forward 10 Seconds
         ; _     -> Rewind
         ; s     -> Stop
         ; +     -> Screen On
         ; -     -> Screen Off
         ; r     -> Repeat On/Off
         ; F2    -> Quit

continue: jsr getin
         beq iloop
		 
;continue: 
		;lda $dc01
		;cmp #%11101111   ;space
		;bne notspace

         cmp #$20; " "
         bne notspace
         lda playing
         beq :+
         jsr pause
         jmp iloop
:        jsr resume
         jmp iloop
		 
notspace:
;		lda $dc01
;		cmp #%11011111  ;C=
;		bne :+

         cmp #$53  ;"s"
         bne :+

         jsr dostop
         jmp iloop

;:        lda $dc01
;		cmp #%11111101  ;<-
;		bne :+ 

:		cmp #$5f  ;"{arrow left}"
         bne :+

         jsr rewind
         jmp iloop

;:        lda $dc01
;		cmp #%10111111  ;"q"
;		bne :+
		

:		 cmp #$85 ;F1 Key
         bne :+

         jsr back5
         jmp iloop

;:        lda $dc01
;		 cmp #%11110111   ;"2"
;		 bne :+

:		 cmp #$88 ;F7 Key
         bne :+

         jsr fwrd10
         jmp iloop

;        lda $dc01
;		cmp #%11111110  ;"1"
;		bne :++
		 
:		 cmp #$2B  ;"+"
         bne :++
		 
		 lda _sampleRate
		 cmp #2
		 beq :+
         lda #%00011011  ;Screen On
         sta $d011
:         jmp iloop

;:       lda $dc01
;		cmp #%11111011		;CTRL
;		bne :+

:		 cmp #$2D   ;"-"
         bne :+

         lda #%00001011  ;Screen Off
         sta $d011
         jmp iloop

:        cmp #$52  ;"r"
         bne :+

         lda repeat
         eor #1
         sta repeat
         jmp iloop

;        lda $dc01
;		 cmp #%01111111  ;"STOP"
;		bne :+

:         cmp #$89 ;F2
         bne :+
         lda #0
         sta playing     ;Mark as Paused
         lda #%00011011  ;Screen On
         sta $d011
         lda #%00011111 ;Clear All
         sta $dd0d

         jsr LAB_FDA3  ;jsr $FF84  ;initialize I/O devices
         jsr _STOPSIDP
         rts
         ;jmp ($fffc)

:       
        jmp iloop

         .endscope

;------------------------------------------		 
setSamplerate:

		 ldx _sampleRate
         lda $02a6 ;delay $80 NTSC #$7b PAL
		 beq :+
		 lda sampleRateNTSC,x
         sta $dd04 ;Timer A, Count Lo
		 bne :++
:		 lda sampleRatePAL,x   
		 sta $dd04
:		 rts
;---------------------------------------
;---------------Skip Other Chunks--------------------------
.export _skip
_skip: 

                                       
         lda _subchsz+1
         ora _subchsz+2
         beq skippart

skipfull: ;Skip Full Pages

         lda #$00     ;256 Bytes
         jsr loadnton

         dec _subchsz+1
         bne skipfull

         lda _subchsz+2
         beq skippart

         dec _subchsz+2
         jmp skipfull

skippart: ;Skip Partial Page

         lda _subchsz+0
         jsr loadnton
         rts
		 
;=====================loadntoa==================	
	 
loadntoa: ;Load # bytes to an address
         ;A      -> # Bytes to load
         ;RegPtr -> Target address

         ;Note: $00 = Load 256 Bytes
		.scope
       
         sta limit+1
		 sta limit0+1
         stx next+4
		 stx flag0+1
         sty next+5
		 sty flag0+2

         ldy #0
		 lda _sampleRate
		 cmp #2
		 bne next
		 lda _sidDigimax
		 bne next
		 
next0:	 jsr chrin
		 lsr
		 lsr
		 lsr
		 lsr
flag0:   sta $ffff,y           ;Self-Mod
         iny
limit0:  cpy #$ff              ;Self-Mod
         bne next0
		 rts
		 
next:    jsr chrin
         sta $ffff,y           ;Self-Mod
         iny
limit:   cpy #$ff              ;Self-Mod
         bne next

         rts
         .endscope


;=========================================		
loadnton: ;Load # bytes to /dev/asciiz
          ;A -> # Bytes to load

         ;Note: $00 = Load 256 Bytes
		.scope
         sta limit1+1

         ldy #0

:        jsr chrin    ;Load it, toss it.
         iny
limit1:   cpy #$ff              ;Self-Mod
         bne :-

         rts
        .endscope

;================Load 8-Bit Data Chunk====================
.export _load8bit
_load8bit: 
         
         ;If chunk size > _maxmem
         ;  Reduce chunk size to _maxmem
         ;  Output truncated message
		 
		 ;jsr copyChunksizeToDatasz16Bit ;duvide by 2
		 ;setByteRate16Bit
		
		 jsr copyChunksizeToDatasz8Bit


         ;Configure RAM for sequential
         ;page incrementing.

         ldx #0
         lda #0
         jsr cnframpg 
		 
	jsr load8bitData

	rts

	
;=======================================
copyChunksizeToDatasz8Bit:
		.scope
         lda _subchsz+3
         cmp _maxmem+3
         bcc valid
         bne over

         lda _subchsz+2
         cmp _maxmem+2
         bcc valid
         bne over

         lda _subchsz+1
         cmp _maxmem+1
         bcc valid
         bne over

         lda _subchsz+0
         cmp _maxmem+0
         bcc valid
         beq valid

over:     ;Data Over Maximum Memory Size
         lda _maxmem+0
         sta _subchsz+0

         lda _maxmem+1
         sta _subchsz+1

         lda _maxmem+2
         sta _subchsz+2

         lda _maxmem+3
         sta _subchsz+3

valid:
         ;Copy chunk size to datasz

         lda _subchsz+0
         sta datasz+0

         lda _subchsz+1
         sta datasz+1

         lda _subchsz+2
         sta datasz+2

         lda _subchsz+3
         sta datasz+3
		 rts
		.endscope

;================================================		 
load8bitData:
		 .scope
         ;Check for bizarre case where
         ;total data size <= 256 bytes

         lda _subchsz+1
         ora _subchsz+2
         beq loadpart

         clc
         ldx #3
         stx xpos
         ldy #1
      ;  sty ypos
         jsr plot

loadfull: ;Load Full Pages
         
         ldy #0
         lda _sidDigimax
		 bne :++
		 lda _sampleRate
		 cmp #2
		 bcc :++
:		 jsr chrin
		 lsr
		 lsr
		 lsr
		 lsr
         sta $de00,y  ;GeoRAM Window
         iny
         bne :-      ;256 Bytes
		 beq :++
		 
 :       jsr chrin
         sta $de00,y  ;GeoRAM Window
         iny
         bne :-      ;256 Bytes
       
;------------------------------------------------
:        lda _subchsz+1
         and #%00000011
         bne next

@code:    lda #$fb ;60  ;$a6 ;Hash proc, each 1KB
         jsr chrout
         sec
         jsr plot
         cpy #39
         bcc next
         inc xpos
         ldx xpos
		 cpx #22
		 bcc :+
		 ldx #3
		 stx xpos
		 lda @code+1
		 eor #1
		 sta @code+1
 :       ldy #1
		 
         clc
         jsr plot
;------------------------------------------------

next:   jsr incrampg

         dec _subchsz+1
         bne loadfull

         lda _subchsz+2
         beq loadpart

         dec _subchsz+2
         jmp loadfull

loadpart: ;Load Final Partial Page

         lda _subchsz+0
         ldx #$00  ;GeoRAM Window
         ldy #$de
         jsr loadntoa

         ;Close File
         ;Ignoring extra chunks

         rts

 ;        jmp closfile
         .endscope
.if 1		
;===================load16bit======================	

.export _load16bit
_load16bit:	
          ;Load 16-Bit Data Chunk
          ;Downsample to 8-Bit and
          ;adjust datasize to half
         .scope

         ;Enable SID Noise for Random
         lda #$ff
         sta $d40e ;Max Freq Lo Voice3
         sta $d40f ;Max Freq Hi Voice3
         lda #%10000000
         sta $d412 ;Noise Form, Silent

         ;Downsample 16-bit to 8-bit.
         ;Chunk size is 2x datasz.
         ;Copy chunksize/2 to datasz.
         ;Divide ByteRate by 2.

         ;If datasz > maxmem
         ;  Reduce datasize to maxmem
         ;  Output truncated message
         ;  Copy datasz to chunksize
		 
        jsr copyChunksizeToDatasz16Bit ;divide by 2
         ;Check if datasz > maxmem
	    jsr setByteRate16Bit
        jsr _saveSize


         ;Configure RAM for sequential
         ;page incrementing.

         ldx #0
         lda #0
         jsr cnframpg
		 
	 jsr load16bitData
	 rts
		.endscope
.endif

;========================================		 
load16bitData:
		.scope
         ;Check for bizarre case where
         ;total data size <= 256 bytes

         lda _subchsz+1
         ora _subchsz+2
         bne :+ 
		 jmp loadpart

         ;Samples are Signed 16-Bit
         ;Little Endian. Downsampled
         ;to Unsigned 8-Bit with audio
         ;dithering from SID noise.
		 
:		 clc
         ldx #3
         stx xpos
         ldy #1
      ;  sty ypos
         jsr plot

loadfull: ;Load Full Pages

         ldy #0

:        jsr chrin    ;Fetch Lo-Byte
         clc
         adc $d41b    ;C <- Dither Bit
         php

         jsr chrin    ;Fetch Hi-Byte
         eor #$80     ;Signed->Unsigned

         plp
         adc #0       ;Add Dither Bit
		 sta tmp1

         lda _sidDigimax
		 bne :+
		 lda _sampleRate
		 cmp #2
		 bcc :+
		 lda tmp1
		 lsr
		 lsr
		 lsr
		 lsr
         sta $de00,y  ;GeoRAM Window
         iny
         bne :-      ;256 Bytes
		 beq :++
		 
 :       lda tmp1
         sta $de00,y  ;GeoRAM Window
         iny
         bne :--      ;256 Bytes

;----------plot dot--------------		 
:		 lda _subchsz+1
		 and #%00000011
         bne next

@code:    lda #$fb ;60  ;$a6 ;Hash proc, each 1KB
         jsr chrout
         sec
         jsr plot
         cpy #39
         bcc next
         inc xpos
         ldx xpos
		 cpx #22
		 bcc :+
		 ldx #3
		 stx xpos
		 lda @code+1
		 eor #1
		 sta @code+1
 :       ldy #1
		 
         clc
         jsr plot
;---------------------------------
  
next:    jsr incrampg

         dec _subchsz+1
         bne loadfull

         lda _subchsz+2
         beq loadpart

         dec _subchsz+2
         jmp loadfull

loadpart: ;Load Final Partial Page

         lda _subchsz+0
         sta partsz+1

         ldy #0

:         jsr chrin    ;Fetch Lo-Byte
         clc
         adc $d41b    ;C <- Dither Bit
         php
         
         jsr chrin    ;Fetch Hi-Byte
         eor #$80     ;Signed->Unsigned

         plp
         adc #0       ;Add Dither Bit

         sta $de00,y  ;GeoRAM Window
         iny
partsz:  cpy #$ff           ;Self-Mod
         bne :-
		rts
         ;Close File
         ;Ignoring extra chunks

         ;jmp closfile
         .endscope

;=================================
setByteRate16Bit:
		.scope
         lda datasz+3
         cmp _maxmem+3
         bcc valid
         bne over

         lda datasz+2
         cmp _maxmem+2
         bcc valid
         bne over

         lda datasz+1
         cmp _maxmem+1
         bcc valid
         bne over

         lda datasz+0
         cmp _maxmem+0
         bcc valid
         beq valid

over:     ;Data Over Maximum Memory Size
         lda _maxmem+0
         sta _subchsz+0
         sta datasz+0

         lda _maxmem+1
         sta _subchsz+1
         sta datasz+1

         lda _maxmem+2
         sta _subchsz+2
         sta datasz+2

         lda _maxmem+3
         sta _subchsz+3
         sta datasz+3

         ;Output Truncated Message

         ;lda #$06   ;Insufficient Memory
         ;jsr msgout

valid:

         ;lda #$0b ;Loading/DownSamp. Msg
         ;jsr msgout

         ;Divide ByteRate by 2.

         lsr _byterate+3
         ror _byterate+2
         ror _byterate+1
         ror _byterate+0
		 
	rts
	.endscope
		
;======================================
;Copy chunksize/2 to datasz
copyChunksizeToDatasz16Bit:
		.scope
         lda _subchsz+3
         lsr a
         sta _subchsz+3
         sta datasz+3

         lda _subchsz+2
         ror a
         sta _subchsz+2
         sta datasz+2

         lda _subchsz+1
         ror a
         sta _subchsz+1
         sta datasz+1

         lda _subchsz+0
         ror a
         sta _subchsz+0
         sta datasz+0
		 rts		 
		 .endscope
;==============[ Playback Control ]==================

;Routines:
;
; resume - Resume Playback
; pause  - Pause Playback
; dostop - Pause and Rewind
; rewind - Reset Play Index
; back5  - Skip Back     5 Seconds
; fwrd10 - Skip Forward 10 Seconds
;

playing:  .byte 1          ;Playing State
repeat:   .byte 0          ;Repeat  State

resume:   ;Resume Playback
         .scope
         lda playing
         beq *+3
         rts            ;Already Playing

         lda #1
         sta playing    ;Mark as Playing

         ;Turn off the screen.
         lda #%00001011
         sta $d011

         ;Set current GeoRAM Page
         ldx playidx+1
         lda playidx+2
         jsr setrampg

         ;Leave playidx unchanged

         ;Enable CIA2 Timer A NMI

         lda #%10000001 ;Enable Timer A
         sta $dd0d

         rts
         .endscope

pause:    ;Pause Playback
         .scope
         lda playing
         bne *+3
         rts             ;Already Paused

         lda #0
         sta playing     ;Mark as Paused

         ;Leave playidx unchanged

         ;Prevent CIA2 Timer A NMI

         lda #%00011111 ;Clear All
         sta $dd0d

         rts
         .endscope

dostop:   ;Pause and Rewind
         .scope

		 jsr pause
		 
         ;Turn on the screen.
         lda #%00011011
         sta $d011

         jmp rewind
         .endscope

rewind:   ;Reset Playback Index
         .scope
         lda playing
         pha
         jsr pause

         lda #$00
         sta playidx+0
         sta playidx+1
         sta playidx+2
         sta playidx+3

         pla
         beq *+5
         jsr resume

         rts
         .endscope

back5:    ;Skip Back 5 Seconds
         .scope
         lda playing
         pha
         jsr pause

         ;playidx -= _byterate*5

         ldx #4

next:     ;playidx -= _byterate
         sec

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
         bpl next

         ;if playidx > datasz
         ;  playidx <- 0,0,0,0

         lda playidx+3
         cmp datasz+3
         bcc valid
         bne under

         lda playidx+2
         cmp datasz+2
         bcc valid
         bne under

         lda playidx+1
         cmp datasz+1
         bcc valid
         bne under

         lda playidx+0
         cmp datasz+0
         bcc valid
         beq valid

under:    ;Underflew, reset to zero
         lda #0
         sta playidx+0
         sta playidx+1
         sta playidx+2
         sta playidx+3

valid:    pla
         beq *+5
         jsr resume

         rts
         .endscope

fwrd10:   ;Skip Forward 10 Seconds
         .scope
         lda playing
         pha
         jsr pause

         ;playidx += _byterate*10

         ldx #9

next:     ;playidx += _byterate
         clc

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
         bpl next

         ;if playidx > datasz
         ;  playidx <- datasz
         ;  pause
         ;else
         ;  resume

         lda playidx+3
         cmp datasz+3
         bcc valid
         bne over

         lda playidx+2
         cmp datasz+2
         bcc valid
         bne over

         lda playidx+1
         cmp datasz+1
         bcc valid
         bne over

         lda playidx+0
         cmp datasz+0
         bcc valid
         beq valid

over:     ;Overflew. Set to datasz.
         lda datasz+0
         sta playidx+0

         lda datasz+1
         sta playidx+1

         lda datasz+2
         sta playidx+2

         lda datasz+3
         sta playidx+3

         pla
         rts ;Don't resume

valid:    pla
         beq *+5
         jsr resume

         rts
         .endscope


;===============[ DigiMax-NMI Playback ]==============


;NMI Timing

;Initial NMI Sequence: 7
;KERNAL NMI Vector:    7

play1chn: ;Output a Mono Sample
         .scope

         ;Read CIA2 Interupt Register
         bit $dd0d   ;Ready for next NMI

                     ;18

         ;Backup CPU Registers
         pha         ;3
         txa         ;2
		 pha         ;3

         ldx playidx ;3

         ;Update playidx

         inc playidx  ;5
         beq skipsamp ;2 not taken

         lda $de00,x ;4 ;A <- Sample
         ldx #%00000011 ;Left Channel
         stx $dd00
         sta $dd01   ;10

         ldx #%00000111 ;Right Channel
         stx $dd00
         sta $dd01   ;10
		 
		 lsr
         lsr
         lsr
         lsr
         sta tmp2

         ;Restore CPU Registers
         pla         ;4
         tax         ;2
         pla         ;4

         rti         ;6

                  ;---------------------
                  ;  No RAM Page Change
                  ;
                  ;  76 Cycles

skipsamp:
         ;Page Complete, Update RAM Page
                      ;37 up to here

         inc playidx+1 ;5
         bne *+4       ;2
         inc playidx+2 ;5

         lda geopghi   ;3
         ldx geopglo   ;3

         sta $dfff     ;4
         stx $dffe     ;4

         ;Restore CPU Registers
         pla         ;4
         tax         ;2
         pla         ;4

         rti           ;6
                  ;---------------------
                  ;    79 Cycles
                  ;
                  ;If RAM Page Changes
         .endscope


;============[ SID-NMI Playback ]===============


;NMI Timing

;Initial NMI Sequence: 7
;KERNAL NMI Vector:    7

playSIDchn: ;Output a Mono Sample
         .scope

         ;Read CIA2 Interupt Register
         bit $dd0d   ;Ready for next NMI

                     ;18

         ;Backup CPU Registers
         pha         ;3
         txa         ;2
		 pha         ;3

         ldx playidx ;3

         ;Update playidx

         inc playidx  ;5
         beq skipsamp ;2 not taken

         lda $de00,x ;4 ;A <- Sample
         lsr
         lsr
         lsr
         lsr
         sta $d418
         sta tmp2

         ;ldx #%00000011 ;Left Channel
         ;stx $dd00
         ;sta $dd01   ;10

         ;ldx #%00000111 ;Right Channel
         ;stx $dd00
         ;sta $dd01   ;10

         ;Restore CPU Registers
         pla         ;4
         tax         ;2
         pla         ;4

         rti         ;6

                  ;---------------------
                  ;  No RAM Page Change
                  ;
                  ;  76 Cycles

skipsamp:
         ;Page Complete, Update RAM Page
                      ;37 up to here

         inc playidx+1 ;5
         bne *+4       ;2
         inc playidx+2 ;5

         lda geopghi   ;3
         ldx geopglo   ;3

         sta $dfff     ;4
         stx $dffe     ;4

         ;Restore CPU Registers
         pla         ;4
         tax         ;2
		 pla         ;4

         rti           ;6
                  ;---------------------
                  ;    79 Cycles
                  ;
                  ;If RAM Page Changes
         .endscope
		 
;===============[ DigiMax-NMI 16Khz Playback ]==============
;NMI Timing

;Initial NMI Sequence: 7
;KERNAL NMI Vector:    7

play22Khz: ;Output a Mono Sample
         ;.scope

         ;Read CIA2 Interupt Register
         bit $dd0d   ;Ready for next NMI
         pha         ;3
		 inc probe+1
         lda probe+1 ;5
         beq :+ ;2 not taken
		 
probe:   lda $de00 ;4 ;A <- Sample
         ;sta $dd01   ;10
label:	 sta $d418
		 
         pla         ;4
         rti         ;6

                

:
         ;Page Complete, Update RAM Page
                      ;37 up to here

         inc playidx+1  ;5
         bne :+         ;2
         inc playidx+2  ;5

:        lda geopghi   ;3
		 sta $dfff     ;4
         lda geopglo   ;3
         sta $dffe     ;4
		 
		lda $dc01
		cmp #$ef
		bne:+
		lda #%00011111 ;Clear All
        sta $dd0d
		sta exitNMI
		
         ;Restore CPU Registers
:        pla         ;4
         rti           ;6
                  ;---------------------
                  ;    79 Cycles
                  ;
                  ;If RAM Page Changes
       ;  .endscope
 		 
;===========================================

;----[ Memory Manage ]------------------

incrampg: ;Increment GeoRAM Page
         inc cnframpg-2
         bne *+5
         inc cnframpg-1

         ldx cnframpg-2
         lda cnframpg-1

         jmp setrampg

         .byte 0,0

cnframpg: ;Config GeoRAM Page Sequence
         ;X -> Lo Byte
         ;A -> Hi Byte
         stx cnframpg-2
         sta cnframpg-1

         ;Fallthrough...

setrampg: ;Set GeoRAM Page
         ;X -> Lo Byte
         ;A -> Hi Byte
         .scope

         stx lobyte

         asl lobyte
         rol a
         asl lobyte
         rol a

         sta $dfff
         stx $dffe

         rts
         .endscope
		 

;=========================================
.export _checkSize
_checkSize:
		lda #$3f
		sta $dffe
		lda #$7f  ;for 2 Mb Georam
		sta $dfff
		ldy #$0
:		lda $def8,y
		sta _byterate,y
		iny 
		cpy #4
		bcc :-
		
        ldy #$0
:       lda $defc,y
        sta _subchsz,y
        iny 
        cpy #4
        bcc :-
		lda #0
		sta $dffe
		sta $dfff
		
;Copy chunk size to datasz

         lda _subchsz+0
         sta datasz+0

         lda _subchsz+1
         sta datasz+1

         lda _subchsz+2
         sta datasz+2

         lda _subchsz+3
         sta datasz+3

         ;Configure RAM for sequential
         ;page incrementing.

         ldx #0
         lda #0
         jsr cnframpg
		 rts

;=============================================
.export _saveSize
_saveSize:	
		lda #$3f
		sta $dffe
		lda #$7f  ;for 2 Mb Georam
		sta $dfff
		ldy #$0
:		lda _byterate,y
		sta $def8,y
		iny 
		cpy #4
		bcc :-
        ldy #$0
:       lda _subchsz,y
        sta $defc,y
        iny 
        cpy #4
        bcc :-
		lda #0
		sta $dffe
		sta $dfff
		rts


.export _detectSID
_detectSID:
		.scope
		ldx #24
        lda #0
loop:    sta $d400,x
        dex
        bpl loop

	; main routine
        lda #$02
		sta $d40f
		lda #$30
		sta $d412
		ldy #$00
		ldx #$00
sl3: 	lda $d41b
		bmi sl2
		dex
		bne sl3
		dey
		bne sl3
		beq sl4
sl2:	lda #$01 	; 1 = 8580
		rts
sl4:	lda #0      ; 0 = 6581
		rts
		.endscope

.export _SIDINIT	
_SIDINIT:		;init SID 
	lda #0
	tax		;transfer accumilator to x register
	tay		;transfer accumilator to y register
	jsr SIDLOADPOS ;jump to SIDLOADPOS, return
	rts 
	
_SIDPLAY:
	sei
	LDX #<IRQ	;lo-byte
	LDY #>IRQ	;hi-byte
	STX $0314
	STY $0315

	LDA #$00	;raster pos
	STA $D012

	LDA #$7F	;cia enable interrupt
	STA $DC0D
	LDA #$1B	
	STA $D011	;vertical pos 
	LDA #$01
	STA $D01A	;raster input signals from vic (sync)
	LDA #$00
	CLI
	RTS
	
IRQ:
	INC $D019
	LDA #$00
	STA $D012	

	JSR SIDSTEP	;step sid
	JMP $EA31	;jump to kernal stndard input service routines
	
SIDSTEP: 		;step SID
	jsr SIDPLAYPOS  ;jump to SIDPLAYPOS, return
	rts
	
_STOPSIDP:
		sei
		lda #$81
		sta $dc0d
		sta $dd0d
		lda #$00
		sta $d019
		sta $d01a
		lda #$31
		sta $0314
		lda #$ea
		sta $0315
		
		lda #0
		ldy #25
:		sta $d400-1,y
		dey
		bne :-
;		jsr $FF84  ;initialize I/O devices
		cli
		rts

;=====================================================
		
.export _copyDataColor
_copyDataColor:

		 ldx #0 
:		 jsr  BASIN
		 sta $e000,x
		 inx
		 bne :-
:		 jsr  BASIN
		 sta $e100,x
		 inx
		 bne :-
:		 jsr  BASIN
		 sta $e200,x
		 inx
		 bne :-
:		 jsr  BASIN
		 sta $e300,x
		 inx
		 bne :-
:		 jsr  BASIN
		 sta $e400,x
		 inx
		 bne :-
:		 jsr  BASIN
		 sta $e500,x
		 inx
		 bne :-
:		 jsr  BASIN
		 sta $e600,x
		 inx
		 bne :-
:		 jsr  BASIN
		 sta $e700,x
		 inx
		 bne :-


:		 lda $ff00,x
		 sta $ff00,x
		 inx
		 bne :-
		 rts
;=======================================================

.if 1		
.export _showKoala	
_showKoala:
		.scope
		lda #1
	    sta koalaFlag

		jsr copyColor
		
      lda #$3b ;<--- Turn on bitmap mode
      ldx #$18 ;<--- Turn on all bitmap characters     
      ldy #$03
      sta $d011
      stx $d018
      stx $d016
      sty $dd00
	  
hold:   lda $dc01
       cmp #$ef
       bne hold
	   
	  lda #$1b ;<--- Turn on bitmap mode
      ldx #$17 ;<--- Turn on all bitmap characters
      ldy #$c8
      sta $d011
      stx $d018
      sty $d016
      
       rts
	   .endscope
.endif



.if 1
.export _downloadKoala
		
_downloadKoala:

		.scope
		
	  lda #$3b ;<--- Turn on bitmap mode
      ldx #$18 ;<--- Turn on all bitmap characters     
      ldy #$03
      sta $d011
      stx $d018
      stx $d016
      sty $dd00
      lda #0
      sta $dfff
	  lda #1
	  sta koalaFlag
		
		
start: 	lda #$20
		sta self+2
        lda #0
        sta $dffe
        ;sta $dfff
		sta self+1
        ldx #$00
        ldy #$00
		
loop1:   lda $de00,x
self:   sta $2000,x
	    inx 
	    bne loop1
	    inc self+2
        iny 
        sty $dffe
        cpy #$1f    
        bne loop1
		
:  	lda $de00,x
    sta $3f00,x
	inx 
	cpx #$40
	bne :-
		
	lda #$e0
	sta self1+2
    lda #0
	sta self1+1
		
		
loop2:   lda $de00,x	
self1:   sta $e000
		inc self1+1
		bne :+
		inc self1+2
:    	inx
        bne loop2
        iny 
        sty $dffe
        cpy #$27   ;prg size 0801-c000
        bne loop2
		
:  	lda $de00,x
    sta $e700,x
	inx 
	cpx #$d1
	bne :-
	
	jsr copyColor

check:	   jsr getin
	       beq check
		   cmp #$20
		   bne :+
		   inc $d021
		   jmp check
:          cmp #$30     ;"0"
           beq geoDFFF
           cmp #$31     ;"1"
           beq geoDFFF
           cmp #$32     ;"2"
           beq geoDFFF
           cmp #$33    ;"3"
           beq geoDFFF
           cmp #$34     ;"4"
           beq geoDFFF
           cmp #$35     ;"5"
           beq geoDFFF
           cmp #$36     ;"6"
           beq geoDFFF
           cmp #$37     ;"7"
           beq geoDFFF
           cmp #$38     ;"8"
           beq geoDFFF
           cmp #$39     ;"9"
           beq geoDFFF
		   cmp #$51     ;"q"
           beq :++
		   jmp check
		   
geoDFFF:   cmp #$30
		   bne:+
		   lda #10
		   sta $dfff
		   jmp start
:		   sec
           sbc #$31
           sta $dfff
 	       jmp start
	   


	   
:      lda #$1b ;<--- Turn on bitmap mode
      ldx #$17 ;<--- Turn on all bitmap characters
      ldy #$c8
      sta $d011
      stx $d018
      sty $d016
	  rts
		.endscope
.endif

;-----------------copyColor--------------
copyColor:	    
		sei 
		dec $01
		ldx #$00
loop:	lda colorData,x
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
		bne loop
		lda colorData+$7d0
		sta colorRam+$3e8
        lda $e7d0  ;backgroundcolour
        sta $d021
		inc $01
		cli
		rts

  ;=======================================================

.if 1           
.export _showSEQ      
_showSEQ:
                .scope 


				;clc
				;ldx #3
				;stx xpos
				;ldy #1
				;sty ypos
				;jsr plot

                jsr $e544             

back1:          ldx #$02      ; filenum;ber 2
                jsr $ffc6     ; call chkin (file 2 now used as input)
                
                
                
                lda #$00        ;zero line count
                sta linecount
back:           lda #$00    ;zero char count
                sta charcount
                        
next4:          jsr $ffb7 ;lda $90              ;chech st byte
                bne eof   ;end of file
                jsr $ffe4  ;$ffcf       ;get character from file getin
                cmp #$0a
                beq :+
                cmp #$0d   ;return?
                bne noreturn
:               lda #$0d
back2:          jsr $ffd2  ;print return
                inc linecount   
                lda linecount
                cmp #22   ;22 lines?
                bcc back  ;not yet
                ldy #$00
next:           lda text,y
                jsr $ffd2   
                iny 
                cpy #$06
                bne next
                jsr $ffcc   ;restore keyboard input
next1:          jsr $ffe4   ;get a chracter
                cmp #$00
                beq next1
                cmp #$51    ;is it q?
                beq exit   
                ldy #$00        ;erase more
                lda #$14    ;chr$ ins/del
next2:          jsr $ffd2
                iny 
                cpy #$06
                bne next2
                beq back1
noreturn:       tay        ;save a
                and #$7f   ;strip high bit
                cmp #$20        ;less than 32
                bcs next3   ;no so restore A
                ldy #$2e    ;yes, substitute dot
next3:          tya
                sta tmp 
                ldy charcount
                cpy #39
                bcs next5  ;yes, so skip printing
                inc charcount
                jsr $ffd2   ;print character
                bne next4   ;continue line
                beq next4
;endfile        jsr $ffcc   
;exit           rts 
next5:      
                lda #0
                sta charcount
                lda #$0d
                jsr $ffd2 
                lda tmp
                inc charcount
                jmp back2

eof:
                and #$40      ; end of file?
;               beq close   ;.readerror
close:
                lda #$02      ; filenumber 2
                jsr $ffc3     ; call close

                jsr $ffcc     ; call clrchn
hold:           jsr $ffe4   ;get a chracter
                beq hold
                rts
                
exit:           lda #$02      ; filenumber 2
                jsr $ffc3 
                rts

linecount: .byte 0               
charcount: .byte 0
tmp:       .byte 0
text: .byte "-MORE-"
                .endscope
                
.endif        

;=======================================================

koalaFlag: .byte 0

.if 1          
.export _showINFO      
_showINFO:
                .scope 
				lda koalaFlag
				beq:+
				rts
:               lda #<instructions
                sta $fb
                lda #>instructions
                sta $fc
               
                jsr $e544

back1:               
                lda #0        ;zero line count
                sta linecount
back:           lda #0        ;zero char count
                sta charcount
       
next:           ldy #0
                lda ($fb),y      ;get character 
                beq hold
                cmp #$0a
                beq :+
                cmp #$0d   ;return?
                bne noreturn
:               lda #$0d

back2:          jsr $ffd2  ;print return
                inc linecount   
                lda linecount
                cmp #22 ;# lines?
                bcs :+
                inc $fb
                bne back
                inc $fc
                jmp back 

:               ldx #0
:               lda text,x
                jsr $ffd2   
                inx 
                cpx #$06
                bne :-
              
:               jsr $ffe4   ;get a chracter
              
                beq :-
                cmp #$51    ;is it q?
                beq exit   
                ldx #0        ;erase more
                lda #$14    ;chr$ ins/del
:               jsr $ffd2
                inx 
                cpx #$06
                bne :-
                beq back1
noreturn:       tax        ;save a
                and #$7f   ;strip high bit
                cmp #$20        ;less than 32
                bcs :+   ;no so restore A
                ldx #$2e    ;yes, substitute dot
:               txa
                sta tmp 
                ldx charcount
                cpx #39
                bcs :+  ;yes, so skip printing
                inc charcount
                jsr $ffd2   ;print character
                inc $fb    
                bne next   ;continue line
                inc $fc 
                bne next  


:      
                lda #0
                sta charcount
                lda #$0d
                jsr $ffd2 
                lda tmp
                inc charcount
                jmp back2


hold:           jsr $ffe4   ;get a chracter
                beq hold
exit:           rts
                
linecount: .byte 0               
charcount: .byte 0
tmp:       .byte 0
text: .byte "-MORE-"
                .endscope
                
.endif        

LAB_FDA3:
        LDA     #$7F                    ; disable all interrupts
        STA     $DC0D                ; save VIA 1 ICR
        STA     $DD0D                ; save VIA 2 ICR
        STA     $DC00                ; save VIA 1 DRA, keyboard column drive
        LDA     #$08                    ; set timer single shot
        STA     $DC0E                ; save VIA 1 CRA
        STA     $DD0E                ; save VIA 2 CRA
        STA     $DC0F                ; save VIA 1 CRB
        STA     $DD0F                ; save VIA 2 CRB
        LDX     #$00                    ; set all inputs
        STX     $DC03                ; save VIA 1 DDRB, keyboard row
        STX     $DD03                ; save VIA 2 DDRB, RS232 port
        STX     $D418                ; clear the volume and filter select register
        DEX                             ; set X = $FF
        STX     $DC02                ; save VIA 1 DDRA, keyboard column
        LDA     #$07                    ; DATA out high, CLK out high, ATN out high, RE232 Tx DATA
                                        ; high, video address 15 = 1,   video address 14 = 1
        STA     $DD00                ; save VIA 2 DRA, serial port and video address
        LDA     #$3F                    ; set serial DATA input, serial CLK input
        STA     $DD02                ; save VIA 2 DDRA, serial port and video address
        LDA     #$E6                    ; set 1110 0111, motor off, enable I/O, enable KERNAL,
                                                ; enable BASIC
        STA     $01                  ; save the 6510 I/O port
        LDA     #$2F                    ; set 0010 1111, 0 = input, 1 = output
        STA     $00                  ; save the 6510 I/O port direction register
LAB_FDDD:
        LDA     $02A6                ; get the PAL/NTSC flag
        BEQ     LAB_FDEC                ; if NTSC go set NTSC timing

                                                ; else set PAL timing
        LDA     #$25                    ;.
        STA     $DC04                ; save VIA 1 timer A low byte
        LDA     #$40                    ;.
        JMP     LAB_FDF3                ;.

LAB_FDEC:
        LDA     #$95                    ;.
        STA     $DC04                ; save VIA 1 timer A low byte
        LDA     #$42                    ;.
LAB_FDF3:
        STA     $DC05                ; save VIA 1 timer A high byte

        LDA     #$81                    ; enable timer A interrupt
        STA     $DC0D                ; save VIA 1 ICR
        LDA     $DC0E                ; read VIA 1 CRA
        AND     #$80                    ; mask x000 0000, TOD clock
        ORA     #$11                    ; mask xxx1 xxx1, load timer A, start timer A
        STA     $DC0E                ; save VIA 1 CRA
        JMP     $EE8E                ; set the serial clock out low and return
        rts 

;======================================================================

base = $07c0-160+(40/2)-(16/2);

var0: .byte 0
tmp3: .byte 0

.export _setScopeIRQ

_setScopeIRQ:
        sei
        LDX #<scopeIRQ       ;lo-byte
        LDY #>scopeIRQ       ;hi-byte
        STX $0314
        STY $0315

       ; LDA #$00        ;raster pos
       ; STA $D012

        ;LDA #$7F        ;cia enable interrupt
       ; STA $DC0D
       ; LDA #$1B        
       ; STA $D011       ;vertical pos 
        ;LDA #$01
        ;STA $D01A       ;raster input signals from vic (sync)
		lda #0
		sta tmp2
        CLI
        RTS

scopeIRQ:
                .scope 

                asl $d019
                ldx tmp2
                lda tmp3
                clc
                adc #$40         ;delay
                sta tmp3
                beq next0
                jmp next1

                ;clear column
next0:           ldx #15        ;numbers of columns
loop:            lda base-40,x   
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
                bpl loop
                jmp $ea31
                
next1:           lda #97         ;106  ;160  ;graphic symbol     
                sta base-240,x  ;$06a8,x
                sta base-200,x  ;$06d0,x
                sta base-160,x  ;$06f8,x
                sta base-120,x  ;$0720,x
                sta base-80,x   ;$0748,x
                sta base-40,x   ;$0770,x
                sta base,x      ;$0798,x
                
exit:            jmp $ea31
                .endscope 
				
.if 0		 
;----[ NMI Playback ]-------------------


;NMI Timing

;Initial NMI Sequence: 7
;KERNAL NMI Vector:    7

playSID16KHzchn: ;Output a Mono Sample
         .scope

         ;Read CIA2 Interupt Register
         bit $dd0d   ;Ready for next NMI

                     ;18

         ;Backup CPU Registers
         sta storeA ;pha         ;3
         stx storeX ;txa         ;2
				  ;pha         ;3

         ldx playidx ;3

         ;Update playidx

         inc playidx  ;5
         beq skipsamp ;2 not taken

         lda $de00,x ;4 ;A <- Sample
         sta $d418
      
         ;Restore CPU Registers
         ldx storeX  ;pla         ;4
         lda storeA  ;tax         ;2
        ; pla         ;4

         rti         ;6

                  ;---------------------
                  ;  No RAM Page Change
                  ;
                  ;  76 Cycles

skipsamp:
         ;Page Complete, Update RAM Page
                      ;37 up to here

         inc playidx+1 ;5
         bne *+4       ;2
         inc playidx+2 ;5

         lda geopghi   ;3
         ldx geopglo   ;3

         sta $dfff     ;4
         stx $dffe     ;4

         ;Restore CPU Registers
         ldx storeX  ;pla         ;4
         lda storeA  ;tax         ;2
				  ; pla         ;4

         rti           ;6
                  ;---------------------
                  ;    79 Cycles
                  ;
                  ;If RAM Page Changes
         .endscope
.endif	

.if 0
;---------------------------------------------------------------------------------
;void makecolour(void);
;---------------------------------------------------------------------------------
.export _makecolour1
_makecolour1: 
			lda #<_ATTRIBUTES
			ldx #>_ATTRIBUTES	
			jsr copy
			rts
			
;.export _makecolour
;_makecolour: 
;			lda #<_OTHELLO_ATTRIBUTES
;			ldx #>_OTHELLO_ATTRIBUTES
			
copy:		sta $fb
			stx $fc
			ldx #$00
:			ldy SCREENRAM,x
			lda($fb),y
			sta $d800,x
			ldy SCREENRAM+$100,x
			lda($fb),y
			sta $d900,x
			ldy SCREENRAM+$200,x
			lda($fb),y
			sta $da00,x
			ldy SCREENRAM+$2e8,x
			lda($fb),y
			sta $dae8,x
			inx
			bne :-
			rts
.endif	 		
;****************************************************************
;
; TMS Demo - Coleco ver 1.00 (C) Electric Adventures 2019
;
;****************************************************************

; Include Coleco defined values
    include "Coleco-Include.ASM"

PATSIZE:   EQU 73
SPRITECOUNT: EQU 1

;
; Set ROM header
           ORG        8000h
;** CARTRIDGE SOFTWARE POINTERS 8000H **
;        --------------------------------------------

;           DB       0AAh,055h       ;Cartridge present:  Colecovision logo
           DB       055h,0AAh       ;Cartridge present:  skip logo, Colecovision logo
           DW       0000           ;Pointer to the sprite name table
           DW       0000           ;Pointer to the sprite order table
           DW       0000           ;Pointer to the working buffer for WR_SPR_NM_TBL
           DW       CONTROLLER_BUFFER ;Pointer to the hand controller input areas
           DW       START      ;Entry point to the user program

;****************************************************************

rst_8:
       reti
       nop
rst_10:
       reti
       nop
rst_18:
       JP	RAND_GEN
rst_20:
       reti
       nop
rst_28:
       reti
       nop
rst_30:
       reti
       nop
rst_38:
       reti
       nop

       jp NMI

        db "TMS Demo/ELECTRIC ADVENTURES/2019"
;
; Start of application logic
START:
    ; set stack pointer
    LD	SP,StackTop	;128 bytes in length at 737fh

    ; Initialise sound
	LD	B,SoundDataCount	;Max number of active voices+effects
	LD	HL,SoundAddrs
	CALL	SOUND_INIT

    ; initialise clock
    LD	HL,TIMER_TABLE
    LD	DE,TIMER_DATA_BLOCK
    CALL INIT_TIMER

    ; Set screen mode 2,2
	CALL SETSCREEN2

    CALL INITRAM

    CALL CONTROLLER_INIT
    ;Enable both joysticks, buttons, keypads
    LD	HL,09b9bh
    LD	(CONTROLLER_BUFFER),HL

    ; Seed random numbers with a fixed number (nothing else to use?)
    LD HL,1967
    CALL SEED_RANDOM

    ;Enable timers
    CALL CREATE_TIMERS


TITLESCREEN:
    ; display our title screen
    CALL DISABLE_NMI
    ; Clear the screen
    CALL CLEARPAT

    ; Clean up in case the game left anything on screen
    CALL CLEARSPRITES
    CALL SPRWRT

    ; Load the character set, make all three sections the same
    CALL LOAD_CHR_SET

    ; now setup our initial screen layout

    ; our initial text
    LD HL,VRAM_NAME + 32*12 + 10
    CALL SETWRT
    LD HL,TITLE_TEXT
    CALL OUTPUT_TEXT

	CALL JOYTST ; clear joystick buffer
   	LD HL,OUTPUT_VDP_TITLE
	CALL SET_VDU_HOOK
    CALL ENABLE_NMI

SPLASH_TITLE2:
    LD	A,(HalfSecTimer)
	CALL	TEST_SIGNAL
	OR	A
    JR Z,SPLASH_TITLE2
    ; Any other actions on the title screen go here
	JR SPLASH_TITLE2


; Load the character set, make all three sections the same
LOAD_CHR_SET:
    LD HL,0
SLOOP:
    LD DE,TILESET_1_PAT
    PUSH HL
    LD BC,PATSIZE*8
    CALL LDIRVM
    POP HL
    ; now load colour attributes
    PUSH HL
    LD BC,VRAM_COLOR
    ADD HL,BC
    LD DE,TILESET_1_COL
    LD BC,PATSIZE*8
    CALL LDIRVM
    POP HL
    LD BC,800h
    ADD HL,BC
    LD A,H
    CP 18h
    JR C,SLOOP
    RET


; Init Ram for a new game
INITRAM:
    RET

; This is our routine called every VDP interrupt during normal game play
; - Do all VDP writes here to avoid corruption
VDU_WRITES:
    RET

; This is our routine called every VDP interrupt during the title screen
; - Do all VDP writes here to avoid corruption
OUTPUT_VDP_TITLE:
    RET

; output characters to the name table
; Video Ram write position already should be set
; HL = Pointer to text buffer to write, end at FFh
OUTPUT_TEXT:
    LD A,(HL)
    CP 255
    RET Z
    OUT (DATA_PORT),A
    INC HL
    JR OUTPUT_TEXT

; Title text
TITLE_TEXT:
    db 30,23,29,0,14,41,49,51,63,255

;**************************************************************************************************
; Include external data files
;**************************************************************************************************

    include "Coleco-TMSDemo-Patterns.ASM"


;**************************************************************************************************
; Sound and music data area
;**************************************************************************************************

; Bounce
bounce:
    DB 081h, 054h, 010h, 002h, 023h, 007h
    DB $90  ; end
    DW 0000h

sample:
    db 080h,02Eh,031h,7
    db 080h,053h,031h,7
    db 080h,053h,031h,7
    db 080h,094h,031h,7
    db 080h,094h,031h,7
    db 080h,08Fh,030h,7
    db 080h,0F0h,030h,7
    db 080h,02Eh,031h,7
    db 080h,01Dh,031h,7
    db 080h,02Eh,031h,7
    db 080h,0F0h,030h,7
    db 080h,067h,031h,7
    db 080h,01Dh,031h,7
    db 080h,01Dh,031h,7
    db 080h,07Dh,031h,7
    db 080h,0FEh,030h,7
    db 080h,00Dh,031h,7
    db 080h,0E2h,030h,7
    db 080h,00Dh,031h,7
    db 080h,07Dh,031h,7
    db 080h,053h,031h,7
    db 080h,02Eh,031h,7
    db 080h,0E2h,030h,7
    db 080h,040h,031h,7
    db 080h,067h,031h,7
    db 080h,094h,031h,7
    db 080h,040h,031h,7
    db 080h,040h,031h,7
    db 080h,094h,031h,7
    db 080h,094h,031h,7
    db 080h,01Dh,031h,7
    db 080h,01Dh,031h,7
    db 080h,053h,031h,7
    db 080h,0FEh,030h,7
    db 080h,00Dh,031h,7
    db 080h,0ABh,031h,7
    db 080h,02Eh,031h,7
    db 080h,0FEh,030h,7
    db 080h,094h,031h,7
    db 080h,053h,031h,7
    db 080h,0E2h,030h,7
    db 080h,0FEh,030h,7
    db 080h,040h,031h,7
    db 080h,0F0h,030h,7
    db 080h,053h,031h,7
    db 080h,0E2h,030h,7
    db 080h,0E2h,030h,7
    db 080h,01Dh,031h,7
    db 080h,094h,031h,7
    db 080h,0E2h,030h,7
    db 080h,094h,031h,7
    db 080h,07Dh,031h,7
    db 080h,094h,031h,7
    db 080h,00Dh,031h,7
    db 080h,0FEh,030h,7
    db 080h,07Dh,031h,7
    db 080h,094h,031h,7
    db 080h,0ABh,031h,7
    db 080h,0ABh,031h,7
    db 080h,040h,031h,7
    db 080h,067h,031h,7
    db 080h,067h,031h,7
    db 080h,02Eh,031h,7
    db 080h,07Dh,031h,7
    db 090h

sample2:
    db 080h,057h,033h,6
    db 080h,087h,030h,6
    db 080h,087h,030h,6
    db 080h,087h,030h,6
    db 080h,057h,033h,6
    db 080h,001h,030h,6 ;BLANK Note
    db 080h,01bh,032h,6
    db 080h,001h,030h,6 ;BLANK Note
    db 080h,057h,033h,6
    db 080h,08fh,030h,6
    db 080h,08fh,030h,6
    db 080h,08fh,030h,6
    db 080h,057h,033h,6
    db 080h,01bh,032h,6
    db 080h,01bh,032h,6
    db 080h,001h,030h,6 ;BLANK Note
    db 080h,057h,033h,6
    db 080h,097h,030h,6
    db 080h,097h,030h,6
    db 080h,097h,030h,6
    db 080h,057h,033h,6
    db 080h,001h,030h,6 ;BLANK Note
    db 080h,081h,032h,6
    db 080h,001h,030h,6 ;BLANK Note
    db 080h,057h,033h,6
    db 080h,097h,030h,6
    db 080h,097h,030h,6
    db 080h,097h,030h,6
    db 080h,057h,033h,6
    db 080h,081h,032h,6
    db 080h,081h,032h,6
    db 080h,001h,030h,6 ;BLANK Note
    db 080h,057h,033h,6
    db 080h,07fh,030h,6
    db 080h,07fh,030h,6
    db 080h,07fh,030h,6
    db 080h,057h,033h,6
    db 080h,001h,030h,6 ;BLANK Note
    db 080h,01bh,032h,6
    db 080h,001h,030h,6 ;BLANK Note
    db 080h,057h,033h,6
    db 080h,07fh,030h,6
    db 080h,07fh,030h,6
    db 080h,07fh,030h,6
    db 080h,057h,033h,6
    db 080h,03bh,032h,6
    db 080h,03bh,032h,6
    db 080h,001h,030h,6 ;BLANK Note
    db 080h,057h,033h,6
    db 080h,097h,030h,6
    db 080h,097h,030h,6
    db 080h,097h,030h,6
    db 080h,057h,033h,6
    db 080h,001h,030h,6 ;BLANK Note
    db 080h,081h,032h,6
    db 080h,001h,030h,6 ;BLANK Note
    db 080h,057h,033h,6
    db 080h,097h,030h,6
    db 080h,097h,030h,6
    db 080h,097h,030h,6
    db 080h,057h,033h,6
    db 080h,081h,032h,6
    db 080h,081h,032h,6
    db 090h

;**************************************************************************************************
; Sound settings
;**************************************************************************************************
SoundDataCount:	  EQU	7
Len_SoundDataArea: EQU	10*SoundDataCount+1	;7 data areas
SoundAddrs:
	DW	bounce,SoundDataArea     ; 1  ball bounce sound
	DW  sample,SoundDataArea+10  ; 2 music sample
	DW  sample2,SoundDataArea+10 ; 3 music sample
	DW  0,0

;**************************************************************************************************
; Standard Libraries
;**************************************************************************************************

    include "Coleco-Lib.ASM"

;**************************************************************************************************
; RAM Definitions
;**************************************************************************************************

; Sound Data area - 7 songs
SoundDataArea: DS Len_SoundDataArea



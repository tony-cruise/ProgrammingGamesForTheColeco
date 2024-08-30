;****************************************************************
;
; MegaBlast - Coleco ver 1.00 (C) Electric Adventures 2020
;
;****************************************************************

; Include Coleco defined values
    include "Coleco-Include.ASM"

PATSIZE:   EQU 71
SPRITECOUNT: EQU 11

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

    db "Mega Blast/ELECTRIC ADVENTURES/2020"
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

    ; Set screen mode 2,2 (16x16 sprites)
    CALL SETSCREEN2

    CALL CONTROLLER_INIT
    ;Enable both joysticks, buttons, keypads
    LD	HL,09b9bh
    LD	(CONTROLLER_BUFFER),HL

    ; Seed random numbers with a fixed number
    LD HL,1967
    CALL SEED_RANDOM

    ;Enable timers
    CALL CREATE_TIMERS

MAIN_SCREEN:
    ; Read joysticks to clear any false reads
    CALL JOYTST

     ; Initial Seed random with the time that has passed
    LD HL,(TIME)
    CALL SEED_RANDOM

	; disable interrupts
    CALL DISABLE_NMI

    ; Clean up in case the game left anything on screen
    CALL CLEARSPRITES
    CALL SPRWRT
    
    ; Clear the screen
    CALL CLEARPAT
 
    ; Main game logic loop
MLOOP:
    ; check that a base tick has occurred
    ; ensures consistent movement speed between 50 & 60Hz systems
    LD	A,(TickTimer)
    CALL	TEST_SIGNAL
    OR	A
    JR Z,MLOOP

    JR MLOOP

; This is our routine called every VDP interrup
; - Do all VDP writes here to avoid corruption
; Note:
; - The included VDP routine is already calling the 
;   sound update routines, and writing the sprite data
;   table to VRAM.
VDU_WRITES:
    RET

; Init Ram for a new game
INITRAM:
    RET
    
;**************************************************************************************************
; Sound and music data area
;**************************************************************************************************

; Bounce
bounce:
    DB 081h, 054h, 010h, 002h, 023h, 007h
    DB $90  ; end
    DW 0000h


;**************************************************************************************************
; Sound settings
;**************************************************************************************************
SoundDataCount:	  EQU	7
Len_SoundDataArea: EQU	10*SoundDataCount+1	;7 data areas
SoundAddrs:
	DW	bounce,SoundDataArea     ; 1  ball bounce sound
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



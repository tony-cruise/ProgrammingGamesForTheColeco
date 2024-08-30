;****************************************************************
;
; EA Game Template - Coleco ver 1.02 (C) Electric Adventures 2020
;
;****************************************************************
;FNAME "TEMPLATE.ROM"
;cpu z80
;
; Include Coleco defined values
    include "Coleco-Include.ASM"

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

    db "GAME TEMPLATE/ELECTRIC ADVENTURES/2020"
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

    ; Do all our VRAM setup
    ; NMI is currently disabled

    ; Send the two sprite definitions to the VDP
    LD HL,VRAM_SPRGEN
    LD DE,SPDATA
    LD BC,32*2
    CALL LDIRVM

    ; Clear the screen
    CALL CLEARPAT

    ; Clear the colour table
    LD HL,VRAM_COLOR
    LD BC,1800h
    LD A,071h ; Cyan on Black
    CALL FILVRM

    ; Load the character set, make all three sections the same
    LD HL,0
SLOOP:
    LD DE,CHRDAT
    PUSH HL
    LD BC,36*8
    CALL LDIRVM
    POP HL
    PUSH HL
    LD BC,VRAM_COLOR
    ADD HL,BC
    ; make numbers yellow
    LD BC,88
    LD A,0a1h
    CALL FILVRM
    POP HL
    LD BC,800h
    ADD HL,BC
    LD A,H
    CP 18h
    JR C,SLOOP

MAIN_SCREEN:
    ; Read joysticks to clear any false reads
    CALL JOYTST

    ; Initial Seed random numbers with a random number from BIOS
    CALL RAND_GEN
    CALL SEED_RANDOM

	; disable interrupts
    CALL DISABLE_NMI

    ; Clean up in case the game left anything on screen
    CALL CLEARSPRITES
    CALL SPRWRT
    
    ; Clear the screen
    CALL CLEARPAT
    LD HL,VRAM_NAME+12
    LD DE,MESG1
    LD BC,8
    CALL LDIRVM


    LD HL,VDU_WRITES
    CALL SET_VDU_HOOK
    CALL ENABLE_NMI

    ; Set initial position, colour and shape of the ball
    LD HL,04040h
    LD (SPRTBL),HL
    LD HL,00500h
    LD (SPRTBL+2),HL

    ; Set initial position, colour and shape of the bat
    LD HL,080A0H
    LD (SPRTBL+4),HL
    LD HL,00604h
    LD (SPRTBL+6),HL

    ; set initial velocity of ball (dx = 1, dy = 1)
    LD HL,00101h
    LD (BALL),HL

    ; Main game logic loop
MLOOP:
    ; check that a base tick has occurred
    ; ensures consistent movement speed between 50 & 60Hz systems
    LD	A,(TickTimer)
    CALL	TEST_SIGNAL
    OR	A
    JR Z,MLOOP

    CALL MOVE_BALL
    CALL MOVE_PLAYER
    JR MLOOP

; Move the player
MOVE_PLAYER:
    CALL JOYDIR
    BIT 1,A
    JR Z,NRIGHT
    ; move to the right
    LD A,(SPRTBL+5)
    CP 239
    RET Z
    INC A
    LD (SPRTBL+5),A
    RET
NRIGHT:
    BIT 3,A
    RET Z
    ; move to the left
    LD A,(SPRTBL+5)
    CP 0
    RET Z
    DEC A
    LD (SPRTBL+5),A
    RET

; move the Ball
MOVE_BALL:
    ; change the current y position
    LD A,(SPRTBL)
    LD B,A
    LD A,(BALL)
    ADD A,B
    LD (SPRTBL),A
    CP 0
    JR NZ, NOTTOP
    ; hit the top
    LD A,1
    LD (BALL),A
    LD B,1
    CALL PLAY_IT
    JR YDONE
NOTTOP:
    CP 175
    JR NZ, YDONE
    LD A,255
    LD (BALL),A
    LD B,1
    CALL PLAY_IT
YDONE:
    ; change the current x position
    LD A,(SPRTBL+1)
    LD B,A
    LD A,(BALL+1)
    ADD A,B
    LD (SPRTBL+1),A
    CP 0
    JR NZ, NOTLEFT
    ; hit the left
    LD A,1
    LD (BALL+1),A
    LD B,1
    CALL PLAY_IT
    JR XDONE
NOTLEFT:
    CP 239
    JR NZ, XDONE
    LD A,255
    LD (BALL+1),A
    LD B,1
    CALL PLAY_IT
XDONE:
    RET

; This is our routine called every VDP interrup
; - Do all VDP writes here to avoid corruption
; Note:
; - The included VDP routine is already calling the 
;   sound update routines, and writing the sprite data
;   table to VRAM.
VDU_WRITES:
    RET

CHRDAT:
    DB 000,000,000,000,000,000,000,000 ; 0  blank
    DB 124,198,198,198,198,198,124,000 ; 1  '0'
	DB 024,056,120,024,024,024,024,000 ; 2  '1'
    DB 124,198,006,004,024,096,254,000 ; 3  '2'
	DB 124,198,006,060,006,198,124,000 ; 4  '3'
    DB 024,056,088,152,254,024,024,000 ; 5  '4'
	DB 254,192,192,252,006,198,124,000 ; 6  '5'
    DB 124,198,192,252,198,198,124,000 ; 7  '6'
	DB 254,006,012,012,024,024,024,000 ; 8  '7'
    DB 124,198,198,124,198,198,124,000 ; 9  '8'
	DB 124,198,198,126,006,198,124,000 ; 10 '9'
    DB 056,108,198,198,254,198,198,000 ; 11 'A'
	DB 252,198,198,252,198,198,252,000 ; 12 'B'
    DB 124,230,192,192,192,230,124,000 ; 13 'C'
	DB 252,206,198,198,198,206,252,000 ; 14 'D'
    DB 254,192,192,248,192,192,254,000 ; 15 'E'
	DB 254,192,192,248,192,192,192,000 ; 16 'F'
    DB 124,198,192,192,206,198,124,000 ; 17 'G'
	DB 198,198,198,254,198,198,198,000 ; 18 'H'
    DB 254,056,056,056,056,056,254,000 ; 19 'I'
	DB 126,024,024,024,024,216,248,000 ; 20 'J'
    DB 198,204,216,240,248,204,198,000 ; 21 'K'
	DB 192,192,192,192,192,192,254,000 ; 22 'L'
    DB 130,198,238,254,214,198,198,000 ; 23 'M'
	DB 134,198,230,214,206,198,194,000 ; 24 'N'
    DB 124,238,198,198,198,238,124,000 ; 25 'O'
	DB 252,198,198,252,192,192,192,000 ; 26 'P'
    DB 124,198,198,198,214,206,124,000 ; 27 'Q'
	DB 252,198,198,252,248,204,198,000 ; 28 'R'
    DB 124,198,192,124,006,198,124,000 ; 29 'S'
	DB 254,056,056,056,056,056,056,000 ; 30 'T'
    DB 198,198,198,198,198,238,124,000 ; 31 'U'
	DB 198,198,198,238,108,108,056,000 ; 32 'V'
    DB 198,198,214,254,124,108,040,000 ; 33 'X'
	DB 198,238,124,056,124,238,198,000 ; 34 'Y'
    DB 198,238,124,056,056,056,056,000 ; 35 'Z'

MESG1: ; Template
    DB 030,015,023,026,022,011,030,015

SPDATA:
    db 003h,00Fh,01Fh,03Fh,07Fh,07Fh,0FFh,0FFh
    db 0FFh,0FFh,07Fh,07Fh,03Fh,01Fh,00Fh,003h
    db 0C0h,0F0h,0F8h,0FCh,0FEh,0FEh,0FFh,0FFh
    db 0FFh,0FFh,0FEh,0FEh,0FCh,0F8h,0F0h,0C0h
    db 000,000,000,000,000,000,000,000
    db 000,000,000,000,000,000,255,255
    db 000,000,000,000,000,000,000,000
    db 000,000,000,000,000,000,255,255

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

BALL:       DS 2

; Sound Data area - 7 songs
SoundDataArea: DS Len_SoundDataArea



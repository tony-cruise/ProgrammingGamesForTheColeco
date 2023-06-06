;****************************************************************
;
; MegaBlast - Coleco ver 1.00 (C) Electric Adventures 2014
;
;****************************************************************
FNAME "MEGABLAST.ROM"
cpu z80
;
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

    ; Set screen mode 2,2
	CALL SETSCREEN2

    ;Enable both joysticks, buttons, keypads
    LD	HL,09b9bh
    LD	(CONTROLLER_BUFFER),HL

    ; Seed random numbers with a fixed number
    LD HL,1967
    CALL SEED_RANDOM

    ;Enable timers
    CALL CREATE_TIMERS

TITLESCREEN:
    ; display our title screen
    CALL DISABLE_NMI
    ; Clear the screen
    CALL CLEARPAT

    ; Load the character set, make all three sections the same
    CALL LOAD_CHR_SET

    ; now setup the title screen layout
    LD HL,VRAM_NAME
    LD DE,TITLE_SCREEN_PAT
    LD BC,24*32
    CALL LDIRVM

	CALL JOYTST ; clear joystick buffer
   	LD HL,OUTPUT_VDP_TITLE
	CALL SET_VDU_HOOK
    CALL ENABLE_NMI

SPLASH_TITLE2:
	CALL JOYTST
	CP 255
	JR Z,NGAME
    LD	A,(HalfSecTimer)
	CALL	TEST_SIGNAL
	OR	A
    JR Z,SPLASH_TITLE2
    ; Any other actions on the title screen go here
	JR SPLASH_TITLE2

NGAME:
    CALL DISABLE_NMI
    CALL INITRAM
    ; Send the sprite definitions to the VDP
    LD HL,VRAM_SPRGEN
    LD DE,SPDATA
    LD BC,32*SPRITECOUNT
    CALL LDIRVM

    ; Load the character set, make all three sections the same
    CALL LOAD_CHR_SET

    ; now setup the title screen layout
    LD HL,VRAM_NAME
    LD DE,MAINLAYOUT
    LD BC,24*32
    CALL LDIRVM

MAIN_SCREEN:
    ; Read joysticks to clear any false reads
    CALL JOYTST

	LD HL,(TIME)
	LD (SEED),HL
	RR H
	RL L
	LD (SEED+2),HL

	; disable interrupts
    CALL DISABLE_NMI

    ; Clean up in case the game left anything on screen
	CALL CLEARSPRITES
	CALL SPRWRT

    ; now setup the main screen layout
	LD HL,VRAM_NAME
	LD DE,MAINLAYOUT
	LD BC,24*32
	CALL LDIRVM

    ; set position of player ship
    LD A,150
    LD (SPRTBL),A
    LD (SPRTBL+4),A
    LD A,120
    LD (SPRTBL+1),A
    LD (SPRTBL+5),A
    XOR A
    LD (SPRTBL+2),A
    LD A,4
    LD (SPRTBL+6),A
    LD A,05h
    LD (SPRTBL+3),A
    LD A,0fh
    LD (SPRTBL+7),A

	LD HL,VDU_WRITES
	CALL SET_VDU_HOOK
	CALL ENABLE_NMI

    ; Main game logic loop
MLOOP:
    ; check that a base tick has occurred
    ; ensures consistent movement speed between 50 & 60Hz systems
	LD	A,(TickTimer)
	CALL	TEST_SIGNAL
	OR	A
	JR Z,MLOOP2
    ; once per tick
    CALL MOVE_PLAYER
    CALL FIRE_PLAYER_BULLET
    CALL MOVE_PLAYER_BULLET

MLOOP2:
    LD A,(QtrSecTimer)
    CALL TEST_SIGNAL
    OR A
    JR Z,MLOOP

    JR MLOOP

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

; Check for player bullet firing
FIRE_PLAYER_BULLET:
    ; make sure there is not already a bullet
    LD A,(SPRTBL+8)
    CP 209
    RET NZ
	; see if the fire button is pressed
	CALL JOYTST
	CP 0
	RET Z
	; fire bullet
	; set Y based on player ship
    LD A,(SPRTBL)
    SUB A,6
    LD (SPRTBL+8),A
    ; set X based on player ship
    LD A,(SPRTBL+1)
    ADD A,6
    LD (SPRTBL+9),A
    ; set bullet sprite pattern
    LD A,24
    LD (SPRTBL+10),A
    ; set bullet colour
    LD A,11
    LD (SPRTBL+11),A
	RET

; Move the players bullet
MOVE_PLAYER_BULLET:
    ; check that the bullet is visible
    LD A,(SPRTBL+8)
    CP 209
    RET Z
    ; decrease bullets Y position
    DEC A
    DEC A
    DEC A
    CP 4
    JR NC, MPB1
    ; bullet has reached the top of the screen, hide the bullet
    LD A,209
MPB1:
    ; save new position
    LD (SPRTBL+8),A
    RET

; Detect joystick direction and move the player accordingly
MOVE_PLAYER:
	CALL JOYDIR
	LD C,A
	BIT 1,C
	JR Z,NRIGHT
	; move to the right
	LD A,(SPRTBL+1)
	CP 240
	JR NC,NLEFT
	INC A
	LD (SPRTBL+1),A
	LD (SPRTBL+5),A
	JR NLEFT
NRIGHT:
    BIT 3,C
    JR Z,NLEFT
    ; move to the left
    LD A,(SPRTBL+1)
    CP 0
    JR Z,NLEFT
    DEC A
    LD (SPRTBL+1),A
    LD (SPRTBL+5),A
NLEFT:
    RET


; This is our routine called every VDP interrupt during normal game play
; - Do all VDP writes here to avoid corruption
VDU_WRITES:
    RET

; This is our routine called every VDP interrupt during the title screen
; - Do all VDP writes here to avoid corruption
OUTPUT_VDP_TITLE:
    RET

; Init Ram for a new game
INITRAM:
    RET


TITLE_SCREEN_PAT:
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,023,000,015,000,017,000,011,000,000,000,000
    DB 012,000,022,000,011,000,029,000,030,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 037,038,039,040,037,038,039,040,037,038,039,040,037,038,039,040
    DB 037,038,039,040,037,038,039,040,037,038,039,040,037,038,039,040
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    ; press fire to begin
    DB 000,000,000,000,000,000,026,028,015,029,029,000,016,019,028,015
    DB 000,030,025,000,012,015,017,019,024,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    ; EA Logo
    DB 061,061,061,061,061,061,061,061,061,061,061,057,058,059,060,061
    DB 062,063,064,065,066,061,061,061,061,061,061,061,061,061,061,061

MAINLAYOUT:
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 037,038,039,040,037,038,039,040,037,038,039,040,037,038,039,040
    DB 037,038,039,040,037,038,039,040,037,038,039,040,037,038,039,040
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    ; planet surface
    DB 041,041,041,041,041,041,041,041,041,041,041,041,041,041,041,041
    DB 041,041,041,041,041,041,041,041,041,041,041,041,041,041,041,041
    ; score and life area
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    DB 000,000,000,001,001,001,001,001,001,001,000,000,000,000,000,000
    DB 000,000,000,000,000,000,000,000,000,000,000,000,000,000,000,000
    ; EA Logo
    DB 061,061,061,061,061,061,061,061,061,061,061,057,058,059,060,061
    DB 062,063,064,065,066,061,061,061,061,061,061,061,061,061,061,061


SPDATA:
include "Coleco-MegaBlast-Tilset.ASM"

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

END:	EQU $

;**************************************************************************************************
; RAM Definitions
;**************************************************************************************************

ORG RAMSTART

; Sound Data area - 7 songs
SoundDataArea: DS Len_SoundDataArea



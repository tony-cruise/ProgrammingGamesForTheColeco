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

        db "Mega Blast/ELECTRIC ADVENTURES/2014-2018"
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

    ; Seed random numbers with a fixed number (nothing else to use?)
    LD HL,1967
    CALL SEED_RANDOM

    ;Enable timers
    CALL CREATE_TIMERS

    ; Do all our VRAM setup
    ; NMI is currently disabled

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

    ; now setup the title screen layout
    LD HL,VRAM_NAME
    LD DE,TITLE_SCREEN_PAT
    LD BC,24*32
    CALL LDIRVM

	CALL JOYTST ; clear joystick buffer
   	LD HL,OUTPUT_VDP_TITLE
	CALL SET_VDU_HOOK
    CALL ENABLE_NMI

    ; play our music
    LD B,9
    CALL PLAY_IT
    LD B,10
    CALL PLAY_IT
    LD B,11
    CALL PLAY_IT
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
    ; stop all music
    LD B,12
    CALL PLAY_IT
    LD B,13
    CALL PLAY_IT
    LD B,14
    CALL PLAY_IT

    CALL DISABLE_NMI
    CALL INITRAM
    ; Set initial LEVEL
    LD A,1
    LD (LEVEL),A

    ; Send the sprite definitions to the VDP
    LD HL,VRAM_SPRGEN
    LD DE,MAIN_SHIP
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
	CALL SEED_RANDOM

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

    CALL DISPLAYLIVES

    LD A,1
    LD (LASTSCORE),A
    CALL DISPLAYSCORE

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
    CALL SPAWN_ENEMIES
    CALL MOVE_ENEMIES

    ; test to see if we have run out of lives
    ; TODO: Display G A M E  O V E R message, wait and new game
    LD A,(LIVES)
    CP 0
    JP Z,TITLESCREEN

MLOOP2:
    LD A,(QtrSecTimer)
    CALL TEST_SIGNAL
    OR A
    JR Z,MLOOP

    JR MLOOP


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
    ; play Zap sound
    LD B,1
    CALL PLAY_IT
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
    CP 242
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

; Spawn/create new enemies
SPAWN_ENEMIES:
    LD A,(LEVEL)
    INC A
    SLA A ; multiply by 4
    SLA A
    LD C,A
    CALL RND
    CP C
    RET NC
    ; see if there is an enemy object available
    LD HL,ENEMYDATA
    LD B,20
SE1:
    XOR A
    CP (HL)
    JR NZ,SE2
    ; enemy available
    PUSH HL
    ; calc our sprite memory position
    LD A,20
    SUB B
    SLA A
    SLA A
    LD C,A
    LD B,0
    LD HL,SPRTBL+12
    ADD HL,BC
    ; set Y to zero
    LD A,0
    LD (HL),A
    ; set X to a random value
    INC HL
    CALL RND
    LD (HL),A
    ; set pattern
    INC HL
    LD A,8
    LD (HL),A
    ; set colour
    INC HL
    LD A,0dh
    LD (HL),A
    POP HL
    ; hard wire to enemy type 1 for now
    LD A,1 
    CALL CALC_ENEMY
    LD (HL),A
    INC HL
    LD A,(IY+2) ; DX
    LD (HL),A
    INC HL
    LD A,(IY+3) ; DY
    LD (HL),A
    RET
SE2:
    ; move to the next data position (now 3 Ram spaces per enemy)
    INC HL
    INC HL
    INC HL
    ; dec b and jump if non-zero
    DJNZ SE1
    RET

; Calculate base enemy data location in ROM
; A = enemy type (assumed to be 1 or greater)
; Returns:
; IY = Enemy Type data in ROM
CALC_ENEMY:
    ; save registers we are going to change
    PUSH AF
    PUSH HL
    PUSH DE
    LD HL,ENEMY_TYPES
    DEC A
    ; divide by 8
    SLA A
    SLA A
    SLA A
    LD E,A
    LD D,0
    OR A
    ADC HL,DE
    ; set our return data
    PUSH HL
    POP IY
    ; restore registers we changed
    POP DE
    POP HL
    POP AF
    RET

; Move any active enemies
MOVE_ENEMIES:
    LD HL,ENEMYDATA
    LD B,20
ME1:
    XOR A
    CP (HL)
    JP Z,ME2
    ; found active enemy
    ; calc our sprite memory position (20-B) * 4
    PUSH BC
    LD A,20
    SUB B
    SLA A
    SLA A
    LD C,A
    LD B,0
    LD IX,SPRTBL+12
    ADD IX,BC
    POP BC
    ; get our enemy data
    LD A,(HL) 
    ; get the pointer to our enemy data
    CALL CALC_ENEMY

    LD A,(ANIMATE)
    CP 0
    JR NZ,ME5
    ; animate our sprite pattern (hardwired for the moment)
    LD A,(IX+2) ; get current pattern
    ADD A,4     ; add four
    CP (IY+1)   ; compare against our ending pattern    
    JR NZ,ME4   ; if we have reached our ending pattern we need to move back to the original pattern
    LD A,(IY+0) ; starting sprite shape
ME4:
    LD (IX+2),A ; store the value back
ME5:
    ; get current Y position
    LD E,(IX+0)
    ; change Y at the rate defined in the enemy ram data table
    INC HL
    INC HL
    LD A,(HL)
    DEC HL
    DEC HL
    ADD A,E
    CP 150
    JR C,ME3
    ; enemy has reached the bottom of the screen
    ; check whether the enemy has hit the player ship
    LD A,(SPRTBL+1)
    SUB A,(IY+5) ; width of enemy from enemy data table
    CP (IX+1)
    JR NC, ME7
    ; x + it's width is larger than the players X
    LD A,(SPRTBL+1)
    ADD A,(IY+5)
    CP (IX+1)
    JR C, ME7
    ; we should be hitting the player
    ; decrease the players life counter
    LD A,(LIVES)
    DEC A
    ; check we don't overflow
    JR NC,ME9
    XOR A
ME9:
    LD (LIVES),A
    ; Play our player death explosion
    PUSH HL
    PUSH IX
    PUSH BC
    LD B,4
    CALL PLAY_IT
    LD B,5
    CALL PLAY_IT
    POP BC
    POP IX
    POP HL
    ; at the moment we won't do any animation effect
    ; TODO: Animate players death

    ; continue on so that we finish our enemy loop and subroutine
    JR ME8
ME7:
    ; have not hit the player decrease score
    ; decrease score
    LD A,1
    CALL SCORESUB
    ; explosion?
    PUSH HL ; save the registers we are using
    PUSH IX
    PUSH BC
    LD B,6  ; play noise portion
    CALL PLAY_IT
    LD B,7  ; play tone portion
    CALL PLAY_IT
    POP BC ; restore our registers
    POP IX
    POP HL

ME8:
    ; clear enemy data
    XOR A
    LD (HL),A
    ; clear sprite
    LD A,209
    LD (IX+0),A
    JR ME2
ME3:
    LD (IX+0),A

    ; enemy object has been moved now do collision detection
    LD A,(SPRTBL+8) ; bullet y position
    CP 209 ; check that it is on screen
    JR Z,ME2
    PUSH HL ; save values so we can use the registers
    PUSH DE
    PUSH IY
    LD A,(IY+5) ; get our width
    LD L,A
    LD H,L
    LD IY,SPRTBL+8
    LD DE,0208h ; set our bullet size at 2x8
    CALL COLTST
    POP IY 
    POP DE
    POP HL
    JR NC,ME2
    ; we have a hit, for the moment just make both objects disappear
    LD A,209
    LD (SPRTBL+8),A
    LD (IX+0),A
    XOR A
    LD (HL),A ; deactive the enemy
    ; increase our score for hitting the asteroid
    ; Note: later we will vary the score by type of enemy
    LD A,(IY+4) ; get our points from the enemy data table
    CALL SCOREADD

    ; later we will:
    ; - animate enemy

    ; Play explosion sound
    PUSH HL ; save the registers we are using
    PUSH BC
    LD B,2 ; queue the noise part of the sound
    CALL PLAY_IT
    LD B,3 ; queue the tone part of the sound
    CALL PLAY_IT
    POP BC ; restore our registers
    POP HL

ME2:
    INC HL
    INC HL
    INC HL
    DEC B
    JP NZ,ME1
    ; adjust our animation timing
    LD A,(ANIMATE)
    DEC A
    JP P,ME6
    LD A,4
ME6:
    LD (ANIMATE),A

    RET

; =================================================
; Test whether two objects are colliding
; =================================================
; IX+0 = 1st object Y
; IX+1 = 1st object X
; IY+0 = 2nd object Y
; IY+1 = 2nd object Y
; D = 2nd object width
; E = 2nd object height
; H = 1st object width
; L = 1st object height
; =================================================
; Result: Carry flag set if two objects collide
; =================================================
COLTST: 
    LD A,(IX+0)
    SUB E
    CP (IY+0)
    JR NC,NOHIT
    ADD A,E ; get our original value back
    ADD A,L
    CP (IY+0)
    JR C,NOHIT
    LD A,(IX+1)
    SUB D
    CP (IY+1)
    JR NC,NOHIT
    ADD A,D ; get our original value back
    ADD A,H
    CP (IY+1)
    JR C,NOHIT
    SCF
    RET
NOHIT:  
    XOR A
    RET


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
    LD A,3
    LD (LIVES),A
    LD HL,0
    LD (SCORE),HL
    LD (SCORE+1),HL
    LD A,1
    LD (LASTSCORE),A
    XOR A
    LD (LASTLIVES),A
    LD (LEVEL),A
    LD (ANIMATE),A
    ; initialise enemy data
    LD HL,ENEMYDATA
    LD (HL),A
    LD DE,ENEMYDATA+1
    LD BC,59
    LDIR
   RET

; Display the current player lives (max 7)
DISPLAYLIVES:
    LD HL,LIVES
    LD A,(LASTLIVES)
    CP (HL)
    RET Z
    ; clear current lives display
    LD HL,VRAM_NAME+688
    LD BC,14
    XOR A
    CALL FILVRM
    LD HL,VRAM_NAME+720
    LD BC,14
    XOR A
    CALL FILVRM
    ; now show the current lives
    ; - first write the top characters
    LD D,44
    LD HL,VRAM_NAME+688
    CALL SETWRT
    ; current # of lives
    LD A,(LIVES)
    ; max 7 to be displayed
    AND %111
    LD B,A
DL1:
    LD A,D
    OUT (DATA_PORT),A
    INC A
    OUT (DATA_PORT),A
    DJNZ DL1
    ; - now write the bottom characters
    LD D,42
    LD HL,VRAM_NAME+720
    CALL SETWRT
    ; current # of lives
    LD A,(LIVES)
    ; max 7 to be displayed
    AND %111
    LD B,A
DL2:
    LD A,D
    OUT (DATA_PORT),A
    INC A
    OUT (DATA_PORT),A
    DJNZ DL2
    LD A,(LIVES)
    LD (LASTLIVES),A
    RET

; Subtract A from the current score
; - Score is stored as three two nibble decimal values.
; - Displaying a fixed zero at the end this gives a
;   score range of 7 digits i.e max score is 99 million.
SCORESUB:
    PUSH DE ; save DE
    PUSH HL ; save HL
    ; subtract value in A from the 1st score byte
    LD E,A
    LD HL,SCORE
    LD A,(HL)
    SUB E
    ; adjust into a two nibble decimal
    DAA
    ; save to 1st score byte
    LD (HL),A
    ; now add any overflow to the 2nd score byte
    INC HL
    LD A,(HL)
    SBC A,0
    DAA
    LD (HL),A    
    ; now add any overflow to the 3rd score byte
    INC HL
    LD A,(HL)
    SBC A,0
    DAA
    LD (HL),A
    JR NC, SCORESUB2
    ; we have overflowed - set score to zero
    XOR A
    LD (HL),A
    DEC HL
    LD (HL),A
    DEC HL
    LD (HL),A
SCORESUB2:    
    POP HL ; restore HL
    POP DE ; restore DE
    RET

; Add A to the current score
; - Score is stored as three two nibble decimal values.
; - Displaying a fixed zero at the end this gives a
;   score range of 7 digits i.e max score is 99 million.
SCOREADD:
    PUSH DE ; save DE
    PUSH HL ; save HL
    ; add value in A to the current 1st score byte
    LD HL,SCORE
    LD E,A
    LD A,(HL)
    ADD A,E
    ; adjust into a two nibble decimal
    DAA
    ; save to 1st score byte
    LD (HL),A
    ; now add any overflow to the 2nd score byte
    INC HL
    LD A,(HL)
    ADC A,0
    DAA
    LD (HL),A
    ; now add any overflow to the 3rd score byte
    INC HL
    LD A,(HL)
    ADC A,0
    DAA
    LD (HL),A
    POP HL ; restore HL
    POP DE ; restore DE
    RET

; Display the current score on the 2nd last row
DISPLAYSCORE:
    ; compare the 1st score digit with our lastscore value
	LD A,(SCORE)
	LD HL,LASTSCORE
	CP (HL)
	RET Z
    ; setup our write to video ram
	LD HL,VRAM_NAME + 707
	CALL SETWRT
    ; starting at our last byte, write out each of the two digits per byte
	LD HL,SCORE+2
	LD B,3
SLP:
    ; output the two decimal digits currently in A
    CALL PRINTIT
	DEC HL
	DJNZ SLP
    ; save the current score value into lastscore
	LD A,(SCORE)
	LD (LASTSCORE),A
    RET

; This is our routine called every VDP interrupt during normal game play
; - Do all VDP writes here to avoid corruption
VDU_WRITES:
    CALL DISPLAYSCORE
    CALL DISPLAYLIVES
    RET

; This is our routine called every VDP interrupt during the title screen
; - Do all VDP writes here to avoid corruption
OUTPUT_VDP_TITLE:
    RET

; Enemy source data table
ENEMY_TYPES:
    ; Start Shape, End Shape, DX, DY, Score, Width, Spare1, Spare2
    DB 8, 16, 0, 1, 10, 16, 0, 0 ; Large Meteor
    DB 20, 24, 0, 2, 20, 12, 0, 0 ; Small Meteor
    DB 28, 40, 1, 2, 50, 12, 0, 0 ; Smart Bomb
    DB 44,48, 0, 0, 0, 16, 0, 0   ; Explosion

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


;**************************************************************************************************
; Include external data files
;**************************************************************************************************

include "Coleco-MegaBlast-Patterns.ASM"

;**************************************************************************************************
; Sound and music data area
;**************************************************************************************************

sfx_ZAP1_1:
DB $41,$77,$30,$10,$11,$20
DB $50

sfx_EXPLOSION1_0:
DB $00,$00,$37,30
DB $10
sfx_EXPLOSION1_3:
DB $c0,$e7,$f3,1
DB $c0,$d1,$f3,1
DB $c0,$91,$f3,1
DB $c0,$63,$f3,1
DB $c0,$45,$f3,1
DB $c0,$2f,$f3,1
DB $c0,$0b,$f3,1
DB $c0,$a3,$f2,1
DB $c0,$67,$f2,1
DB $c0,$e3,$f1,1
DB $c0,$99,$f1,1
DB $c0,$49,$f1,1
DB $c0,$25,$f1,1
DB $c0,$27,$f1,1
DB $c0,$c7,$f0,16
DB $d0

sfx_EXPLOSION2_0:
DB $00,$00,$37,120
DB $10
sfx_EXPLOSION2_3:
DB $c0,$e7,$f3,1
DB $c0,$d1,$f3,1
DB $c0,$91,$f3,1
DB $c0,$63,$f3,1
DB $c0,$45,$f3,1
DB $c0,$2f,$f3,1
DB $c0,$0b,$f3,1
DB $c0,$a3,$f2,1
DB $c0,$67,$f2,1
DB $c0,$e3,$f1,1
DB $c0,$99,$f1,1
DB $c0,$49,$f1,1
DB $c0,$25,$f1,1
DB $c0,$27,$f1,1
DB $c0,$c5,$f0,1
DB $c0,$95,$f0,1
DB $c0,$57,$f0,1
DB $c0,$53,$f0,1
DB $c0,$51,$f0,1
DB $c0,$4f,$f0,1
DB $c0,$4b,$f0,3
DB $c0,$45,$f0,1
DB $c0,$43,$f0,2
DB $c0,$3d,$f0,2
DB $c0,$35,$f0,1
DB $c0,$39,$f0,1
DB $c0,$3d,$f0,1
DB $c0,$3f,$f0,1
DB $c0,$41,$f0,1
DB $c0,$45,$f0,1
DB $c0,$4d,$f0,1
DB $c0,$61,$f0,1
DB $c0,$71,$f0,1
DB $c0,$8b,$f0,1
DB $c0,$a1,$f0,1
DB $c0,$cd,$f0,1
DB $c0,$f5,$f0,1
DB $c0,$ad,$f1,1
DB $c0,$b3,$f1,1
DB $c0,$ad,$f1,1
DB $c0,$a7,$f1,1
DB $c0,$9b,$f1,1
DB $c0,$8d,$f1,1
DB $c0,$7f,$f1,1
DB $c0,$71,$f1,1
DB $c0,$5f,$f1,1
DB $c0,$4f,$f1,1
DB $c0,$39,$f1,1
DB $c0,$13,$f1,1
DB $c0,$4b,$f0,7
DB $c0,$7f,$f0,1
DB $c0,$97,$f0,1
DB $c0,$b3,$f0,1
DB $c0,$cf,$f0,1
DB $c0,$ff,$f0,1
DB $c0,$4b,$f1,1
DB $c0,$87,$f1,1
DB $c0,$a3,$f1,1
DB $c0,$b5,$f1,1
DB $c0,$c7,$f1,1
DB $c0,$33,$f2,1
DB $c0,$61,$f2,1
DB $c0,$9b,$f2,1
DB $d0

sfx_EXPLOSION3_0:
DB $00,$00,$37,42
DB $10
sfx_EXPLOSION3_3:
DB $c0,$e7,$f3,1
DB $c0,$d1,$f3,1
DB $c0,$91,$f3,1
DB $c0,$55,$f1,1
DB $c0,$45,$f3,1
DB $c0,$59,$f1,1
DB $c0,$53,$f1,1
DB $c0,$59,$f3,1
DB $c0,$45,$f1,2
DB $c0,$59,$f3,1
DB $c0,$45,$f1,1
DB $c0,$65,$f3,1
DB $c0,$61,$f3,1
DB $c0,$53,$f0,1
DB $c0,$51,$f0,1
DB $c0,$5b,$f3,1
DB $c0,$4f,$f0,1
DB $c0,$7b,$f3,1
DB $c0,$77,$f3,1
DB $c0,$53,$f0,1
DB $c0,$47,$f0,1
DB $c0,$77,$f3,2
DB $c0,$47,$f0,2
DB $c0,$7d,$f3,2
DB $c0,$55,$f0,2
DB $c0,$71,$f3,1
DB $c0,$55,$f0,1
DB $c0,$53,$f0,1
DB $c0,$6d,$f3,1
DB $c0,$63,$f3,1
DB $c0,$5f,$f1,2
DB $c0,$67,$f3,1
DB $c0,$5f,$f1,2
DB $c0,$91,$f3,1
DB $c0,$9d,$f3,1
DB $d0


bass1a:
    ; ch 3, note G#3 $088, 0db, length 45
    db  0xc0,0x88,0xf0,0x2d
    ; ch 3, note G#5 $022, 0db, length 15
    db  0xc0,0x22,0xf0,0x0f
    ; ch 3, note F#3 $098, 0db, length 7
    db  0xc0,0x98,0xf0,0x07
    ; ch 3, note G#3 $088, 0db, length 8
    db  0xc0,0x88,0xf0,0x08
    ; ch 3, note A#4 $079, 0db, length 30
    db  0xc0,0x79,0xf0,0x1e
    ; ch 3, note G#5 $022, 0db, length 15
    db  0xc0,0x22,0xf0,0x0f
    ; ch 3, note G#3 $088, 0db, length 7
    db  0xc0,0x88,0xf0,0x07
    ; ch 3, note A#4 $079, 0db, length 8
    db  0xc0,0x79,0xf0,0x08
    ; ch 3, note B4 $072, 0db, length 30
    db  0xc0,0x72,0xf0,0x1e
    ; ch 3, note G#5 $022, 0db, length 15
    db  0xc0,0x22,0xf0,0x0f
    ; ch 3, note A#4 $079, 0db, length 7
    db  0xc0,0x79,0xf0,0x07
    ; ch 3, note B4 $072, 0db, length 8
    db  0xc0,0x72,0xf0,0x08
    ; ch 3, note A#4 $079, 0db, length 15
    db  0xc0,0x79,0xf0,0x0f
    ; ch 3, note F#3 $098, 0db, length 15
    db  0xc0,0x98,0xf0,0x0f
    ; ch 3, note G#5 $022, 0db, length 15
    db  0xc0,0x22,0xf0,0x0f
    ; ch 3, repeat
    db  0xd8
bass1b:
    ; period noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x03,0x0f,0x1f,0x12
    ; noise, rest 14
    db  0x2f
    ; period noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x03,0x0f,0x1f,0x12
    ; white noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x07,0x0f,0x1f,0x12
    ; period noise, vol sweep, ch3, length 7 (1 x 15), 1/2
    db  0x02,0x03,0x07,0x1f,0x12
    ; period noise, vol sweep, ch3, length 8 (1 x 15), 1/2
    db  0x02,0x03,0x08,0x1f,0x12
    ; period noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x03,0x0f,0x1f,0x12
    ; period noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x03,0x0f,0x1f,0x12
    ; white noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x07,0x0f,0x1f,0x12
    ; period noise, vol sweep, ch3, length 7 (1 x 15), 1/2
    db  0x02,0x03,0x07,0x1f,0x12
    ; period noise, vol sweep, ch3, length 8 (1 x 15), 1/2
    db  0x02,0x03,0x08,0x1f,0x12
    ; period noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x03,0x0f,0x1f,0x12
    ; period noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x03,0x0f,0x1f,0x12
    ; white noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x07,0x0f,0x1f,0x12
    ; period noise, vol sweep, ch3, length 7 (1 x 15), 1/2
    db  0x02,0x03,0x07,0x1f,0x12
    ; period noise, vol sweep, ch3, length 8 (1 x 15), 1/2
    db  0x02,0x03,0x08,0x1f,0x12
    ; period noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x03,0x0f,0x1f,0x12
    ; period noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x03,0x0f,0x1f,0x12
    ; white noise, vol sweep, ch3, length 15 (1 x 15), 1/2
    db  0x02,0x07,0x0f,0x1f,0x12
    ; noise, repeat
    db  0x18

lyrics1:
    ; ch 1, rest 30
    db  0x7e
    ; ch 1, note A2 $1fc 220Hz, Vol 4db, length 56
    db  0x40,0xfc,0x11,0x07
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note A2 $1fc 220Hz, Vol 4db, length 64
    db  0x40,0xfc,0x11,0x08
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note A2 $1fc 220Hz, Vol 4db, Length 56
    db  0x40,0xfc,0x11,0x07
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note A2 $1fc 220Hz, Vol 4db, Length 64
    db  0x40,0xfc,0x11,0x08
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note G1 $23b 196Hz, Vol 4db, Length 56
    db  0x40,0x3b,0x12,0x07
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note A2 $1fc 220Hz, Vol 4db, Length 64
    db  0x40,0xfc,0x11,0x08
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note B2 $1c5 246Hz, Vol 4db, length 210
    db  0x40,0xc5,0x11,0x0f
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note B2 $1c5 246Hz, Vol 4db, length 255
    db  0x40,0xc5,0x11,0x1e
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note A2 $1fc 220Hz, Vol 4db, length 56
    db  0x40,0xfc,0x11,0x07
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note B2 $1c5 246Hz, Vol 4db, length 64
    db  0x40,0xc5,0x11,0x08
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note C2 $1ab 261Hz, Vol 4db, length 210
    db  0x40,0xab,0x11,0x0f
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note C2 $1ab 261Hz, Vol 4db, length 255
    db  0x40,0xab,0x11,0x1e
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note B2 $1c5 246Hz, Vol 4db, length 56
    db  0x40,0xc5,0x11,0x07
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note C2 $1ab 261Hz, Vol 4db, length 64
    db  0x40,0xab,0x11,0x08
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note B2 $1c5 246Hz, Vol 4db, length 210
    db  0x40,0xc5,0x11,0x0f
    ; ch 1, rest 1
    db  0x61
    ; ch 1, note G1 $23b 196Hz, Vol 4db, length 210
    db  0x40,0x3b,0x12,0x0f
    ; ch 1, rest 15
    db  0x6f
    ; ch 1, repeat
    db  0x58

lyrics1a:
    ; ch 1, rest 30
    db  0x7e
    ; ch 1, vol swept note A2 $1fc 220Hz, Vol 4db, 7 x (1 x 8), 1/1
    db  0x42,0xfc,0x11,0x07,0x18,0x11
    ; ch 1, vol swept note A2 $1fc 220Hz, Vol 4db, 8 x (1 x 8), 1/1
    db  0x42,0xfc,0x11,0x08,0x18,0x11
    ; ch 1, vol swept note A2 $1fc 220Hz, Vol 4db, 7 x (1 x 8), 1/1
    db  0x42,0xfc,0x11,0x07,0x18,0x11
    ; ch 1, vol swept note A2 $1fc 220Hz, Vol 4db, 8 x (1 x 8), 1/1
    db  0x42,0xfc,0x11,0x08,0x18,0x11
    ; ch 1, vol swept note G1 $23b 196Hz, Vol 4db, 7 x (1 x 8), 1/1
    db  0x42,0x3b,0x12,0x07,0x18,0x11
    ; ch 1, vol swept note A2 $1fc 220Hz, Vol 4db, 8 x (1 x 8), 1/1
    db  0x42,0xfc,0x11,0x08,0x18,0x11
    ; ch 1, vol swept note B2 $1c5 246Hz, Vol 4db, 15 x (1 x 14), 1/1
    db  0x42,0xc5,0x11,0x0f,0x1e,0x11
    ; ch 1, vol swept note B2 $1c5 246Hz, Vol 4db, 30 x (1 x 14), 1/1
    db  0x42,0xc5,0x11,0x1e,0x1e,0x11
    ; ch 1, vol swept note A2 $1fc 220Hz, Vol 4db, 7 x (1 x 8), 1/1
    db  0x42,0xfc,0x11,0x07,0x18,0x11
    ; ch 1, vol swept note B2 $1c5 246Hz, Vol 4db, 8 x (1 x 8), 1/1
    db  0x42,0xc5,0x11,0x08,0x18,0x11
    ; ch 1, vol swept note C2 $1ab 261Hz, Vol 4db, 15 x (1 x 14), 1/1
    db  0x42,0xab,0x11,0x0f,0x1e,0x11
    ; ch 1, vol swept note C2 $1ab 261Hz, Vol 4db, 30 x (1 x 14), 1/1
    db  0x42,0xab,0x11,0x1e,0x1e,0x11
    ; ch 1, vol swept note B2 $1c5 246Hz, Vol 4db, 7 x (1 x 8), 1/1
    db  0x42,0xc5,0x11,0x07,0x18,0x11
    ; ch 1, vol swept note C2 $1ab 261Hz, Vol 4db, 8 x (1 x 8), 1/1
    db  0x42,0xab,0x11,0x08,0x18,0x11
    ; ch 1, vol swept note B2 $1c5 246Hz, Vol 4db, 15 x (1 x 14), 1/1
    db  0x42,0xc5,0x11,0x0f,0x1e,0x11
    ; ch 1, vol swept note G1 $23b 196Hz, Vol 4db, 15 x (1 x 14), 1/1
    db  0x42,0x3b,0x12,0x0f,0x1e,0x11
    ; ch 1, rest 15
    db  0x6f
    ; ch 1, repeat
    db  0x58

stopch1:
    db 0x50

stopch3:
    db 0xD0

stopnoise:
    db 0x10

;**************************************************************************************************
; Sound settings
;**************************************************************************************************
SoundDataCount:	  EQU	8
Len_SoundDataArea: EQU	10*SoundDataCount+1	;7 data areas
SoundAddrs:
	DW	sfx_ZAP1_1,SoundDataArea          ; 1 lazer zap sound (Channel 1)
    DW  sfx_EXPLOSION1_0,SoundDataArea+10 ; 2 Explosion 1 part 1 (Noise)
    DW  sfx_EXPLOSION1_3,SoundDataArea+20 ; 3 Explosion 1 part 2 (Channel 3)
    DW  sfx_EXPLOSION2_0,SoundDataArea+10 ; 4 Explosion 2 part 1 (Noise)
    DW  sfx_EXPLOSION2_3,SoundDataArea+20 ; 5 Explosion 2 part 2 (Channel 3)
    DW  sfx_EXPLOSION3_0,SoundDataArea+30 ; 6 Explosion 3 part 1 (Noise)
    DW  sfx_EXPLOSION3_3,SoundDataArea+40 ; 7 Explosion 3 part 2 (Channel 3)
    DW  lyrics1,SoundDataArea+50          ; 8 Smooth Criminal
    DW  lyrics1a,SoundDataArea+50         ; 9 Smooth Criminal (Better)
    DW  bass1a,SoundDataArea+60           ; 10 Smooth Criminal - Base Tone
    DW  bass1b,SoundDataArea+70           ; 11 Smooth Criminal - Base Noise
    DW  stopch1,SoundDataArea+50          ; 12 stop channel 1
    DW  stopch3,SoundDataArea+60          ; 13 stop channel 3
    DW  stopnoise,SoundDataArea+70        ; 14 stop noise channel
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

LEVEL:	     DS 1
LIVES:       DS 1
LASTLIVES:   DS 1
SCORE:	     DS 3
LASTSCORE:   DS 3
ENEMYDATA:   DS 60
ANIMATE:     DS 1

; Sound Data area - 7 songs
SoundDataArea: DS Len_SoundDataArea



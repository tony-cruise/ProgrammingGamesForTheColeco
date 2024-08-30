;****************************************************************
;
; Music Demo - Coleco ver 1.00 (C) Electric Adventures 2019
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

        db "Music Demo/ELECTRIC ADVENTURES/2019"
;
; Start of application logic
START:
  ; set stack pointer
  LD	SP,StackTop	;128 bytes in length at 737fh

  CALL INIT_SOUND

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

  ; Send the sprite definitions to the VDP
  LD HL,VRAM_SPRGEN
  LD DE,SPRITE_1
  LD BC,32*SPRITECOUNT
  CALL LDIRVM

  ; Clean up in case anything left on screen
  CALL CLEARSPRITES
  CALL SPRWRT

  ; Load the character set, make all three sections the same
  CALL LOAD_CHR_SET

  ; now setup our initial screen layout
  LD HL,VRAM_NAME
  LD DE,SL_DEMO
  LD BC,768
  CALL LDIRVM

	CALL JOYTST ; clear joystick buffer
 	LD HL,VDU_WRITES
	CALL SET_VDU_HOOK
  CALL ENABLE_NMI

  LD A,0
  LD (CH1FRQ),A
  LD A,0
  LD (CH1FRQ+1),A
  LD A,5
  LD (CH1VOL),A
  LD (CH2VOL),A

  CALL SET_ALL_SOUND_FREQUENCIES
  CALL SET_SOUND_VOLUME

  ; set cursor position
  LD A,68
  LD (SPRTBL),A
  LD A,56  
  LD (SPRTBL+1),A
  XOR A
  LD (SPRTBL+2),A
  LD A,8
  LD (SPRTBL+3),A

SPLASH_TITLE2:
  LD	A,(EighthSecTimer)
	CALL	TEST_SIGNAL
	OR	A
  JR Z,SPLASH_TITLE2
  ; Any other actions on the title screen go here

  CALL SELECT_CHANNEL
  CALL PLAYER_ACTIONS
  CALL SET_ALL_SOUND_FREQUENCIES
  CALL SET_SOUND_VOLUME

	JR SPLASH_TITLE2

PLAYER_ACTIONS:
  CALL JOYDIR
  LD C,A
  LD A,(CURRENT_CHANNEL)
  BIT 0,C
  JR Z,NUP
  JP DEC_CHANNEL_VOL
NUP:
  BIT 1,C
  JR Z,NRIGHT
  JP INC_CHANNEL_FREQ
NRIGHT:
  BIT 2,C
  JR Z,NDOWN
  JP INC_CHANNEL_VOL
NDOWN:
  BIT 3,C
  JR Z,NLEFT
  JP DEC_CHANNEL_FREQ
NLEFT:
  RET

SELECT_CHANNEL:
  CALL JOYTST
  CP 0
  RET Z
  LD A,(CURRENT_CHANNEL)
  INC A
  CP 3
  JR C,.skip
    XOR A
.skip:
  LD (CURRENT_CHANNEL),A
  SLA A
  SLA A
  SLA A
  SLA A
  ADD A,68
  LD (SPRTBL),A
  RET

INC_CHANNEL_VOL:
  LD HL,CH1VOL
  CP 0
  JR Z,ICV1
ICV2:
  INC HL
  SUB 1
  JR NZ,ICV2
ICV1:
  LD A,(HL)
  ADD A,1
  AND %1111
  LD (HL),A
  RET

DEC_CHANNEL_VOL:
  LD HL,CH1VOL
  CP 0
  JR Z,DCV1
DCV2:
  INC HL
  SUB 1
  JR NZ,DCV2
DCV1:
  LD A,(HL)
  SUB 1
  AND %1111
  LD (HL),A
  RET

INC_CHANNEL_FREQ:
  LD HL,CH1FRQ
  CP 0
  JR Z,ICF1
ICF2:
  INC HL
  INC HL
  SUB 1
  JR NZ,ICF2
ICF1:
  LD A,(HL)
  ADD A,8
  LD (HL),A
  INC HL
  LD A,(HL)
  ADC A,0
  AND %11
  LD (HL),A
  RET

DEC_CHANNEL_FREQ:
  LD HL,CH1FRQ
  CP 0
  JR Z,DCF1
DCF2:
  INC HL
  INC HL
  SUB 1
  JR NZ,DCF2
DCF1:
  LD A,(HL)
  SUB 8
  LD (HL),A
  INC HL
  LD A,(HL)
  SBC A,0
  AND %11
  LD (HL),A
  RET

;**************************************************************
; Sound routines
;**************************************************************
SOUND_PORT: EQU 0FFh ; SN76489A 

; Initialise the sound chip, so that no sound is playing
INIT_SOUND:
  LD A,%10011111 ; Tone 1 volume =  off
  OUT (SOUND_PORT), A
  LD A,%10111111 ; Tone 2 volume =  off
  OUT (SOUND_PORT), A
  LD A,%11011111 ; Tone 3 volume =  off
  OUT (SOUND_PORT), A
  LD A,%11111111 ; Noise volume =  off
  OUT (SOUND_PORT), A
  RET

; sets the current volume of each of the sound channels
SET_SOUND_VOLUME:
  LD HL,CH1VOL
  LD A,%10010000 ; Channel 1 volume
  OR (HL)
  OUT (SOUND_PORT),A
  INC HL
  LD A,%10110000 ; Channel 2 volume
  OR (HL)
  OUT (SOUND_PORT),A
  INC HL
  LD A,%11010000 ; Channel 3 volume
  OR (HL)
  OUT (SOUND_PORT),A
  INC HL
  LD A,%11110000 ; Noise volume
  OR (HL)
  OUT (SOUND_PORT),A
  RET

SET_ALL_SOUND_FREQUENCIES:
  LD HL,CH1FRQ
  LD D,%10000000
  CALL SET_SOUND_FREQUENCY
  LD D,%10100000
  CALL SET_SOUND_FREQUENCY
  LD D,%11000000
  CALL SET_SOUND_FREQUENCY
  RET

SET_SOUND_FREQUENCY:
  LD A,(HL)
  AND 00Fh
  OR D
  OUT (SOUND_PORT),A
  LD A,(HL)
  AND 0F0h
  LD D,A
  INC HL
  LD A,(HL)
  AND 00Fh
  OR D
  RRCA
  RRCA
  RRCA
  RRCA
  OUT (SOUND_PORT),A
  INC HL
  RET

;**************************************************************

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
    LD HL,0
    LD (CH1FRQ),HL
    LD (CH2FRQ),HL
    LD (CH3FRQ),HL
    XOR A
    LD (CHNCTL),A
    LD (CURRENT_CHANNEL),A
    LD A,15
    LD (CH1VOL),A
    LD (CH2VOL),A
    LD (CH3VOL),A
    LD (CHNVOL),A
    RET

; This is our routine called every VDP interrupt during normal game play
; - Do all VDP writes here to avoid corruption
VDU_WRITES:
    LD HL,VRAM_NAME+17+32*9
    CALL SETWRT
    LD A,(CH1VOL)
    CALL bin2bcd
    LD (TEMP),A
    LD HL,TEMP
    CALL PRINTIT
    LD HL,VRAM_NAME+17+32*11
    CALL SETWRT
    LD A,(CH2VOL)
    CALL bin2bcd
    LD (TEMP),A
    LD HL,TEMP
    CALL PRINTIT
    LD HL,VRAM_NAME+17+32*13
    CALL SETWRT
    LD A,(CH3VOL)
    CALL bin2bcd
    LD (TEMP),A
    LD HL,TEMP
    CALL PRINTIT

    ; now output each channel frequency
    LD HL,VRAM_NAME+24+32*9
    CALL SETWRT
    LD HL,(CH1FRQ)
    CALL Bin162Bcd
    LD HL,BSD_OUTPUT+2
    CALL PRINTIT
    DEC HL
    CALL PRINTIT

    LD HL,VRAM_NAME+24+32*11
    CALL SETWRT
    LD HL,(CH2FRQ)
    CALL Bin162Bcd
    LD HL,BSD_OUTPUT+2
    CALL PRINTIT
    DEC HL
    CALL PRINTIT

    LD HL,VRAM_NAME+24+32*13
    CALL SETWRT
    LD HL,(CH3FRQ)
    CALL Bin162Bcd
    LD HL,BSD_OUTPUT+2
    CALL PRINTIT
    DEC HL
    CALL PRINTIT
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

;**************************************************************************************************
; Include external data files
;**************************************************************************************************

  include "Coleco-MusicDemo-Patterns.ASM"

;**************************************************************************************************
; Standard Libraries
;**************************************************************************************************

  include "Coleco-Lib.ASM"

;**************************************************************************************************
; RAM Definitions
;**************************************************************************************************

CURRENT_CHANNEL: DS 1
TEMP: DS 1

; Sound variables
CH1FRQ: DS 2
CH2FRQ: DS 2
CH3FRQ: DS 2

CHNCTL: DS 1

CH1VOL: DS 1
CH2VOL: DS 1
CH3VOL: DS 1
CHNVOL: DS 1




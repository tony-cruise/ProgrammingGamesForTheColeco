;****************************************************************
; Coleco SUBROUTINES ver 1.02 (C) Electric Adventures 2020
;****************************************************************

; Set address called inside NMI routine
; HL = Hook Address
SET_VDU_HOOK:
   LD A,0cdh
   LD (VDU_HOOK),A
   LD (VDU_HOOK+1),HL
   LD A,0c9h
   LD (VDU_HOOK+3),A
   RET

; Disable the generation of NMI calls
DISABLE_NMI:
	ld      a,(073c4h)
	and     0dfh
DNMI1:
	ld      c,a
	ld      b,1
	jp      01fd9h

; Enable the generationo of NMI calls
ENABLE_NMI:
	ld      a,(073c4h)
	or      020h
	call    DNMI1
	jp      01fdch

; Set the name table to default values
; DE = VRAM Offset
SET_DEF_NAME_TBL:
    ld      c,CTRL_PORT
    di
    out     (c),e
    set     6,d
    out     (c),d
    ei
    ld      c,DATA_PORT
    ld      d,3
SDNT1:
    xor     a
SDNT2:
    out     (c),a
    nop
    inc     a
    jp      nz,SDNT2
    dec     d
    jp      nz,SDNT1
    ret

;
; HL = Source data
; DE = VRam starting location
RLE2VRAM:
    di
    ld      c,CTRL_PORT
    out     (c),e
    set     6,d
    out     (c),d
    ei
    ld      c,DATA_PORT
RLE2V0:
    ld      a,(hl)
    inc     hl
    cp      0ffh
    ret     z
    bit     7,a
    jr      z,RLE2V2
    and     07fh
    inc     a
    ld      b,a
    ld      a,(hl)
    inc     hl
RLE2V1:
    out     (c),a
    nop
    nop
    djnz    RLE2V1
    jr      RLE2V0
RLE2V2:
    inc     a
    ld      b,a
RLE2V3:
    outi
    jr      z,RLE2V0
    jp      RLE2V3

; Uncompress RLE data into RAM
; HL = Source data
; DE = Destination
RLE2RAM:
RLE2R0:
    ld      a,(hl)
    inc     hl
    cp      0ffh
    ret     z
    bit     7,a
    jr      z,RLE2R2
    and     07fh
    inc     a
    ld      b,a
    ld      a,(hl)
    inc     hl
RLE2R1:
    ld      (de),a
    inc     de
    djnz    RLE2R1
    jr      RLE2R0
RLE2R2:
    inc     a
    ld      b,a
    ldir
    jr      RLE2R0

; Write to VDP, port in B, value in C
WRTVDP:
    DI
    LD A,B
    OUT (CTRL_PORT),A
    LD A,C
    OR 80h
    OUT (CTRL_PORT),A
    EI
    PUSH HL
    LD A,B
    LD B,0
    LD HL,0F3DFh
    ADD HL,BC
    LD (HL),A
    POP HL
    RET

; Set write to Video Ram
; HL = VRAM Address
SETWRT:
    DI
    LD A,L
    OUT (CTRL_PORT),A
    LD A,H
    AND 3Fh
    OR 40h
    OUT (CTRL_PORT),A
    EI
    RET
;
; Set read to Video Ram
; HL = VRAM Address
SETRD:
    DI
    LD A,L
    OUT (CTRL_PORT),A
    LD A,H
    AND 3Fh
    OUT (CTRL_PORT),A
    EI
    RET

; Load a block of memory to VRAM
; HL = VRAM Address
; DE = RAM Address
; BC = Length
LDIRVM:
    CALL SETWRT
LLOOP:
    LD A,(DE)
    OUT (DATA_PORT),A
    INC DE
    DEC BC
    LD A,C
    OR B
    CP 0
    JR NZ,LLOOP
    RET

; Fill a section of VRAM with value in A
; HL = VRAM Address
; BC = Length
FILVRM:
    LD E,A
    CALL SETWRT
FLOOP:
    LD A,E
    OUT (DATA_PORT),A
    DEC BC
    LD A,C
    OR B
    CP 0
    JR NZ,FLOOP
    RET

; Write Sprite positions to VRAM
; - writes sprites in reverse order every 2nd screen refresh
; - this allows for eight sprites per line, with flickering
; - only when there are five or more sprites on a line
SPRWRT:
    LD A,(SPRORDER)
    BIT 0,A
    JR NZ,SW1
    ; write sprites normal order
    SET 0,A
    LD (SPRORDER),A
    LD HL,VRAM_SPRATTR
    LD DE,SPRTBL
    LD BC,80h
    CALL LDIRVM
    RET
SW1:
    ; write sprites reverse order
    RES 0,A
    LD (SPRORDER),A
    LD HL,VRAM_SPRATTR
    CALL SETWRT
    LD IX,SPRTBL+80h-4
    LD C,32
SW2:
    LD A,(IX+0)
    OUT (DATA_PORT),A
    LD A,(IX+1)
    OUT (DATA_PORT),A
    LD A,(IX+2)
    OUT (DATA_PORT),A
    LD A,(IX+3)
    OUT (DATA_PORT),A
    DEC IX
    DEC IX
    DEC IX
    DEC IX
    DEC C
    XOR A
    CP C
    JR NZ,SW2
    RET

; Setup Screen 2,2 - Interrupts are disabled
SETSCREEN2:
    LD BC,0002h	;Reg 0: Mode 2
    CALL WRITE_REGISTER
    LD BC,0206h        ; Name table 1800h
    CALL WRITE_REGISTER
    LD BC,03ffh        ; Colour table 2000h
    CALL WRITE_REGISTER
    LD BC,0403h        ; Pattern table 0000h
    CALL WRITE_REGISTER
    LD BC,0536h        ; Sprite attribute table 1b00h
    CALL WRITE_REGISTER
    LD BC,0607h        ; Sprite pattern table 3800h
    CALL WRITE_REGISTER
    LD BC,0700h        ; Base colours
    CALL WRITE_REGISTER
    LD BC,01c2h	;Reg 1: Mode 2, 16k, no interrupts, 16x16 sprites
    CALL WRITE_REGISTER
    RET

; Test for the press of a joystick button (0 or 1)
; A = 255 - fire button pressed
JOYTST:
    CALL POLLER
	LD	A,(CONTROLLER_BUFFER+FIRE1)
    OR A
    JR Z,JOYTST2
    LD A,255
    RET
 JOYTST2:
    LD A,(CONTROLLER_BUFFER+5)
    AND 040h
    RET Z
    LD A,255
    RET

; Test for a press of a keypad button
JOYPAD:
    CALL POLLER
    LD A,(CONTROLLER_BUFFER+KEYPAD1)
    RET
;
; Test for the direction of joystick 0
; Result: A
JOYDIR:
       CALL POLLER
       LD A,(CONTROLLER_BUFFER+JOY1)
       RET
;
; Play a sound, protects the calling routine from common registers being changed
; B = Sound to play
SOUND:
    PUSH IX
    PUSH IY
    PUSH HL
    PUSH DE
    CALL PLAY_IT
    POP DE
    POP HL
    POP IY
    POP IX
    RET

; Output a character to the screen nametable
; (HL) contains the character to output
PRINTIT:
    XOR A ; clear A
    RLD   ; rotate left out of (HL) into A
    INC A
    OUT (DATA_PORT),A
    DEC A
    RLD   ; rotate left out of (HL) into A
    INC A
    OUT (DATA_PORT),A
    DEC A
    RLD
    RET

; Clear the sprites from the screen (set Y=209)
CLEARSPRITES:
	LD B,80h
	LD DE,SPRTBL
CS1:
    LD A,209
	LD (DE),A
	INC DE
	DEC B
	LD A,B
	CP 0
	JR NZ,CS1
	LD (SPRORDER),A
	RET

; Clear the VDP Pattern table (clears screen)
CLEARPAT:
	LD HL,VRAM_NAME
	LD BC,768
	XOR A
	CALL FILVRM
    RET

; Create and enable standard timers
CREATE_TIMERS:
	LD	HL,(AMERICA)	;How long a second is
	SRA L
	LD	H,0
	LD	A,1	;set to repeating
	CALL	REQUEST_SIGNAL
	LD	(HalfSecTimer),A		;Happens once per half second
	LD	HL,(AMERICA)	;How long a second is
	SRA L
	SRA L
	LD	H,0
	LD	A,1	;set to repeating
	CALL	REQUEST_SIGNAL
	LD	(QtrSecTimer),A		;Happens once per quarter second
	LD	HL,1
	LD	A,1	;set to repeating
	CALL	REQUEST_SIGNAL
	LD	(TickTimer),A		;Happens once per tick
    RET

;   Seed Random numbers
;   Seed in HL
SEED_RANDOM:
    LD (SEED),HL
    RR H
    RL L
    LD (SEED+2),HL
    RET

;   Generate a random number, based on the initial Seed
;   value.
RND:
    PUSH HL
	PUSH BC
	PUSH DE
	LD DE,(SEED+2)
	LD HL,(SEED)
	LD B,5
RLP1:
    RR H
	RL L
	RR D
	RL E
	DJNZ RLP1
	LD B,3
RLP2:
    PUSH DE
	LD DE,(SEED)
	OR A
	SBC HL,DE
	EX DE,HL
	POP HL
	DJNZ RLP2
	LD (SEED),HL
	LD (SEED+2),DE
	LD A,E
	OR H
	POP DE
	POP BC
	POP HL
	RET

; NMI routine
; - updates a time counter,
; - plays any songs
; - writes in memory sprite table to VDU
; - calls user defined hook - for other writes
; - update the time counters
NMI:
	PUSH	AF
	PUSH	BC
	PUSH	DE
	PUSH	HL
	PUSH	IX
	PUSH	IY
	EX	AF,AF'
	PUSH	AF
	EXX
	PUSH	BC
	PUSH	DE
	PUSH	HL
	; update our time counter
    LD HL,(TIME)
    DEC HL
    LD (TIME),HL
    ;Now we can safely call any OS7 calls
	CALL	PLAY_SONGS	;Update active music
	CALL	SOUND_MAN	;Prepare for next go at music
	; write sprite table
    CALL    SPRWRT
    LD A,(VDU_HOOK)
    CP 0cdh
    JR NZ,NMI2
    CALL VDU_HOOK
 NMI2:
	CALL	TIME_MGR

;Now restore everything
	POP	HL
	POP	DE
	POP	BC
	EXX
	POP	AF
	EX	AF,AF'
	POP	IY
	POP	IX
	POP	HL
	POP	DE
	POP	BC

	CALL	READ_REGISTER	;Side effect allows another NMI to happen

	POP	AF

	RETN	;Non maskable interrupt used for:
		;music, processing timers, sprite motion processing

; Set origin in Coleco RAM area
    ORG 07000h ; fit common items before the BIOS RAM usage area

TickTimer:    DS 1 ; Signal that 3 frames has elapsed
HalfSecTimer: DS 1 ; Signal that 1/2 second has elapsed
QtrSecTimer:  DS 1 ; Signal that 1/4 second has elapsed
TIME:         DS 2
SEED:	      DS 4
CONTROLLER_BUFFER:	DS 12	;Pointer to hand controller input area
MOVDLY:       DS 10      ; Up to 10 movement timers

    ORG 07030h ; avoid Coleco BIOS RAM usage area

; Sprite positions
SPRTBL:       DS 80h
SPRORDER:     DS 1 ; flag to indicate the current sprite write direction
TIMER_TABLE:	    DS 16	;Pointer to timers table (16 timers)
TIMER_DATA_BLOCK:	DS 58	;Pointer to timers table for long timers
                            ;4 bytes * 16 longer than 3 sec timers
VDU_HOOK: DS 4 ; NMI VDU Delayed writes hook


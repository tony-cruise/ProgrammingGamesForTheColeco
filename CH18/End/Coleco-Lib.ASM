;
; Coleco SUBROUTINES
;
; HL = Hook Address
SET_VDU_HOOK:
   LD A,0cdh
   LD (VDU_HOOK),A
   LD (VDU_HOOK+1),HL
   LD A,0c9h
   LD (VDU_HOOK+3),A
   RET

DISABLE_NMI:
	ld      a,(073c4h)
	and     0dfh
DNMI1:
	ld      c,a
	ld      b,1
	jp      01fd9h

ENABLE_NMI:
	ld      a,(073c4h)
	or      020h
	call    DNMI1
	jp      01fdch

ENABLE_SGM_MEMORY:
    LD A,00000001bh
    OUT (53h),A
    RET

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
;
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

;===========================================================================
; unRLEWBtoVRAM v1.1 (26 jun 2014)
; Function : Unpack WB RLE to VRAM
;
; Input    : HL - source RAM RLE data address
;            DE - target VRAM address
;
; $80 nn dd            ; run of n consecutive identical bytes ($1>$FE), value dd
; $80 $0               ; for one $80 value
; $80 $FF              ; end of data block
; <any other value>    ; raw data
;===========================================================================

RLECONTROL: EQU   080h

unRLEWBtoVRAM:
  ; set VRAM addr
  ex de,hl
  call SETWRT
  ex de,hl

ANALYZE:
  ld    A,(HL)         ; get byte
  cp    RLECONTROL
  jr    NZ,WriteByte   ; if raw

  inc   HL             ; get next byte
  ld    A,(HL)
  or    A
  jr    Z,WriteCONTROL ;if A=0 then write one $80  ($80 $0)
  cp    0FFh            ;if A=$FF ($80 $FF)
  ret   Z              ;then exit

  ;$80 nn dd
  inc   A              ;2 to 255
  ld    B,A
  inc   HL
  ld    A,(HL)         ;get value

doRLE:
  out   (DATA_PORT),A    ;write in VRAM
  nop
  nop
  djnz  doRLE

  inc   HL
  jr    ANALYZE

WriteCONTROL:
  ld    A,RLECONTROL  ;write CONTROL value

WriteByte:
  out   (DATA_PORT),A   ;write in VRAM
  ;nop
  inc   HL
  jr    ANALYZE

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
;
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
;
; Read ^[STOP], Z FLAG SET IF TRUE
BREAKX:
    RET ; disable
    LD A,22
    OUT (0AAh),A
    IN A,(0A9h)
    BIT 1,A
    RET NZ
    LD A,23
    OUT (0AAh),A
    IN A,(0A9h)
    BIT 4,A
    RET
;
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
;
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
;
; Write Sprite positions to VRAM
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
    LD HL,SPRTBL+80h-4
    LD B,32
    LD DE,7
SW2:
    LD A,(HL)
    INC HL
    OUT (DATA_PORT),A
    LD A,(HL)
    INC HL
    OUT (DATA_PORT),A
    LD A,(HL)
    INC HL
    OUT (DATA_PORT),A
    LD A,(HL)
    OUT (DATA_PORT),A
    XOR A
    SBC HL,DE
    DJNZ SW2
    RET
;
; Setup Screen 2,2
SETSCREEN2:
;    CALL MODE_1
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
    ; 16KB VIDEO MEMORY, 16x16 NORMAL SPRITES, AND TURN ON SCREEN
    ;ld  bc,01e2h; $01c2 ; $01e2 ; = AND ENABLE NMI EXECUTION
    ;call WRITE_REGISTER
    ;RET ; // coleco screen mode set
;	LD HL,0101h
;	LD (BAKCLR),HL
;	LD IX,005Fh
;	LD IY,0
;	LD A,2
;	CALL BANKCL
;	LD A,(RG1SAV)
;	OR 2
;	LD B,A
;	LD C,1
;	lD IX,0047h
;	LD IY,0
;	CALL BANKCL
;	RET

;
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

JOYPAD:
    CALL POLLER
    LD A,(CONTROLLER_BUFFER+KEYPAD1)
    RET
;
; Test for the direction of joystick 0 or 1
; Result: A
JOYDIR:
       CALL POLLER
       LD A,(CONTROLLER_BUFFER+JOY1)
       RET
;    RET ; disable
;    DI
;    LD A,1
;    LD IX,00D5h
;    LD IY,0
;    CALL 001Ch
;    PUSH AF
;    LD A,1
;    CALL 001Ch
;    LD B,A
;    POP AF
;    OR B
;    EI
;    RET
;
SOUND:
    RET ; disable sounds for the moment
;    LD A,(HL)
;    CP 255
;    RET Z
;    OUT (SND1),A
;    INC HL
;    CP 7
;    LD A,(HL)
;    JR NZ,SNDLP1
;    PUSH BC
;    LD B,A
;    IN A,(SND3)
;    AND 192
;    ADD A,B
;    POP BC
;SNDLP1:
;    OUT (SND2),A
;    INC HL
;    JR SOUND
;
; Output a character to the screen nametable
; (HL) contains the character to output
;
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

;*****************************
;    a(BIN) =>  a(BCD) 
;   [0..99] => [00h..99h]
;*****************************
bin2bcd:
    push    bc
    ld  c, a
    ld  b, 8
    xor a
.loop:
    sla c
    adc a, a
    daa
    djnz    .loop
    pop bc
    ret    

;;--------------------------------------------------
;; Binary to BCD conversion
;;
;; Converts a 16-bit unsigned integer into a 6-digit
;; BCD number. 1181 Tcycles
;;
;; input: HL = unsigned integer to convert
;; output: BSD_OUTPUT 0-2 = 6-digit BCD number
;; destroys: A,F,B,C,D,E,H,L
;;--------------------------------------------------
Bin162Bcd:
    LD BC, 16*256+0 ; handle 16 bits, one bit per iteration
    LD DE, 0
cvtLoop:
    ADD HL, HL
    LD A, E
    ADC A, A
    DAA
    LD E, A
    LD A, D
    ADC A, A
    DAA
    LD D, A
    LD A, C
    ADC A, A
    DAA
    LD C, A
    DJNZ cvtLoop
    LD (BSD_OUTPUT),A
    ;EX HL, DE
    LD (BSD_OUTPUT + 1), DE
    ;LD (BSD + 2),L
    RET

;
; Clear the sprites from the screen (set Y=209)
CLEARSPRITES:
	LD B,80h
	LD DE,SPRTBL
CSPR1:
    LD A,209
	LD (DE),A
	INC DE
	;DEC B
	;LD A,B
	;CP 0
	DJNZ CSPR1
	RET
;
; Clear the VDP Pattern table (clears screen)
CLEARPAT:
	LD HL,VRAM_NAME
	LD BC,768
	XOR A
	CALL FILVRM
    RET
;
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
	LD  HL,(AMERICA)    ;How long a second is
    SRA L
    SRA L
    SRA L
    LD  H,0
    LD  A,1 ;set to repeating
    CALL    REQUEST_SIGNAL
    LD  (EighthSecTimer),A     ;Happens once per eighth of a second
    LD	HL,1
	LD	A,1	;set to repeating
	CALL	REQUEST_SIGNAL
	LD	(TickTimer),A		;Happens once per tick
    RET
;
;   Seed Random numbers
;   Seed in HL
SEED_RANDOM:
    LD (SEED),HL
    RR H
    RL L
    LD (SEED+2),HL
    RET
;
;   Generate a random number, based on the initial Seed
;   value.
;
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
	;OR H
	POP DE
	POP BC
	POP HL
	RET
;
; NMI routine
;
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
	;CALL	PLAY_SONGS	;Update active music
	;CALL	SOUND_MAN	;Prepare for next go at music
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
EighthSecTimer: DS 1 ; Signal that 1/8 second has elapsed
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

BSD_OUTPUT: DS 6; Buffer for output BSD digits


; RAM Usage: 30h+80h+1+16+58+4 = 255 bytes
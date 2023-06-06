;--------------------------------------------
; Coleco
;--------------------------------------------
;
; VDP
DATA_PORT: EQU 0BEh ; MSX 098h
CTRL_PORT: EQU 0BFh ; MSX 099h
;
; Video modes
SCRMODE_STANDARD:               EQU 00h
SCRMODE_TEXT:                   EQU 10h
SCRMODE_MULTICOLOR:             EQU 08h
SCRMODE_BITMAP:                 EQU 02h
SCRMODE_BITMAP_TEXT:            EQU 12h
SCRMODE_BITMAP_MULTICOLOR:      EQU 0ah
SCRMODE_BITMAP_TEXT_MULTICOLOR: EQU 1ah
;
; TMS99xxA colours
COLOR_TRANSPARENT:          EQU 00h
COLOR_BLACK:                EQU 01h
COLOR_GREEN:                EQU 02h
COLOR_LIGHT_GREEN:          EQU 03h
COLOR_BLUE:                 EQU 04h
COLOR_LIGHT_BLUE:           EQU 05h
COLOR_DARK_RED:             EQU 06h
COLOR_CYAN:                 EQU 07h
COLOR_RED:                  EQU 08h
COLOR_LIGHT_RED:            EQU 09h
COLOR_YELLOW:               EQU 0ah
COLOR_LIGHT_YELLOW:         EQU 0bh
COLOR_DARK_GREEN:           EQU 0ch
COLOR_MAGENTA:              EQU 0dh
COLOR_GRAY:                 EQU 0eh
COLOR_WHITE:                EQU 0fh

;
; Coleco BIOS Jump Table
RAND_GEN:	    EQU	1ffdh	;Output: 16 bit result in RAND_NUM, HL, A=L
RAND_NUM:	    EQU	73c8h	;2 byte output of last call to RAND_GEN
CALC_OFFSET:    EQU $08c0
LOAD_ASCII:     EQU $1f7f
FILL_VRAM:      EQU $1f82
MODE_1:         EQU $1f85
PUT_VRAM:       EQU $1fbe
WRITE_REGISTER: EQU $1fd9
READ_REGISTER:  EQU $1fdc
WRITE_VRAM:     EQU $1fdf
DECODER:        EQU $1f79
;Timer related calls
INIT_TIMER:     EQU	$1fc7	;**HL=timer table,DE=timer data block
FREE_SIGNAL:	EQU	$1fca	;Note: must not be interrupted
REQUEST_SIGNAL:	EQU	$1fcd
TEST_SIGNAL:	EQU	$1fd0
TIME_MGR:	    EQU	$1fd3
AMERICA:	    EQU	$0069	;Contains how many timer ticks in a second (50/60)
;
; Music/sound effects related
;
SOUND_INIT:	    EQU	1feeh	;B=concurrent voices+effects, HL=song table
SOUND_MAN:	    EQU	1ff4h	;Call during interrupt (late)
PLAY_IT:		EQU	1ff1h	;B=Song number
PLAY_SONGS:	    EQU	1f61h	;Call during interrupt (early)
TURN_OFF_SOUND:	EQU	1fd6h	;No sounds
;
; Coleco Controller related calls and settings
;
POLLER:	            EQU	1febh
;To be added together for CONTROLLER_MAP +0 (player 1), and +1 (player 2)
CONTROLLER_ENABLE:	EQU	80h
KEYPAD_ENABLE:		EQU	10h
ARM_BUTTON_ENABLE:	EQU	8
JOYSTICK_ENABLE:	EQU	2
FIRE_BUTTON_ENABLE:	EQU	1
;Controller Table offsets
PLAYER1:	EQU	0	;Settings (above)
PLAYER2:	EQU	1
FIRE1:	    EQU	2	;Fire button 1 (40h=yes, 0=no)
JOY1:	    EQU	3	;1=N, 2=E, 4=S, 8=W, etc.
SPIN1:	    EQU	4	;counter
ARM1:	    EQU	5	;Arm button 1 (40h=yes, 0=no)
KEYPAD1:	EQU	6	;0-9, '*'=10, '#'=11
FIRE2:	    EQU	7
JOY2:	    EQU	8
SPIN2:	    EQU	9
ARM2:	    EQU	10
KEYPAD2:	EQU	11



StackTop:	        EQU	739fh	;Top of stack, bottom at 7330h (112 bytes in length)
SPRITE_NAME:	    EQU	7030h	;Pointer to sprite name table
	; max 32 sprites * 4 bytes each = 128 bytes
	; note: 7020h-702bh are used for music player.
SPRITE_ORDER:	    EQU	7080h	;Pointer to sprite order table
	; max 32 sprites
WORK_BUFFER:	    EQU	70a0h	;Pointer to graphics work area
	; up to around 300h max usage
;CONTROLLER_BUFFER:	EQU	72a0h	;Pointer to hand controller input area
	;12 bytes
;TIMER_TABLE:	    EQU	72ach	;Pointer to timers table
	;16 timers
;TIMER_DATA_BLOCK:	EQU	72dch	;Pointer to timers table for long timers
	;4 bytes * 16 longer than 3 sec timers

; Any system values
; VRAM DEFAULT TABLES
VRAM_PATTERN:       EQU $0000
VRAM_NAME:          EQU $1800
VRAM_SPRATTR:       EQU $1B00
VRAM_COLOR:         EQU $2000
VRAM_SPRGEN:        EQU $3800

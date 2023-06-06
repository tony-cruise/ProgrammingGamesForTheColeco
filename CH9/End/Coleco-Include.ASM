;---------------------------------------------
; Coleco ver 1.02 (C) Electric Adventures 2020
;---------------------------------------------
;
; Video Display Processor
DATA_PORT: EQU 0beh ;
CTRL_PORT: EQU 0bfh ;
;
; Sound Generator
SND_PORT:  EQU 0ffh ; write only
;
; Game Controller
GC_STROBE_SET:   EQU 080h ; write only
GC_STROBE_RESET: EQU 0c0h ; write only
GC_CONTROLLER1:  EQU 0fch ; read only
GC_CONTROLLER2:  EQU 0ffh ; read only
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
;
; Misc calls
ADD816:          EQU $01b1      ; Add 8-bit value to 16-bit value
BOOT_UP:         EQU $0000      ; Reset console
DECLSN:          EQU $0190
DECMSN:          EQU $019b
DISPLAY_LOGO:    EQU $1319
MSNTOLSN:        EQU $01a6
POWER_UP:        EQU $006e
RAND_GEN:        EQU $1ffd      ; Output: 16 bit result in RAND_NUM, HL, A=L
RAND_NUM:        EQU $73c8      ; 2 byte output of last call to RAND_GEN
;
; Video related calls
FILL_VRAM:       EQU $1f82
GAME_OPT:        EQU $1f7c
GET_VRAM:        EQU $1fbb
INIT_SPR_NM_TBL: EQU $1fc1
INIT_TABLE:      EQU $1fb8
LOAD_ASCII:      EQU $1f7f
MODE_1:          EQU $1f85
PUT_VRAM:        EQU $1fbe
READ_REGISTER:   EQU $1fdc
READ_VRAM:       EQU $1fe2
WRITE_REGISTER:  EQU $1fd9
WRITE_VRAM:      EQU $1fdf
WR_SPR_NM_TBL:   EQU $1fc4
;
; Object routines
ACTIVATE:        EQU $1ff7
CALC_OFFSET:     EQU $08c0
GET_BKGRND:      EQU $0898
INIT_WRITER:     EQU $1fe5
PUT_FRAME:       EQU $080b
PUTOBJ:          EQU $1ffa
PUTSEMI:         EQU $06ff
PUT_MOBILE:      EQU $0a87
PUT0SPRITE:      EQU $08df
PUT1SPRITE:      EQU $0955
PUTCOMPLEX:      EQU $0ea2
PX_TO_PTRN_POS:  EQU $07e8
SET_UP_WRITE:    EQU $0623
WRITER:          EQU $1fe8
;
; Graphics primitives
ENLARGE:           EQU $1f73
REFLECT_HORZONTAL: EQU $1f6d
REFLECT_VERTICAL:  EQU $1f6a
ROTATE_90:         EQU $1f70
;
; Timer related calls
FREE_SIGNAL:    EQU $1fca       ;Note: must not be interrupted
INIT_TIMER:     EQU $1fc7       ;**HL=timer table,DE=timer data block
REQUEST_SIGNAL: EQU $1fcd
TEST_SIGNAL:    EQU $1fd0
TIME_MGR:       EQU $1fd3
AMERICA:        EQU $0069       ;Contains how many timer ticks in a second (50/60)
;
; Music/sound effects related
;
PLAY_IT:        EQU $1ff1       ;B=Song number
PLAY_SONGS:     EQU $1f61       ;Call during interrupt (early)
SOUND_INIT:     EQU $1fee       ;B=concurrent voices+effects, HL=song table
SOUND_MAN:      EQU $1ff4       ;Call during interrupt (late)
TURN_OFF_SOUND: EQU $1fd6       ;No sounds
;
; Coleco Controller related calls and settings
;
CONT_READ:       EQU $113d
CONTROLLER_INIT: EQU $1105
CONTROLLER_SCAN: EQU $1f76
DECODER:         EQU $1f79
POLLER:          EQU $1feb
UPDATE_SPINNER:  EQU $1f88
; controller debounce routines
JOY_DBNCE:       EQU $12b9
FIRE_DBNCE:      EQU $1289
ARM_DBNCE:       EQU $12e9
KBD_DBNCE:       EQU $1250
;
;To be added together for CONTROLLER_MAP +0 (player 1), and +1 (player 2)
CONTROLLER_ENABLE:      EQU     80h
KEYPAD_ENABLE:          EQU     10h
ARM_BUTTON_ENABLE:      EQU     8
JOYSTICK_ENABLE:        EQU     2
FIRE_BUTTON_ENABLE:     EQU     1
;
;Controller Table offsets
PLAYER1:    EQU 0       ;Settings (above)
PLAYER2:    EQU 1
FIRE1:      EQU 2       ;Fire button 1 (40h=yes, 0=no)
JOY1:       EQU 3       ;1=N, 2=E, 4=S, 8=W, etc.
SPIN1:      EQU 4       ;counter
ARM1:       EQU 5       ;Arm button 1 (40h=yes, 0=no)
KEYPAD1:    EQU 6       ;0-9, '*'=10, '#'=11
FIRE2:      EQU 7
JOY2:       EQU 8
SPIN2:      EQU 9
ARM2:       EQU 10
KEYPAD2:    EQU 11

StackTop:     EQU $739f ;Top of stack, bottom at 7330h (112 bytes in length)
SPRITE_NAME:  EQU $7030 ;Pointer to sprite name table
        ; max 32 sprites * 4 bytes each = 128 bytes
        ; note: 7020h-702bh are used for music player.
SPRITE_ORDER: EQU $7080 ; Pointer to sprite order table, max 32 sprites
WORK_BUFFER:  EQU $70a0 ;Pointer to graphics work area, up to around 300h max usage

; Any system values
; VRAM DEFAULT TABLES
VRAM_PATTERN:       EQU $0000
VRAM_NAME:          EQU $1800
VRAM_SPRATTR:       EQU $1B00
VRAM_COLOR:         EQU $2000
VRAM_SPRGEN:        EQU $3800
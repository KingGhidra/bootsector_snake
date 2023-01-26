;; rounded to the nearest power of 2
SCREEN_WIDTH:        EQU 0x1F
SCREEN_HEIGHT:       EQU 0x0F
SCREEN_MASK:         EQU  SCREEN_HEIGHT      | ( SCREEN_WIDTH      << 8)
SCREEN_CENTER:       EQU (SCREEN_HEIGHT / 2) | ((SCREEN_WIDTH / 2) << 8)
SCREEN_BOTTOM_LEFT:  EQU (SCREEN_HEIGHT + 1) | (1                  << 8)
SCREEN_BOTTOM_RIGHT: EQU (SCREEN_HEIGHT + 1) | ((SCREEN_WIDTH - 1) << 8)

;; https://en.wikipedia.org/wiki/Code_page_737
TXT_HEART:       EQU 0x3
TXT_FACE:        EQU 0x1
TXT_CIRCLE:      EQU 0x9
TXT_UP_ARROW:    EQU 0x18
TXT_DOWN_ARROW:  EQU 0x19
TXT_RIGHT_ARROW: EQU 0x1A
TXT_LEFT_ARROW:  EQU 0x1B

;; https://www.fountainware.com/EXPL/bios_key_codes.htm
KEY_LEFT:  EQU 0x4B
KEY_RIGHT: EQU 0x4D
KEY_UP:    EQU 0x48
KEY_DOWN:  EQU 0x50

;; https://i.stack.imgur.com/A8gMs.png
;; https://wiki.osdev.org/Memory_Map_(x86)
;; Free memory: 0x7E00 -> 0x9FC00
;;              0x0500 -> 0x7C00
MEM_BASE: EQU 0x7E00

;; byte food_pos[2];
FOOD_POS:  EQU MEM_BASE + 0x0

;; short rand_seed;
;RAND_SEED: EQU MEM_BASE + 0x2

;; short time;
TIME: EQU MEM_BASE + 0x2

;; short score;
SCORE: EQU MEM_BASE + 0x4

;; byte direction;
DIRECTION: EQU MEM_BASE + 0x6

;; byte grow;
GROW: EQU MEM_BASE + 0x7

;; circular queue
;; short snake_head, snake_tail
SNAKE_HEAD: EQU MEM_BASE + 0x8
SNAKE_TAIL: EQU MEM_BASE + 0xA
;; short snake[SCREEN_WIDTH * SCREEN_HEIGHT];
SNAKE_BASE: EQU MEM_BASE + 0xC
SNAKE_SIZE: EQU 0x3FF ; rounded to the nearest power of 2

;; BootSector start position 
[ORG 0x7C00]

;; Text Mode 40×25
MOV AX, 0x1
INT 0x10

;; Hide cursor
MOV CH, 0x22
MOV AH, 0x01
INT 0x10

;; tiny model CS=DS=SS
;XOR AX, AX
;MOV DS, AX
;MOV SS, AX
;MOV SP, 0x7C00

;; srand(time());
MOV AH, 0
INT 0x1A
MOV [TIME], WORD DX

INIT_GAME:
	;; food_pos = rand() & screen_mask;
	CALL RAND
	AND AX, SCREEN_MASK
	MOV [FOOD_POS], WORD AX

	MOV AX, SCREEN_CENTER
	MOV [SNAKE_BASE], WORD AX

	MOV [SNAKE_HEAD], WORD 0x0
	MOV [SNAKE_TAIL], WORD 0x0
	MOV [DIRECTION],  WORD MOVE_SNAKE_NONE
	MOV [GROW],       BYTE 0x5
	MOV [SCORE],      WORD 0x0

GAME_LOOP:
	;; Draw food
	MOV AX, WORD [FOOD_POS]
	CALL MOVE_CURSOR
	MOV CL, TXT_HEART
	CALL PUTCHAR

	;; short new_head = snake[snake_head];
	MOV BX, WORD   [SNAKE_HEAD]
	MOV DX, WORD BX[SNAKE_BASE]

	;; Check if a key is pressed
	MOV AH, 0x1
	INT 0x16
	JZ USE_OLD_KEY ; key isn't pressed

	;; Check key code
	MOV AH, 0x0
	INT 0x16

	;; Make sure the new key isn't in the opposite direction
	MOV AL, [DIRECTION]
	CMP AX, KEY_UP | KEY_DOWN << 8
	JE USE_OLD_KEY
	CMP AX, KEY_DOWN | KEY_UP << 8
	JE USE_OLD_KEY
	CMP AX, KEY_LEFT | KEY_RIGHT << 8
	JE USE_OLD_KEY
	CMP AX, KEY_RIGHT | KEY_LEFT << 8
	JE USE_OLD_KEY

	;; Update our direction
	MOV [DIRECTION], AH

	USE_OLD_KEY:
	MOV AL, BYTE [DIRECTION]

	CMP AL, KEY_UP
	JE KEYBOARD_UP
	CMP AL, KEY_DOWN
	JE KEYBOARD_DOWN
	CMP AL, KEY_RIGHT
	JE KEYBOARD_RIGHT
	CMP AL, KEY_LEFT
	JE KEYBOARD_LEFT
	JMP MOVE_SNAKE_NONE

	KEYBOARD_UP:
	DEC DL ; new_head.y--;
	MOV CL, TXT_UP_ARROW
	JMP MOVE_SNAKE_END

	KEYBOARD_DOWN:
	INC DL ; new_head.y++;
	MOV CL, TXT_DOWN_ARROW
	JMP MOVE_SNAKE_END

	KEYBOARD_RIGHT:
	INC DH ; new_head.x++;
	MOV CL, TXT_RIGHT_ARROW
	JMP MOVE_SNAKE_END

	KEYBOARD_LEFT:
	DEC DH ; new_head.x--;
	MOV CL, TXT_LEFT_ARROW
	JMP MOVE_SNAKE_END

	MOVE_SNAKE_END:
		;; Print direction arrow
		MOV AX, SCREEN_BOTTOM_RIGHT
		CALL MOVE_CURSOR
		CALL PUTCHAR

		;; if(new_head & ~screen_mask) reset();
		;; Uncomment to disable wrapping
		;TEST DX, ~SCREEN_MASK
		;JNZ INIT_GAME

		;; snake.push(new_head);
		INC BX
		INC BX
		AND BX, SNAKE_SIZE
		AND DX, SCREEN_MASK
		MOV BX[SNAKE_BASE], WORD DX
		MOV   [SNAKE_HEAD], WORD BX

		;; if(grow != 0)
		MOV  CL, BYTE [GROW]
		TEST CL, CL
		JNZ MOVE_SNAKE_DEC_GROW

			;; snake.pop();
			MOV BX, [SNAKE_TAIL]
			INC BX
			INC BX
			AND BX, SNAKE_SIZE
			MOV [SNAKE_TAIL], BX
			JMP MOVE_SNAKE_NONE

		;; else grow--;
		MOVE_SNAKE_DEC_GROW:
			DEC CL
			MOV [GROW], BYTE CL

	MOVE_SNAKE_NONE:

	;; Print new_head
	MOV AX, DX
	CALL MOVE_CURSOR
	MOV CL, TXT_FACE
	CALL PUTCHAR

	;; short i = snake_tail;
	MOV BX, WORD [SNAKE_TAIL]

	;; while(true) {
	DRAW_SNAKE_LOOP:
		;; if(snake[i] == snake[snake_head]) break; 
		CMP BX, [SNAKE_HEAD]
		JE DRAW_SNAKE_END
		MOV AX, WORD BX[SNAKE_BASE]

		;; move_cursor(snake[i]);
		CALL MOVE_CURSOR
		;; putchar(txt_circle);
		MOV CL, TXT_CIRCLE
		CALL PUTCHAR

		;; if(new_head == snake[i]) reset();
		CMP AX, DX
		JE INIT_GAME

		;; if(food == snake[i]) {
		CMP AX, [FOOD_POS]
		JNE NOT_FOOD
			;; grow += 5;
			MOV AL, BYTE [GROW]
			ADD AL, 0x5
			MOV [GROW], BYTE AL
			;; food = rand() & screen_mask;
			CALL RAND
			AND AX, SCREEN_MASK
			MOV [FOOD_POS], WORD AX
			;; score++;
			MOV AX, WORD [SCORE]
			INC AX
			MOV [SCORE], WORD AX
		NOT_FOOD: ; }

		;; i = (i + 2) % SNAKE_SIZE;
		INC BX
		INC BX
		AND BX, SNAKE_SIZE

		JMP DRAW_SNAKE_LOOP
	;; }
	DRAW_SNAKE_END:

	MOV AX, SCREEN_BOTTOM_LEFT
	CALL MOVE_CURSOR
	CALL PRINT_SCORE

	SLEEP:
		MOV AH, 0x0
		INT 0x1A
		CMP DX, [TIME]
		JE SLEEP
		MOV [TIME], DX
	
	;; Clear the screen.
	MOV AH, 0x6
	MOV AL, 0x0               ; Scroll
	MOV BH, 0x90              ; Color
	MOV CH, SCREEN_HEIGHT + 1 ; Start row
	MOV CL, 0                 ; Start col
	MOV DH, SCREEN_HEIGHT + 1 ; End row
	MOV DL, SCREEN_WIDTH      ; End col
	INT 0x10

	MOV AH, 0x6
	MOV AL, 0x0           ; Scroll
	MOV BH, 0x1F          ; Color
	MOV CH, 0             ; Start row
	MOV CL, 0             ; Start col
	MOV DH, SCREEN_HEIGHT ; End row
	MOV DL, SCREEN_WIDTH  ; End col
	INT 0x10

	JMP GAME_LOOP

;; OUT AX: Random number
RAND:
	PUSH CX
	;; The food gets stuck on the same line if we have a shitty seed.
	;; Just use the time instead.
	;MOV AX, WORD [RAND_SEED]
	MOV AX, WORD [TIME]
	MOV CX, 75
	MUL CX
	ADD AX, 74
	;MOV [RAND_SEED], WORD AX
	POP CX
	RET

; IN AH: x
; IN AL: y
MOVE_CURSOR:
	PUSH DX
	MOV DL, AH
	MOV DH, AL
	PUSH AX
	PUSH BX
	MOV BH, 0x0
	MOV AH, 0x2
	INT 0x10
	POP BX
	POP AX
	POP DX
	RET

; IN CL: char
PUTCHAR:
	PUSH AX
	MOV AL, CL
	MOV AH, 0x0E
  	INT 0x10
	POP AX
	RET

PRINT_SCORE:
	PUSHAD
	MOV CL, 'S'
	CALL PUTCHAR
	MOV CL, 'c'
	CALL PUTCHAR
	MOV CL, 'o'
	CALL PUTCHAR
	MOV CL, 'r'
	CALL PUTCHAR
	MOV CL, 'e'
	CALL PUTCHAR
	MOV CL, ':'
	CALL PUTCHAR

	;; short number = score;
	MOV AX, WORD [SCORE]
	MOV BX, 10

	;; short i = 0;
	XOR CX, CX

	;; do {
	PUSH_LOOP:
		;; 0000:number `div` 10
		XOR DX, DX
		DIV BX ; number = number / 10;
		INC CX ; i++;
		ADD DL, '0'
		PUSH DX ; push((number % 10) + '0');
	;; } while(number != 0);
		TEST AX, AX
		JNZ PUSH_LOOP

	;; while(i--) putchar(pop());
	POP_LOOP:
		POP DX
		PUSH CX
		MOV CL, DL
		CALL PUTCHAR
		POP CX
		LOOP POP_LOOP
	POPAD
	RET

TIMES 510 - ($ - $$) DB 0
;; MBR magic number
DW 0xAA55
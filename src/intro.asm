; ============================================================
; C0MAN  --  intro.asm
; Boot animation (F O N Y scrolls up from the bottom to the
; middle of the screen) and the title/welcome screen.
; ============================================================

INTRO_TARGET_ROW EQU 11

TITLE_TEXT:        DB T_PAC_OPEN_R, T_PAC_CLOSED, "MAN",0
PRESS_SPACE_TEXT:  DB "PRESS SPACE TO START",0
HISCORE_HDR_TEXT:  DB "HIGH SCORES",0

; ---- INTRO_INIT: call once when entering GS_INTRO --------------------
INTRO_INIT:
        CALL    CLEAR_SCREEN
        LD      A,23
        LD      (INTRO_ROW),A
        XOR     A
        LD      (INTRO_TIMER),A
        LD      (INTRO_PHASE),A
        RET

; ---- INTRO_UPDATE: call once per frame during GS_INTRO ----------------
INTRO_UPDATE:
        LD      A,(INTRO_PHASE)
        OR      A
        JR      NZ,IU_HOLD

        LD      A,(INTRO_TIMER)
        INC     A
        LD      (INTRO_TIMER),A
        CP      3
        RET     NZ
        XOR     A
        LD      (INTRO_TIMER),A

        CALL    INTRO_ERASE_ROW
        LD      A,(INTRO_ROW)
        CP      INTRO_TARGET_ROW
        JR      Z,IU_REACHED
        DEC     A
        LD      (INTRO_ROW),A
        JP      INTRO_DRAW_ROW
IU_REACHED:
        CALL    INTRO_DRAW_ROW
        LD      A,1
        LD      (INTRO_PHASE),A
        XOR     A
        LD      (INTRO_TIMER),A
        RET
IU_HOLD:
        LD      A,(INTRO_TIMER)
        INC     A
        LD      (INTRO_TIMER),A
        CP      100
        RET     C
        LD      A,GS_TITLE
        LD      (GAME_STATE),A
        JP      TITLE_INIT

; letters are fixed at columns 17/19/21/23, only the row animates
INTRO_DRAW_ROW:
        LD      A,(INTRO_ROW)
        LD      B,A
        LD      C,17
        LD      A,'F'
        CALL    PUT_TILE
        LD      A,(INTRO_ROW)
        LD      B,A
        LD      C,19
        LD      A,'O'
        CALL    PUT_TILE
        LD      A,(INTRO_ROW)
        LD      B,A
        LD      C,21
        LD      A,'N'
        CALL    PUT_TILE
        LD      A,(INTRO_ROW)
        LD      B,A
        LD      C,23
        LD      A,'Y'
        JP      PUT_TILE

INTRO_ERASE_ROW:
        LD      A,(INTRO_ROW)
        LD      B,A
        LD      C,17
        LD      A,T_SPACE
        CALL    PUT_TILE
        LD      A,(INTRO_ROW)
        LD      B,A
        LD      C,19
        LD      A,T_SPACE
        CALL    PUT_TILE
        LD      A,(INTRO_ROW)
        LD      B,A
        LD      C,21
        LD      A,T_SPACE
        CALL    PUT_TILE
        LD      A,(INTRO_ROW)
        LD      B,A
        LD      C,23
        LD      A,T_SPACE
        JP      PUT_TILE

; ============================================================
; Title / welcome screen
; ============================================================
TITLE_INIT:
        CALL    CLEAR_SCREEN
        LD      HL,TITLE_TEXT
        LD      B,3
        LD      C,18
        CALL    PRINT_AT
        LD      HL,HISCORE_HDR_TEXT
        LD      B,6
        LD      C,14
        CALL    PRINT_AT
        CALL    HISCORE_DRAW_LIST
        LD      HL,PRESS_SPACE_TEXT
        LD      B,20
        LD      C,10
        JP      PRINT_AT

; ---- TITLE_UPDATE: call once per frame during GS_TITLE ----------------
TITLE_UPDATE:
        CALL    IS_SPACE_DOWN
        OR      A
        RET     Z
        CALL    RESET_GAME_STATS
        CALL    LEVEL_START
        LD      A,GS_PLAYING
        LD      (GAME_STATE),A
        RET

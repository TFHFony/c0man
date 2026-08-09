; ============================================================
; C0MAN  --  score.asm
; Score/lives/level state and HUD rendering
; ============================================================

HUD_LABEL_SCORE: DB "SCORE",0
HUD_LABEL_HIGH:  DB "HIGH",0
HUD_LABEL_LV:    DB "LV",0

; ---- HUD_INIT: draw the static HUD labels (call once at boot) -------
HUD_INIT:
        LD      HL,HUD_LABEL_SCORE
        LD      B,HUD_ROW
        LD      C,0
        CALL    PRINT_AT
        LD      HL,HUD_LABEL_HIGH
        LD      B,HUD_ROW
        LD      C,14
        CALL    PRINT_AT
        LD      HL,HUD_LABEL_LV
        LD      B,HUD_ROW
        LD      C,28
        JP      PRINT_AT

; ---- RESET_GAME_STATS: score=0, 3 lives, level 1, base speeds -------
RESET_GAME_STATS:
        XOR     A
        LD      (SCORE_BCD),A
        LD      (SCORE_BCD+1),A
        LD      (SCORE_BCD+2),A
        LD      A,3
        LD      (LIVES),A
        LD      A,1
        LD      (LEVEL),A
        LD      A,8
        LD      (PAC_MOVESPD),A
        LD      A,10
        LD      (GHOST_SPEED),A
        XOR     A
        LD      (DYING_TIMER),A         ; was never initialised - a leftover
                                         ; power-on garbage value here could
                                         ; make the very first death's pause
                                         ; skip almost instantly
        RET

; ---- NEXT_LEVEL: level+1, speeds up every level, forever - no cap.
; Down to the old floor (PAC_MOVESPD 4/GHOST_SPEED 5) it steps by 1
; every level same as before; below that it steps by 1 every OTHER
; level instead (smaller steps, since it's already fast), down to an
; absolute minimum of 1 frame/cell-step (0 would be meaningless). It
; keeps getting faster forever - by design this eventually becomes
; unplayable at high levels. ------------------------------------------
NEXT_LEVEL:
        LD      A,(LEVEL)
        INC     A
        LD      (LEVEL),A
        CALL    DRAW_LEVEL

        LD      A,(PAC_MOVESPD)
        CP      1
        JR      Z,NL_PACDONE            ; already at the hard floor
        CP      4
        JR      NC,NL_PAC_DEC           ; still >=4 - step every level
        LD      A,(LEVEL)
        AND     1
        JR      Z,NL_PACDONE            ; below 4 - only odd levels step
NL_PAC_DEC:
        LD      A,(PAC_MOVESPD)
        DEC     A
        LD      (PAC_MOVESPD),A
NL_PACDONE:

        LD      A,(GHOST_SPEED)
        CP      1
        JR      Z,NL_GHDONE
        CP      5
        JR      NC,NL_GH_DEC
        LD      A,(LEVEL)
        AND     1
        JR      Z,NL_GHDONE
NL_GH_DEC:
        LD      A,(GHOST_SPEED)
        DEC     A
        LD      (GHOST_SPEED),A
NL_GHDONE:
        RET

; ---- LOSE_LIFE: -1 life, GAME_STATE -> GS_DYING or GS_GAMEOVER -------
LOSE_LIFE:
        LD      A,(LIVES)
        DEC     A
        LD      (LIVES),A
        PUSH    AF                      ; DRAW_LIVES clobbers A - keep the
        CALL    DRAW_LIVES              ; decremented value/flags safe across it
        POP     AF
        OR      A
        JR      NZ,LL_CONTINUE
        LD      A,SND_GAMEOVER
        CALL    SOUND_PLAY
        LD      A,GS_GAMEOVER
        LD      (GAME_STATE),A
        RET
LL_CONTINUE:
        LD      A,SND_LIFE
        CALL    SOUND_PLAY
        LD      A,GS_DYING
        LD      (GAME_STATE),A
        RET

; ---- ADD_SCORE_BCD: D=high BCD pair, E=low BCD pair -> adds to
; SCORE_BCD (3 bytes, +0=lowest pair..+2=highest pair) and refreshes
; the SCORE / HIGH HUD fields. -----------------------------------------
ADD_SCORE_BCD:
        LD      HL,SCORE_BCD
        LD      A,(HL)
        ADD     A,E
        DAA
        LD      (HL),A
        INC     HL
        LD      A,(HL)
        ADC     A,D
        DAA
        LD      (HL),A
        INC     HL
        LD      A,(HL)
        ADC     A,0
        DAA
        LD      (HL),A
        CALL    DRAW_SCORE
        JP      DRAW_HIGHSCORE

; ---- IS_NEW_HIGH: -> A=1 if SCORE_BCD > HISCORE_TBL[0].score ---------
; (CMP3_GT lives in highscore.asm)
IS_NEW_HIGH:
        LD      HL,SCORE_BCD
        LD      DE,HISCORE_TBL+3
        JP      CMP3_GT

; ---- BCD_BYTE_TO_ASCII2: A=BCD byte -> writes 2 ASCII digits to
; (DE),(DE+1) and advances DE by 2 --------------------------------------
BCD_BYTE_TO_ASCII2:
        PUSH    AF
        RRA
        RRA
        RRA
        RRA
        AND     $0F
        ADD     A,'0'
        LD      (DE),A
        INC     DE
        POP     AF
        AND     $0F
        ADD     A,'0'
        LD      (DE),A
        INC     DE
        RET

; ---- BCD3_TO_ASCII: HL=ptr to 3-byte BCD (little-endian pairs),
; DE=dest 6-byte ASCII buffer (most-significant digits first) ---------
BCD3_TO_ASCII:
        INC     HL
        INC     HL              ; -> highest pair
        LD      A,(HL)
        CALL    BCD_BYTE_TO_ASCII2
        DEC     HL
        LD      A,(HL)
        CALL    BCD_BYTE_TO_ASCII2
        DEC     HL
        LD      A,(HL)
        JP      BCD_BYTE_TO_ASCII2

; ---- DRAW_SCORE ------------------------------------------------------
DRAW_SCORE:
        LD      HL,SCORE_BCD
        LD      DE,TXT_BUF
        CALL    BCD3_TO_ASCII
        XOR     A
        LD      (TXT_BUF+6),A
        LD      HL,TXT_BUF
        LD      B,HUD_ROW
        LD      C,6
        JP      PRINT_AT

; ---- DRAW_HIGHSCORE (shows the higher of live score vs table best) --
DRAW_HIGHSCORE:
        CALL    IS_NEW_HIGH
        OR      A
        LD      HL,HISCORE_TBL+3
        JR      Z,DH_GO
        LD      HL,SCORE_BCD
DH_GO:
        LD      DE,TXT_BUF
        CALL    BCD3_TO_ASCII
        XOR     A
        LD      (TXT_BUF+6),A
        LD      HL,TXT_BUF
        LD      B,HUD_ROW
        LD      C,19
        JP      PRINT_AT

; ---- DRAW_LEVEL (LEVEL is a plain binary byte, 1..99) ----------------
DRAW_LEVEL:
        LD      A,(LEVEL)
        LD      B,0
DL_TENS:
        CP      10
        JR      C,DL_DONE
        SUB     10
        INC     B
        JR      DL_TENS
DL_DONE:
        LD      C,A
        LD      A,B
        ADD     A,'0'
        LD      (TXT_BUF+0),A
        LD      A,C
        ADD     A,'0'
        LD      (TXT_BUF+1),A
        XOR     A
        LD      (TXT_BUF+2),A
        LD      HL,TXT_BUF
        LD      B,HUD_ROW
        LD      C,31
        JP      PRINT_AT

; ---- DRAW_LIVES: up to 3 small pac-man icons at cols 35-37 -----------
DRAW_LIVES:
        LD      A,(LIVES)
        LD      (DLV_COUNT),A
        XOR     A
        LD      (DLV_IDX),A
DLV_LOOP:
        LD      A,(DLV_IDX)
        CP      3
        RET     Z
        LD      B,HUD_ROW
        ADD     A,35
        LD      C,A
        LD      A,(DLV_IDX)
        LD      HL,DLV_COUNT
        CP      (HL)
        JR      NC,DLV_BLANK
        LD      A,T_PAC_CLOSED
        JR      DLV_PUT
DLV_BLANK:
        LD      A,T_SPACE
DLV_PUT:
        CALL    PUT_TILE
        LD      A,(DLV_IDX)
        INC     A
        LD      (DLV_IDX),A
        JR      DLV_LOOP

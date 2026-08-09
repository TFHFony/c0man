; ============================================================
; C0MAN  --  ghosts.asm
; 4 ghosts: simple AI (random turn at junctions with a bias
; toward/away from the player), pen release, frightened/eaten
; states, collision with the player.
; ============================================================

PEN_DOOR_ROW EQU 9
PEN_DOOR_COL EQU 19

DIR_LIST:       DB DIR_RIGHT,DIR_LEFT,DIR_UP,DIR_DOWN
OPPOSITE_TBL:   DB 0,DIR_LEFT,DIR_RIGHT,DIR_DOWN,DIR_UP        ; indexed by DIR_xxx
GHOST_GLYPH_TBL: DB T_GHOST_BODY,T_GHOST_BODY,T_GHOST_SCARED,T_GHOST_EYES ; indexed by GHST_xxx
PEN_DELAY_TBL:  DB 30,90,150,210
COMBO_SCORE_TBL: DW $0010,$0025,$0050,$0100

; ---- GHOST_INIT: place all 4 ghosts in the pen, staggered release --
GHOST_INIT:
        LD      IX,GHOST_BASE
        LD      B,0
GI_LOOP:
        PUSH    BC
        LD      A,B
        AND     1
        JR      Z,GI_COL19
        LD      A,20
        JR      GI_SETCOL
GI_COL19:
        LD      A,19
GI_SETCOL:
        LD      (IX+0),A
        LD      A,B
        CP      2
        JR      C,GI_ROW10
        LD      A,11
        JR      GI_SETROW
GI_ROW10:
        LD      A,10
GI_SETROW:
        LD      (IX+1),A
        LD      (IX+2),DIR_UP
        LD      (IX+3),GHST_PEN
        XOR     A
        LD      (IX+4),A
        LD      A,(GHOST_SPEED)
        LD      (IX+5),A
        LD      A,B
        LD      HL,PEN_DELAY_TBL
        LD      E,A
        LD      D,0
        ADD     HL,DE
        LD      A,(HL)
        LD      (IX+6),A
        LD      (IX+7),0
        POP     BC
        LD      DE,GHOST_STRIDE
        ADD     IX,DE
        INC     B
        LD      A,B
        CP      NUM_GHOSTS
        JR      NZ,GI_LOOP

        LD      HL,0
        LD      (FRIGHT_TIMER),HL
        XOR     A
        LD      (EAT_COMBO),A
        RET

; ---- GU_DRAW: (IX=ghost record) paint the current glyph -------------
GU_DRAW:
        LD      A,(IX+3)
        LD      HL,GHOST_GLYPH_TBL
        LD      E,A
        LD      D,0
        ADD     HL,DE
        LD      A,(HL)
        LD      B,(IX+1)
        LD      C,(IX+0)
        JP      PUT_TILE

; ---- GU_ERASE: (IX=ghost record) restore the maze tile it was on ----
GU_ERASE:
        LD      B,(IX+1)
        LD      C,(IX+0)
        CALL    MAZE_PTR
        LD      A,(HL)
        JP      PUT_TILE

; ---- GHOST_ERASE_ALL: restore the maze tile under each ghost's CURRENT
; position. Call this BEFORE GHOST_INIT/repositioning, otherwise the
; old glyphs are left behind on screen (e.g. after the player dies). --
GHOST_ERASE_ALL:
        LD      IX,GHOST_BASE
        LD      B,NUM_GHOSTS
GEA_LOOP:
        PUSH    BC
        CALL    GU_ERASE
        POP     BC
        LD      DE,GHOST_STRIDE
        ADD     IX,DE
        DJNZ    GEA_LOOP
        RET

; ---- GHOST_DRAW_ALL: draw all 4 ghosts (used once when a level starts)
GHOST_DRAW_ALL:
        LD      IX,GHOST_BASE
        LD      B,NUM_GHOSTS
GDA_LOOP:
        PUSH    BC
        CALL    GU_DRAW
        POP     BC
        LD      DE,GHOST_STRIDE
        ADD     IX,DE
        DJNZ    GDA_LOOP
        RET

; ---- TRIGGER_FRIGHTEN: called when the player eats a power pill -----
TRIGGER_FRIGHTEN:
        LD      HL,FRIGHT_FRAMES
        LD      (FRIGHT_TIMER),HL
        XOR     A
        LD      (EAT_COMBO),A
        LD      IX,GHOST_BASE
        LD      B,NUM_GHOSTS
TF_LOOP:
        LD      A,(IX+3)
        CP      GHST_EATEN
        JR      Z,TF_SKIP
        CP      GHST_PEN
        JR      Z,TF_SKIP
        LD      (IX+3),GHST_FRIGHT
        PUSH    BC
        CALL    GU_DRAW
        POP     BC
TF_SKIP:
        LD      DE,GHOST_STRIDE
        ADD     IX,DE
        DJNZ    TF_LOOP
        RET

; ---- FRIGHT_TICK: call once per frame during GS_PLAYING -------------
FRIGHT_TICK:
        LD      HL,(FRIGHT_TIMER)
        LD      A,H
        OR      L
        RET     Z
        DEC     HL
        LD      (FRIGHT_TIMER),HL
        LD      A,H
        OR      L
        RET     NZ

        LD      IX,GHOST_BASE
        LD      B,NUM_GHOSTS
FT_LOOP:
        LD      A,(IX+3)
        CP      GHST_FRIGHT
        JR      NZ,FT_SKIP
        LD      (IX+3),GHST_CHASE
        PUSH    BC
        CALL    GU_DRAW
        POP     BC
FT_SKIP:
        LD      DE,GHOST_STRIDE
        ADD     IX,DE
        DJNZ    FT_LOOP
        RET

; ---- GHOST_UPDATE_ALL: call once per frame during GS_PLAYING --------
GHOST_UPDATE_ALL:
        LD      IX,GHOST_BASE
        LD      B,NUM_GHOSTS
GUA_LOOP:
        PUSH    BC
        CALL    GHOST_UPDATE_ONE
        POP     BC
        LD      DE,GHOST_STRIDE
        ADD     IX,DE
        DJNZ    GUA_LOOP
        RET

GHOST_UPDATE_ONE:
        LD      A,(IX+3)
        CP      GHST_PEN
        JP      Z,GU_PEN
        CP      GHST_EATEN
        JP      Z,GU_EATEN
        CALL    GU_MOVE_STEP
        JP      GU_CHECK_COLLISION

GU_PEN:
        LD      A,(IX+6)
        OR      A
        JR      Z,GU_RELEASE
        DEC     A
        LD      (IX+6),A
        JP      GU_DRAW
GU_RELEASE:
        CALL    GU_ERASE                ; wipe the old pen-interior glyph
        LD      (IX+3),GHST_CHASE
        LD      A,PEN_DOOR_ROW
        LD      (IX+1),A
        LD      A,PEN_DOOR_COL
        LD      (IX+0),A
        LD      (IX+2),DIR_UP
        LD      A,(GHOST_SPEED)
        LD      (IX+5),A
        JP      GU_DRAW

GU_EATEN:
        LD      A,3
        LD      (IX+5),A                ; eyes move fast, regardless of level
        CALL    GU_MOVE_STEP
        LD      A,(IX+1)
        CP      PEN_DOOR_ROW
        JR      NZ,GU_EATEN_DONE
        LD      A,(IX+0)
        CP      PEN_DOOR_COL
        JR      Z,GU_BACKHOME
        LD      A,(IX+0)
        CP      PEN_DOOR_COL+1
        JR      NZ,GU_EATEN_DONE
GU_BACKHOME:
        LD      (IX+3),GHST_PEN
        LD      A,60
        LD      (IX+6),A
GU_EATEN_DONE:
        RET

; ---- GU_MOVE_STEP: timer-gated single cell-step for CHASE/FRIGHT/EATEN
GU_MOVE_STEP:
        LD      A,(IX+4)
        OR      A
        JR      Z,GMS_STEP
        DEC     A
        LD      (IX+4),A
        RET
GMS_STEP:
        LD      A,(IX+5)
        LD      (IX+4),A

        LD      A,(IX+3)
        CP      GHST_FRIGHT
        JR      Z,GMS_FLEE
        CP      GHST_EATEN
        JR      Z,GMS_TOPEN
        LD      A,(PAC_ROW)
        LD      (GC_TARGET_ROW),A
        LD      A,(PAC_COL)
        LD      (GC_TARGET_COL),A
        LD      A,1
        LD      (GC_MODE),A
        JR      GMS_CHOOSE
GMS_FLEE:
        LD      A,(PAC_ROW)
        LD      (GC_TARGET_ROW),A
        LD      A,(PAC_COL)
        LD      (GC_TARGET_COL),A
        XOR     A
        LD      (GC_MODE),A
        JR      GMS_CHOOSE
GMS_TOPEN:
        LD      A,PEN_DOOR_ROW
        LD      (GC_TARGET_ROW),A
        LD      A,PEN_DOOR_COL
        LD      (GC_TARGET_COL),A
        LD      A,1
        LD      (GC_MODE),A

GMS_CHOOSE:
        CALL    GHOST_CHOOSE_DIR
        OR      A
        RET     Z

        LD      (GC_CHOSEN),A
        CALL    GU_ERASE
        LD      A,(GC_CHOSEN)
        LD      (IX+2),A
        LD      B,(IX+1)
        LD      C,(IX+0)
        CALL    COMPUTE_TARGET
        LD      (IX+1),B
        LD      (IX+0),C
        JP      GU_DRAW

; ---- GU_CHECK_COLLISION: (IX=ghost) same-cell test vs the player -----
GU_CHECK_COLLISION:
        LD      A,(IX+1)
        LD      B,A
        LD      A,(PAC_ROW)
        CP      B
        RET     NZ
        LD      A,(IX+0)
        LD      B,A
        LD      A,(PAC_COL)
        CP      B
        RET     NZ

        LD      A,(IX+3)
        CP      GHST_FRIGHT
        JP      Z,GCC_EAT
        CP      GHST_EATEN
        RET     Z
        JP      LOSE_LIFE

GCC_EAT:
        LD      A,SND_GHOST
        CALL    SOUND_PLAY              ; IX (ghost record) is untouched by this
        LD      A,(EAT_COMBO)
        CP      3
        JR      C,GCC_OK
        LD      A,3
GCC_OK:
        LD      HL,COMBO_SCORE_TBL
        ADD     A,A
        LD      E,A
        LD      D,0
        ADD     HL,DE
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        CALL    ADD_SCORE_BCD
        LD      A,(EAT_COMBO)
        CP      3
        JR      Z,GCC_NOINC
        INC     A
        LD      (EAT_COMBO),A
GCC_NOINC:
        LD      (IX+3),GHST_EATEN
        JP      GU_DRAW

; ============================================================
; GHOST_CHOOSE_DIR: (IX=ghost record, GC_TARGET_ROW/COL, GC_MODE set)
; -> A = chosen direction (0 if truly no valid move exists)
; ============================================================
GHOST_CHOOSE_DIR:
        LD      A,(IX+2)
        LD      HL,OPPOSITE_TBL
        LD      E,A
        LD      D,0
        ADD     HL,DE
        LD      A,(HL)
        LD      (GC_REVERSE),A

        LD      A,(IX+1)
        LD      B,A
        LD      A,(GC_TARGET_ROW)
        LD      C,A
        CALL    GCD_PREFDIR_V
        LD      (GC_PREF_V),A

        LD      A,(IX+0)
        LD      B,A
        LD      A,(GC_TARGET_COL)
        LD      C,A
        CALL    GCD_PREFDIR_H
        LD      (GC_PREF_H),A

        LD      A,1
        CALL    GCD_SCAN
        LD      A,(GC_CANDCOUNT)
        OR      A
        JR      NZ,GCD_HAVE
        XOR     A
        CALL    GCD_SCAN
GCD_HAVE:
        LD      A,(GC_CANDCOUNT)
        OR      A
        JR      Z,GCD_NONE

        CALL    RANDOM
        AND     $0F
        CP      11
        JR      NC,GCD_RANDPICK

        LD      A,(GC_PREF_V)
        OR      A
        JR      Z,GCD_TRYH
        CALL    GCD_INLIST
        JR      NZ,GCD_TRYH
        LD      A,(GC_PREF_V)
        RET
GCD_TRYH:
        LD      A,(GC_PREF_H)
        OR      A
        JR      Z,GCD_RANDPICK
        CALL    GCD_INLIST
        JR      NZ,GCD_RANDPICK
        LD      A,(GC_PREF_H)
        RET
GCD_RANDPICK:
        CALL    RANDOM
        LD      B,A
        LD      A,(GC_CANDCOUNT)
        LD      C,A
        LD      A,B
        CALL    MOD8
        LD      HL,GC_CANDS
        LD      E,A
        LD      D,0
        ADD     HL,DE
        LD      A,(HL)
        RET
GCD_NONE:
        XOR     A
        RET

; input B=ghost coord, C=target coord, GC_MODE -> A=DIR_UP/DIR_DOWN/0
GCD_PREFDIR_V:
        LD      A,(GC_MODE)
        OR      A
        JR      Z,GPV_FLEE
        LD      A,B
        CP      C
        JR      Z,GPV_NONE
        JR      C,GPV_DOWN
        LD      A,DIR_UP
        RET
GPV_DOWN:
        LD      A,DIR_DOWN
        RET
GPV_FLEE:
        LD      A,B
        CP      C
        JR      Z,GPV_NONE
        JR      C,GPV_UP2
        LD      A,DIR_DOWN
        RET
GPV_UP2:
        LD      A,DIR_UP
        RET
GPV_NONE:
        XOR     A
        RET

; input B=ghost coord, C=target coord, GC_MODE -> A=DIR_LEFT/DIR_RIGHT/0
GCD_PREFDIR_H:
        LD      A,(GC_MODE)
        OR      A
        JR      Z,GPH_FLEE
        LD      A,B
        CP      C
        JR      Z,GPH_NONE
        JR      C,GPH_RIGHT
        LD      A,DIR_LEFT
        RET
GPH_RIGHT:
        LD      A,DIR_RIGHT
        RET
GPH_FLEE:
        LD      A,B
        CP      C
        JR      Z,GPH_NONE
        JR      C,GPH_LEFT2
        LD      A,DIR_RIGHT
        RET
GPH_LEFT2:
        LD      A,DIR_LEFT
        RET
GPH_NONE:
        XOR     A
        RET

; input A=direction -> Z if present in GC_CANDS[0..count-1]
GCD_INLIST:
        LD      B,A
        LD      A,(GC_CANDCOUNT)
        OR      A
        JR      Z,GIL_NOTFOUND
        LD      C,A
        LD      HL,GC_CANDS
GIL_LOOP:
        LD      A,(HL)
        CP      B
        RET     Z
        INC     HL
        DEC     C
        JR      NZ,GIL_LOOP
GIL_NOTFOUND:
        LD      A,1
        OR      A
        RET

; input A=1(exclude GC_REVERSE) or 0(allow all) -> fills GC_CANDS/GC_CANDCOUNT
GCD_SCAN:
        LD      (GC_EXCLFLAG),A
        XOR     A
        LD      (GC_CANDCOUNT),A
        LD      HL,DIR_LIST
        LD      B,4
GCS_LOOP:
        PUSH    BC
        PUSH    HL
        LD      A,(HL)
        CALL    GCD_TRY
        POP     HL
        POP     BC
        INC     HL
        DJNZ    GCS_LOOP
        RET

; ---- MOD8: A=value, C=divisor(1..4) -> A = value mod divisor --------
MOD8:
        OR      A
        RET     Z
MOD8_LOOP:
        CP      C
        JR      C,MOD8_DONE
        SUB     C
        JR      MOD8_LOOP
MOD8_DONE:
        RET

; input A=candidate direction (IX=ghost record still valid)
GCD_TRY:
        LD      B,A                     ; B = candidate dir (for the excl. check)
        LD      A,(GC_EXCLFLAG)
        OR      A
        JR      Z,GCT_NOEXCL
        LD      A,(GC_REVERSE)
        CP      B
        RET     Z
GCT_NOEXCL:
        LD      A,B
        LD      (GC_CANDDIR_TMP),A
        LD      B,(IX+1)                ; B = row
        LD      C,(IX+0)                ; C = col
        LD      A,(GC_CANDDIR_TMP)      ; A = candidate dir
        CALL    COMPUTE_TARGET          ; B,C -> target cell
        CALL    CELL_WALKABLE
        RET     NZ

        LD      A,(GC_CANDCOUNT)
        LD      L,A
        LD      H,0
        LD      DE,GC_CANDS
        ADD     HL,DE
        LD      A,(GC_CANDDIR_TMP)
        LD      (HL),A

        LD      A,(GC_CANDCOUNT)
        INC     A
        LD      (GC_CANDCOUNT),A
        RET

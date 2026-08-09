; ============================================================
; C0MAN  --  pacman.asm
; Player movement, animation, dot/pill collision
; ============================================================

; ---- glyph table indexed by direction (DIR_NONE..DIR_DOWN) ----------
PAC_GLYPH_TBL:
        DB      T_PAC_CLOSED    ; DIR_NONE   (0) - draw closed when idle
        DB      T_PAC_OPEN_R    ; DIR_RIGHT  (1)
        DB      T_PAC_OPEN_L    ; DIR_LEFT   (2)
        DB      T_PAC_OPEN_U    ; DIR_UP     (3)
        DB      T_PAC_OPEN_D    ; DIR_DOWN   (4)

; ---- PAC_RESET: put the player back at its maze start position and
; clear direction/animation/movement-timer state. Does NOT erase the
; player's old on-screen glyph - callers that reposition after the
; player has already moved (e.g. respawn after death) must call
; PAC_ERASE first, while PAC_COL/PAC_ROW still hold the old cell. -----
PAC_RESET:
        LD      A,(PAC_START_COL)
        LD      (PAC_COL),A
        LD      A,(PAC_START_ROW)
        LD      (PAC_ROW),A
        LD      A,DIR_NONE
        LD      (PAC_DIR),A
        LD      (PAC_NEXTDIR),A
        XOR     A
        LD      (PAC_ANIM),A
        LD      (PAC_MOVETMR),A
        RET

; ---- PAC_GET_GLYPH: -> A = tile code for the player's current
; direction/animation state --------------------------------------------
PAC_GET_GLYPH:
        LD      A,(PAC_ANIM)
        OR      A
        JR      NZ,PGG_OPEN
        LD      A,T_PAC_CLOSED
        RET
PGG_OPEN:
        LD      A,(PAC_DIR)
        LD      HL,PAC_GLYPH_TBL
        LD      E,A
        LD      D,0
        ADD     HL,DE
        LD      A,(HL)
        RET

; ---- PAC_DRAW: paint the pac-man glyph at its current cell. Safe to
; call every frame regardless of whether the player actually moved. ---
PAC_DRAW:
        LD      A,(PAC_ROW)
        LD      B,A
        LD      A,(PAC_COL)
        LD      C,A
        CALL    PAC_GET_GLYPH
        JP      PUT_TILE

; ---- PAC_ERASE: restore the maze's true tile under the player's
; (old) cell - call this right BEFORE updating PAC_COL/PAC_ROW --------
PAC_ERASE:
        LD      A,(PAC_ROW)
        LD      B,A
        LD      A,(PAC_COL)
        LD      C,A
        CALL    MAZE_PTR
        LD      A,(HL)
        JP      PUT_TILE

; ---- COMPUTE_TARGET: A=direction, B=row,C=col (in/out) -> B,C become
; the target cell, with tunnel wraparound applied to C on col 0/39/40.
COMPUTE_TARGET:
        CP      DIR_RIGHT
        JR      NZ,CTG_L1
        LD      A,C
        INC     A
        CP      SCR_COLS
        JR      NZ,CTG_SETC
        XOR     A
CTG_SETC:
        LD      C,A
        RET
CTG_L1:
        CP      DIR_LEFT
        JR      NZ,CTG_L2
        LD      A,C
        OR      A
        JR      NZ,CTG_DECOK
        LD      A,SCR_COLS
CTG_DECOK:
        DEC     A
        LD      C,A
        RET
CTG_L2:
        CP      DIR_UP
        JR      NZ,CTG_L3
        DEC     B
        RET
CTG_L3:
        CP      DIR_DOWN
        JR      NZ,CTG_DONE
        INC     B
CTG_DONE:
        RET

; ---- DIR_IS_WALKABLE: A=direction -> Z flag set if the cell adjacent
; to the player's CURRENT position in that direction is walkable.
; Uses PAC_ROW/PAC_COL as the base; does not modify player state. ------
DIR_IS_WALKABLE:
        PUSH    AF
        LD      A,(PAC_ROW)
        LD      B,A
        LD      A,(PAC_COL)
        LD      C,A
        POP     AF
        CALL    COMPUTE_TARGET
        JP      CELL_WALKABLE

; indexed by (PAC_MOVESPD-3) for PAC_MOVESPD in 3..8 -> ~80% of the value
; ---- PAC_UPDATE: called once per frame while GS_PLAYING ---------------
PAC_UPDATE:
        CALL    READ_DIRECTION
        OR      A
        JR      Z,PU_NOKEY
        LD      (PAC_NEXTDIR),A
PU_NOKEY:
        LD      A,(PAC_MOVETMR)
        OR      A
        JR      Z,PU_MOVE
        DEC     A
        LD      (PAC_MOVETMR),A
        RET

PU_MOVE:
        LD      HL,(FRIGHT_TIMER)
        LD      A,H
        OR      L
        JR      Z,PU_NORMALSPD
        ; frightened - 25% faster: fewer frames-per-cell means faster
        ; movement, so subtract a quarter of the normal frame count.
        ; Computed instead of table-driven so it stays correct no
        ; matter how low PAC_MOVESPD gets at high levels (NEXT_LEVEL
        ; no longer caps it) - a fixed-size lookup table indexed by
        ; PAC_MOVESPD used to read out of bounds once speed dropped
        ; below the table's covered range, producing a huge garbage
        ; frame count that looked like Pac-Man had frozen/gone very slow.
        LD      A,(PAC_MOVESPD)
        LD      B,A
        SRL     A
        SRL     A                       ; A = PAC_MOVESPD/4
        LD      C,A
        LD      A,B
        SUB     C                       ; A = PAC_MOVESPD - PAC_MOVESPD/4
        OR      A
        JR      NZ,PU_SETSPD
        INC     A                       ; clamp: never 0 frames/cell
        JR      PU_SETSPD
PU_NORMALSPD:
        LD      A,(PAC_MOVESPD)
PU_SETSPD:
        LD      (PAC_MOVETMR),A

        ; try to turn onto the queued direction if one is pending
        LD      A,(PAC_NEXTDIR)
        OR      A
        JR      Z,PU_TRYFWD
        LD      B,A
        LD      A,(PAC_DIR)
        CP      B
        JR      Z,PU_TRYFWD             ; already facing that way
        LD      A,B
        CALL    DIR_IS_WALKABLE
        JR      NZ,PU_TRYFWD
        LD      A,(PAC_NEXTDIR)
        LD      (PAC_DIR),A

PU_TRYFWD:
        LD      A,(PAC_DIR)
        OR      A
        RET     Z                       ; DIR_NONE -> stand still
        CALL    DIR_IS_WALKABLE
        RET     NZ                      ; blocked - stay put

        CALL    PAC_ERASE               ; redraw the OLD cell's true tile

        LD      A,(PAC_ROW)
        LD      B,A
        LD      A,(PAC_COL)
        LD      C,A
        LD      A,(PAC_DIR)
        CALL    COMPUTE_TARGET          ; B,C = new row,col
        LD      A,B
        LD      (PAC_ROW),A
        LD      A,C
        LD      (PAC_COL),A

        LD      A,(PAC_ANIM)
        XOR     1
        LD      (PAC_ANIM),A

        CALL    EAT_CELL                ; B,C=new pos; A=tile that was there;
                                         ; HL=ptr to that cell in MAZE_STATE
                                         ; (CHEAT_TRIGGER relies on this)
        CP      T_DOT
        JR      Z,PU_ATE_DOT
        CP      T_PILL
        JR      Z,PU_ATE_PILL
        CP      'O'
        JR      Z,PU_ATE_CHEAT
        RET
PU_ATE_DOT:
        LD      A,SND_DOT
        CALL    SOUND_PLAY
        LD      DE,$0001
        JP      ADD_SCORE_BCD
PU_ATE_PILL:
        LD      A,SND_PILL
        CALL    SOUND_PLAY
        LD      DE,$0010
        CALL    ADD_SCORE_BCD
        JP      TRIGGER_FRIGHTEN
PU_ATE_CHEAT:
        CALL    CHEAT_TRIGGER           ; must run first - relies on
                                         ; B/C/HL still holding the eaten
                                         ; cell's row/col/pointer, which
                                         ; SOUND_PLAY below would clobber
        LD      A,SND_PILL
        JP      SOUND_PLAY

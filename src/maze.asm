; ============================================================
; C0MAN  --  maze.asm
; Maze source data (plain ASCII), auto-tiling into proper
; box-drawing wall glyphs, RAM mirror + VRAM rendering, and
; the walkability/eat-cell helpers used by pacman.asm/ghosts.asm
; ============================================================

; ---- MAZE_SRC: 22 rows x 40 cols, plain ASCII -----------------------
; '#'=wall  '.'=dot  'o'=power pill  ' '=empty  'G'=ghost pen floor
; 'P'=pac-man start position
MAZE_SRC:
        DB      "########################################"
        DB      "#o.........XXXXX........XXXXX.........o#"
        DB      "#.##.FONY..XXXXX.######.XXXXX..FONY.##.#"
        DB      "#.##.......XXXXX.######.XXXXX.......##.#"
        DB      "#.##..####.XXXXX........XXXXX.####..##.#"
        DB      "#.##..#  #.......##..##.......#  #..##.#"
        DB      "#.....####.......##..##.......####.....#"
        DB      "#.##........##............##........##.#"
        DB      "#.##........##............##........##.#"
        DB      "#.##.######......##  ##......######.##.#"
        DB      "#.##.#    #......#GGGG#......#    #.##.#"
        DB      " ....#    #......#GGGG#......#    #.... "
        DB      "#....######......######......######....#"
        DB      "#..................P...................#"
        DB      "#.#######...##...######...##...#######.#"
        DB      "#.#######...##...######...##...#######.#"
        DB      "#.##................................##.#"
        DB      "#.##..####.XXXXX.##..##.XXXXX.####..##.#"
        DB      "#.##..#  #.XXXXX.##..##.XXXXX.#  #..##.#"
        DB      "#.##..####.XXXXX.######.XXXXX.####..##.#"
        DB      "#o.........XXXXX........XXXXX.........o#"
        DB      "########################################"

TUNNEL_ROW  EQU 11

; ---- wall outline lookup ---------------------------------------------
; index = the STUB mask (U<<3)|(D<<2)|(L<<1)|R: which directions the
; drawn line must reach out to, so it meets the line in that neighbour.
; Index 0 never reaches the table (it is resolved as hollow-or-dot).
WALL_LUT:
        DB      T_WALL_HOLLOW   ; 0000 unused (handled before the lookup)
        DB      T_WALL_H        ; 0001 R
        DB      T_WALL_H        ; 0010 L
        DB      T_WALL_H        ; 0011 L+R    straight horizontal
        DB      T_WALL_V        ; 0100 D
        DB      T_WALL_TL       ; 0101 D+R    corner opening down-right
        DB      T_WALL_TR       ; 0110 D+L    corner opening down-left
        DB      T_WALL_TEE_D    ; 0111 D+L+R  tee pointing down
        DB      T_WALL_V        ; 1000 U
        DB      T_WALL_BL       ; 1001 U+R    corner opening up-right
        DB      T_WALL_BR       ; 1010 U+L    corner opening up-left
        DB      T_WALL_TEE_U    ; 1011 U+L+R  tee pointing up
        DB      T_WALL_V        ; 1100 U+D    straight vertical
        DB      T_WALL_TEE_R    ; 1101 U+D+R  tee pointing right
        DB      T_WALL_TEE_L    ; 1110 U+D+L  tee pointing left
        DB      T_WALL_CROSS    ; 1111 four-way cross

; ---- MAZE_INIT: parse MAZE_SRC -> MAZE_STATE (RAM) -> VRAM ----------
MAZE_INIT:
        LD      HL,0
        LD      (DOTS_LEFT),HL
        CALL    MZ_PASS1_EXPOSED
        LD      IX,MAZE_SRC
        LD      HL,MAZE_STATE+(MAZE_TOP*SCR_COLS)
        LD      B,0                     ; row (source-relative, 0..21)
MZ_ROWLOOP:
        LD      C,0                     ; col
MZ_COLLOOP:
        LD      A,(IX+0)
        CP      '#'
        JR      Z,MZ_WALL_THIN
        CP      'X'
        JR      Z,MZ_WALL_THIN          ; X is just another wall char now -
                                         ; thin-line auto-tiled the same as #
        CP      '.'
        JR      Z,MZ_DOT
        CP      'o'
        JR      Z,MZ_PILL
        CP      'P'
        JR      Z,MZ_START
        CP      'F'
        JR      Z,MZ_LETTER
        CP      'O'
        JR      Z,MZ_LETTER
        CP      'N'
        JR      Z,MZ_LETTER
        CP      'Y'
        JR      Z,MZ_LETTER
        LD      A,T_SPACE
        JR      MZ_STORE
; MZ_LETTER: the FONY logo letters - solid (blocking, not walkable, not a
; dot to eat), but rendered as their own literal glyph rather than being
; auto-tiled into a wall-line piece like '#'/'X' are.
MZ_LETTER:
        JR      MZ_STORE
MZ_DOT:
        CALL    MZ_COUNT
        LD      A,T_DOT
        JR      MZ_STORE
MZ_PILL:
        CALL    MZ_COUNT
        LD      A,T_PILL
        JR      MZ_STORE
MZ_START:
        LD      A,C
        LD      (PAC_COL),A
        LD      (PAC_START_COL),A
        LD      A,B
        ADD     A,MAZE_TOP              ; store as absolute screen row
        LD      (PAC_ROW),A
        LD      (PAC_START_ROW),A
        LD      A,T_SPACE
        JR      MZ_STORE
; increments DOTS_LEFT(16-bit) without disturbing HL(dest ptr)/B/C/IX
MZ_COUNT:
        PUSH    HL
        PUSH    AF
        LD      HL,(DOTS_LEFT)
        INC     HL
        LD      (DOTS_LEFT),HL
        POP     AF
        POP     HL
        RET

; ---- MZ_WALL_THIN: pick the outline glyph for a wall cell ------------
MZ_WALL_THIN:
        CALL    MZ_CALC_STUBS           ; -> A = glyph (HL/BC/IX preserved)
MZ_STORE:
        LD      (HL),A
        INC     HL
        INC     IX
        INC     C
        LD      A,C
        CP      SCR_COLS
        JP      NZ,MZ_COLLOOP
        INC     B
        LD      A,B
        CP      MAZE_ROWS
        JP      NZ,MZ_ROWLOOP

        ; bulk-copy the finished RAM maze to the VRAM name table
        LD      HL,MAZE_STATE+(MAZE_TOP*SCR_COLS)
        LD      DE,NAMTBL+(MAZE_TOP*SCR_COLS)
        LD      BC,MAZE_SIZE
        CALL    LDIRVM
        RET

; ---- IS_WALLCHAR: A=source char -> Z if it's '#' or 'X' (either counts
; as a wall for the purposes of auto-tiling the thin-line neighbours) --
IS_WALLCHAR:
        CP      '#'
        RET     Z
        CP      'X'
        RET

; ---- IS_BORDER_DE: D=row, E=col -> A=1 if that cell sits on the outer
; border ring, else A=0. The border and the interior blocks are treated
; as separate structures so a block touching the border still gets its
; own dividing line instead of visually fusing with it. ---------------
IS_BORDER_DE:
        LD      A,D
        OR      A
        JR      Z,IBD_YES
        CP      MAZE_ROWS-1
        JR      Z,IBD_YES
        LD      A,E
        OR      A
        JR      Z,IBD_YES
        CP      SCR_COLS-1
        JR      Z,IBD_YES
        XOR     A
        RET
IBD_YES:
        LD      A,1
        RET

; ---- MZ_SET_EXPOSED: A = bit to OR into MZ_MASK (preserves HL/BC/IX)
MZ_SET_EXPOSED:
        PUSH    HL
        LD      HL,MZ_MASK
        OR      (HL)
        LD      (HL),A
        POP     HL
        RET

; ---- MZ_NEIGHBOR_MASK: B=row, C=col, IX=ptr into MAZE_SRC at (row,col)
; returns A = (Up<<3)|(Down<<2)|(Left<<1)|Right where a set bit means
; that side is EXPOSED, i.e. a line must be drawn on that face. A side
; counts as exposed when the neighbour is open space, is off-screen, or
; belongs to the other structure (border vs interior). Preserves HL.
;
; ---- MZ_PASS1_EXPOSED: fill EXP_BUF with one exposed-mask byte per
; maze cell, so the tiling pass can read a neighbour's exposure
; directly instead of recomputing it. Non-wall cells are stored as
; "fully exposed" - they are never consulted as a wall neighbour. ----
MZ_PASS1_EXPOSED:
        LD      IX,MAZE_SRC
        LD      HL,EXP_BUF
        LD      B,0                     ; row
P1_ROWLOOP:
        LD      C,0                     ; col
P1_COLLOOP:
        LD      A,(IX+0)
        CALL    IS_WALLCHAR
        JR      Z,P1_WALL
        LD      A,%00001111             ; open cell
        JR      P1_STORE
P1_WALL:
        CALL    MZ_NEIGHBOR_MASK        ; -> A = exposed mask (preserves HL)
P1_STORE:
        LD      (HL),A
        INC     HL
        INC     IX
        INC     C
        LD      A,C
        CP      SCR_COLS
        JR      NZ,P1_COLLOOP
        INC     B
        LD      A,B
        CP      MAZE_ROWS
        JR      NZ,P1_ROWLOOP
        RET

MZ_NEIGHBOR_MASK:
        XOR     A
        LD      (MZ_MASK),A
        LD      D,B
        LD      E,C
        CALL    IS_BORDER_DE
        LD      (MZ_CURBORDER),A

        ; ---- up ----
        LD      A,B
        OR      A
        JR      Z,MZN_UP_EXP            ; off-screen above
        LD      A,(IX-SCR_COLS)
        CALL    IS_WALLCHAR
        JR      NZ,MZN_UP_EXP           ; open space above
        LD      D,B
        DEC     D
        LD      E,C
        CALL    IS_BORDER_DE
        LD      D,A
        LD      A,(MZ_CURBORDER)
        CP      D
        JR      Z,MZN_UP_END            ; same structure -> fused, no line
MZN_UP_EXP:
        LD      A,%00001000
        CALL    MZ_SET_EXPOSED
MZN_UP_END:

        ; ---- down ----
        LD      A,B
        CP      MAZE_ROWS-1
        JR      Z,MZN_DN_EXP
        LD      A,(IX+SCR_COLS)
        CALL    IS_WALLCHAR
        JR      NZ,MZN_DN_EXP
        LD      D,B
        INC     D
        LD      E,C
        CALL    IS_BORDER_DE
        LD      D,A
        LD      A,(MZ_CURBORDER)
        CP      D
        JR      Z,MZN_DN_END
MZN_DN_EXP:
        LD      A,%00000100
        CALL    MZ_SET_EXPOSED
MZN_DN_END:

        ; ---- left ----
        LD      A,C
        OR      A
        JR      Z,MZN_LF_EXP
        LD      A,(IX-1)
        CALL    IS_WALLCHAR
        JR      NZ,MZN_LF_EXP
        LD      D,B
        LD      E,C
        DEC     E
        CALL    IS_BORDER_DE
        LD      D,A
        LD      A,(MZ_CURBORDER)
        CP      D
        JR      Z,MZN_LF_END
MZN_LF_EXP:
        LD      A,%00000010
        CALL    MZ_SET_EXPOSED
MZN_LF_END:

        ; ---- right ----
        LD      A,C
        CP      SCR_COLS-1
        JR      Z,MZN_RT_EXP
        LD      A,(IX+1)
        CALL    IS_WALLCHAR
        JR      NZ,MZN_RT_EXP
        LD      D,B
        LD      E,C
        INC     E
        CALL    IS_BORDER_DE
        LD      D,A
        LD      A,(MZ_CURBORDER)
        CP      D
        JR      Z,MZN_RT_END
MZN_RT_EXP:
        LD      A,%00000001
        CALL    MZ_SET_EXPOSED
MZN_RT_END:
        LD      A,(MZ_MASK)
        RET

; ======================================================================
; MZ_CALC_STUBS: pick the outline glyph for the wall cell the main loop
; is on. HL = destination pointer in MAZE_STATE, IX = MAZE_SRC pointer,
; B/C = row/col. Returns the glyph in A; HL, BC and IX are preserved.
;
; A stub toward a neighbour is needed when the outline actually runs
; from this cell into that one:
;   * both cells expose the same face (the line runs straight along it)
;   * or an open diagonal is wedged between two same-structure walls,
;     which is where the outline turns a reflex corner - that turn
;     lives in THIS cell, so it gets stubs toward both of them.
; ======================================================================
MZ_CALC_STUBS:
        PUSH    HL
        PUSH    BC
        XOR     A
        LD      (MZ_MASK),A
        LD      DE,EXP_OFFSET
        ADD     HL,DE                   ; HL -> EXP_BUF entry for this cell

        ; ---------------- left stub ----------------
        LD      A,(HL)
        AND     SIDE_L
        JR      NZ,MCS_L_END            ; left is not a same-structure wall
        LD      A,(HL)
        AND     SIDE_U
        JR      Z,MCS_L_TRYD
        DEC     HL
        LD      A,(HL)
        INC     HL
        AND     SIDE_U
        JR      NZ,MCS_L_SET
MCS_L_TRYD:
        LD      A,(HL)
        AND     SIDE_D
        JR      Z,MCS_L_END
        DEC     HL
        LD      A,(HL)
        INC     HL
        AND     SIDE_D
        JR      Z,MCS_L_END
MCS_L_SET:
        LD      A,SIDE_L
        CALL    MZ_SET_EXPOSED
MCS_L_END:

        ; ---------------- right stub ----------------
        LD      A,(HL)
        AND     SIDE_R
        JR      NZ,MCS_R_END
        LD      A,(HL)
        AND     SIDE_U
        JR      Z,MCS_R_TRYD
        INC     HL
        LD      A,(HL)
        DEC     HL
        AND     SIDE_U
        JR      NZ,MCS_R_SET
MCS_R_TRYD:
        LD      A,(HL)
        AND     SIDE_D
        JR      Z,MCS_R_END
        INC     HL
        LD      A,(HL)
        DEC     HL
        AND     SIDE_D
        JR      Z,MCS_R_END
MCS_R_SET:
        LD      A,SIDE_R
        CALL    MZ_SET_EXPOSED
MCS_R_END:

        ; ---------------- up stub ----------------
        LD      A,(HL)
        AND     SIDE_U
        JR      NZ,MCS_U_END
        LD      A,(HL)
        AND     SIDE_L
        JR      Z,MCS_U_TRYR
        LD      DE,-SCR_COLS
        ADD     HL,DE
        LD      A,(HL)
        LD      DE,SCR_COLS
        ADD     HL,DE
        AND     SIDE_L
        JR      NZ,MCS_U_SET
MCS_U_TRYR:
        LD      A,(HL)
        AND     SIDE_R
        JR      Z,MCS_U_END
        LD      DE,-SCR_COLS
        ADD     HL,DE
        LD      A,(HL)
        LD      DE,SCR_COLS
        ADD     HL,DE
        AND     SIDE_R
        JR      Z,MCS_U_END
MCS_U_SET:
        LD      A,SIDE_U
        CALL    MZ_SET_EXPOSED
MCS_U_END:

        ; ---------------- down stub ----------------
        LD      A,(HL)
        AND     SIDE_D
        JR      NZ,MCS_D_END
        LD      A,(HL)
        AND     SIDE_L
        JR      Z,MCS_D_TRYR
        LD      DE,SCR_COLS
        ADD     HL,DE
        LD      A,(HL)
        LD      DE,-SCR_COLS
        ADD     HL,DE
        AND     SIDE_L
        JR      NZ,MCS_D_SET
MCS_D_TRYR:
        LD      A,(HL)
        AND     SIDE_R
        JR      Z,MCS_D_END
        LD      DE,SCR_COLS
        ADD     HL,DE
        LD      A,(HL)
        LD      DE,-SCR_COLS
        ADD     HL,DE
        AND     SIDE_R
        JR      Z,MCS_D_END
MCS_D_SET:
        LD      A,SIDE_D
        CALL    MZ_SET_EXPOSED
MCS_D_END:

        ; ------------- reflex corners (open diagonals) -------------
        ; Only reached when both orthogonal neighbours are same-structure
        ; walls, which guarantees the diagonal is on-screen too.
        LD      A,(HL)
        AND     SIDE_D|SIDE_R
        JR      NZ,MCS_DR_END
        LD      A,(IX+SCR_COLS+1)
        CALL    IS_WALLCHAR
        JR      Z,MCS_DR_END
        LD      A,SIDE_D|SIDE_R
        CALL    MZ_SET_EXPOSED
MCS_DR_END:
        LD      A,(HL)
        AND     SIDE_D|SIDE_L
        JR      NZ,MCS_DL_END
        LD      A,(IX+SCR_COLS-1)
        CALL    IS_WALLCHAR
        JR      Z,MCS_DL_END
        LD      A,SIDE_D|SIDE_L
        CALL    MZ_SET_EXPOSED
MCS_DL_END:
        LD      A,(HL)
        AND     SIDE_U|SIDE_R
        JR      NZ,MCS_UR_END
        LD      A,(IX-SCR_COLS+1)
        CALL    IS_WALLCHAR
        JR      Z,MCS_UR_END
        LD      A,SIDE_U|SIDE_R
        CALL    MZ_SET_EXPOSED
MCS_UR_END:
        LD      A,(HL)
        AND     SIDE_U|SIDE_L
        JR      NZ,MCS_UL_END
        LD      A,(IX-SCR_COLS-1)
        CALL    IS_WALLCHAR
        JR      Z,MCS_UL_END
        LD      A,SIDE_U|SIDE_L
        CALL    MZ_SET_EXPOSED
MCS_UL_END:

        ; ---------------- resolve the glyph ----------------
        LD      A,(MZ_MASK)
        OR      A
        JR      NZ,MCS_LOOKUP
        ; no stubs: either a lone wall cell, or fully enclosed -> hollow
        LD      A,(HL)
        AND     %00001111
        LD      A,T_WALL_HOLLOW
        JR      Z,MCS_DONE
        LD      A,T_WALL_DOT
        JR      MCS_DONE
MCS_LOOKUP:
        PUSH    HL
        LD      HL,WALL_LUT
        LD      E,A
        LD      D,0
        ADD     HL,DE
        LD      A,(HL)
        POP     HL
MCS_DONE:
        POP     BC
        POP     HL
        RET

; ---- CHECK_WALKABLE: A=tile code -> Z flag set if walkable ----------
CHECK_WALKABLE:
        CP      T_SPACE
        RET     Z
        CP      T_DOT
        RET     Z
        CP      T_PILL
        RET     Z
        CP      'O'                     ; the cheat letter in FONY is
        RET     Z                       ; walkable/edible; F/N/Y stay solid
        RET

; ---- CELL_WALKABLE: B=row, C=col -> Z flag set if that cell is
; walkable. Handles the left/right tunnel row by treating columns
; -1 and 40 as valid (wraps to the far side).
CELL_WALKABLE:
        CALL    MAZE_PTR
        LD      A,(HL)
        JP      CHECK_WALKABLE

; ---- EAT_CELL: B=row, C=col -> A = tile that was there (T_DOT/T_PILL/
; T_SPACE); if it was a dot or pill, clears it in RAM+VRAM and (for
; dot/pill) decrements DOTS_LEFT (16-bit).
EAT_CELL:
        CALL    MAZE_PTR
        LD      A,(HL)
        CP      T_DOT
        JR      Z,EC_HIT
        CP      T_PILL
        JR      Z,EC_HIT
        RET                             ; nothing to eat
EC_HIT:
        PUSH    AF                      ; remember which tile was eaten
        LD      (HL),T_SPACE            ; clear RAM copy
        CALL    CELL_ADDR               ; B,C untouched by MAZE_PTR above
        LD      A,T_SPACE
        CALL    WRTVRM                  ; clear VRAM copy
        LD      HL,(DOTS_LEFT)
        DEC     HL
        LD      (DOTS_LEFT),HL
        POP     AF
        RET

; ---- CHEAT_TRIGGER: B=row, C=col of the just-eaten 'O' -> clears the
; dots on that half of the screen (left half if col<20, right half if
; col>=20, leaving exactly one dot behind on the right), decrements
; DOTS_LEFT to match, and awards half of the cleared dots' points
; (1 point/dot, so floor(count/2)). Also clears the 'O' cell itself so
; the trick can't be re-triggered by walking back over it.
CHEAT_TRIGGER:
        LD      (HL),T_SPACE            ; HL still points at the 'O' cell
                                         ; (set by EAT_CELL's MAZE_PTR call)
        CALL    CELL_ADDR
        LD      A,T_SPACE
        CALL    WRTVRM

        LD      A,C
        CP      20
        JR      C,CHEAT_CLEAR_LEFT
        JP      CHEAT_CLEAR_RIGHT

; ---- CHEAT_CLEAR_LEFT: clears every dot in columns 0..19 -------------
CHEAT_CLEAR_LEFT:
        LD      HL,0
        LD      (CC_COUNT),HL
        LD      A,MAZE_TOP
        LD      (CC_ROW),A
CCL_ROWLOOP:
        XOR     A
        LD      (CC_COL),A
CCL_COLLOOP:
        LD      A,(CC_ROW)
        LD      B,A
        LD      A,(CC_COL)
        LD      C,A
        CALL    MAZE_PTR
        LD      A,(HL)
        CP      T_DOT
        JR      NZ,CCL_NEXT
        LD      (HL),T_SPACE
        PUSH    BC
        CALL    CELL_ADDR
        LD      A,T_SPACE
        CALL    WRTVRM
        POP     BC
        LD      HL,(CC_COUNT)
        INC     HL
        LD      (CC_COUNT),HL
CCL_NEXT:
        LD      A,(CC_COL)
        INC     A
        LD      (CC_COL),A
        CP      20
        JR      NZ,CCL_COLLOOP
        LD      A,(CC_ROW)
        INC     A
        LD      (CC_ROW),A
        CP      MAZE_TOP+MAZE_ROWS
        JR      NZ,CCL_ROWLOOP
        JP      CHEAT_AWARD

; ---- CHEAT_CLEAR_RIGHT: clears every dot in columns 20..39, except
; the first one found (which is left behind) -------------------------
CHEAT_CLEAR_RIGHT:
        LD      HL,0
        LD      (CC_COUNT),HL
        XOR     A
        LD      (CC_SKIPPED),A
        LD      A,MAZE_TOP
        LD      (CC_ROW),A
CCR_ROWLOOP:
        LD      A,20
        LD      (CC_COL),A
CCR_COLLOOP:
        LD      A,(CC_ROW)
        LD      B,A
        LD      A,(CC_COL)
        LD      C,A
        CALL    MAZE_PTR
        LD      A,(HL)
        CP      T_DOT
        JR      NZ,CCR_NEXT
        LD      A,(CC_SKIPPED)
        OR      A
        JR      NZ,CCR_CLEAR
        LD      A,1
        LD      (CC_SKIPPED),A
        JR      CCR_NEXT                ; leave this one dot behind
CCR_CLEAR:
        LD      (HL),T_SPACE
        PUSH    BC
        CALL    CELL_ADDR
        LD      A,T_SPACE
        CALL    WRTVRM
        POP     BC
        LD      HL,(CC_COUNT)
        INC     HL
        LD      (CC_COUNT),HL
CCR_NEXT:
        LD      A,(CC_COL)
        INC     A
        LD      (CC_COL),A
        CP      SCR_COLS
        JR      NZ,CCR_COLLOOP
        LD      A,(CC_ROW)
        INC     A
        LD      (CC_ROW),A
        CP      MAZE_TOP+MAZE_ROWS
        JR      NZ,CCR_ROWLOOP
        ; fall through to CHEAT_AWARD

; ---- CHEAT_AWARD: DOTS_LEFT -= CC_COUNT; score += CC_COUNT/2 ---------
CHEAT_AWARD:
        LD      HL,(DOTS_LEFT)
        LD      DE,(CC_COUNT)
        OR      A
        SBC     HL,DE
        LD      (DOTS_LEFT),HL

        LD      HL,(CC_COUNT)
        SRL     H
        RR      L                       ; HL = CC_COUNT/2
        LD      A,H
        OR      L
        RET     Z                       ; nothing to award

        ; HL (0..~200) -> 2-digit packed BCD in A
        LD      A,L                     ; counts this small always fit in L
        LD      B,0
CA_TENS:
        CP      10
        JR      C,CA_DONE
        SUB     10
        INC     B
        JR      CA_TENS
CA_DONE:
        LD      C,A                     ; C=units
        LD      A,B
        RLCA
        RLCA
        RLCA
        RLCA                            ; A = tens<<4
        OR      C
        LD      E,A
        LD      D,0
        JP      ADD_SCORE_BCD

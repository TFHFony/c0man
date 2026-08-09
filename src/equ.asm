; ============================================================
; C0MAN  --  equ.asm
; BIOS routines, VDP registers, RAM layout, tile codes, constants
; ============================================================

; ---- BIOS entry points (Main-ROM, all MSX1) ----
CHSNS       EQU $009C       ; A=status of keyboard buffer (NZ=key waiting)
CHGET       EQU $009F       ; A=next char from keyboard buffer (blocking)
CHPUT       EQU $00A2       ; print char in A
BEEP        EQU $00C0       ; short beep
INITXT      EQU $006C       ; init SCREEN 0 / WIDTH 40
WRTVDP      EQU $0047       ; B=value, C=register -> write VDP register
RDVRM       EQU $004A       ; HL=vaddr -> A=byte
WRTVRM      EQU $004D       ; HL=vaddr, A=byte -> write
SETRD       EQU $0050       ; HL=vaddr -> setup VDP for sequential read
SETWRT      EQU $0053       ; HL=vaddr -> setup VDP for sequential write
FILVRM      EQU $0056       ; HL=vaddr, BC=len, A=value -> fill VRAM
LDIRVM      EQU $005C       ; HL=src(RAM), DE=vaddr, BC=len -> RAM to VRAM
LDIRMV      EQU $0059       ; HL=vaddr, DE=dst(RAM), BC=len -> VRAM to RAM
SNSMAT      EQU $0141       ; A=row -> A=key matrix row (bit=0 -> pressed)
GICINI      EQU $0090       ; init PSG
WRTPSG      EQU $0093       ; A=register, E=value -> write PSG register
RDPSG       EQU $0096       ; A=register -> A=value

VDP_DATA    EQU $98         ; VDP data port
VDP_CMD     EQU $99         ; VDP command/status port

; ---- BIOS system variables we read (auto-refreshed by BIOS each VBlank) ----
NEWKEY      EQU $FBE5       ; 11-byte debounced key matrix table, row N at NEWKEY+N
JIFFY       EQU $FC9E       ; 16-bit VBlank counter, incremented by BIOS
CLIKSW      EQU $F3DB       ; keyclick switch: 0=off, nonzero=on (BIOS default is on)

; ---- Keyboard matrix row 8 (cursors + space), bit=0 means pressed ----
KEYROW_CURSOR EQU 8
KB_RIGHT    EQU %10000000
KB_DOWN     EQU %01000000
KB_UP       EQU %00100000
KB_LEFT     EQU %00010000
KB_SPACE    EQU %00000001

; ============================================================
; Screen layout (SCREEN 0, WIDTH 40, 24 rows)
; ============================================================
SCR_COLS    EQU 40
SCR_ROWS    EQU 24
HUD_ROW     EQU 0            ; score / high score / level / lives
MAZE_TOP    EQU 1            ; first maze row on screen
MAZE_ROWS   EQU 22           ; rows 1..22
MSG_ROW     EQU 23           ; bottom message/prompt row

NAMTBL      EQU $0000        ; text name table base (set by INITXT)
PATGEN      EQU $0800        ; pattern generator table base (set by INITXT)

; ============================================================
; Tile / character codes (native MSX/CP437 font unless noted CUSTOM)
; ============================================================
; NOTE: verified empirically (rendering test boxes in openMSX and
; reading the actual VRAM pattern-generator bytes) that this BIOS's
; international font keeps a genuine single-line box-drawing set at
; codes 16-27 (NOT in the 176-223 CP437-style range, which this font
; does not use for that purpose). These connect edge-to-edge cleanly:
; 22=| 23=- 24=TL 25=TR 26=BL 27=BR, plus 16=cross 17=tee-D 18=tee-U
; 19=tee-L 20=tee-R. T_PILL=9 (a hollow ring) and T_DOT='.' were
; confirmed separately; T_PILL is still a custom glyph (see below).
T_SPACE     EQU 32           ; empty corridor
T_DOT       EQU 7             ; custom: small centred dot (kept off code 46/'.'
                               ; so the title screen's own literal '.' keeps
                               ; the default font glyph)
T_PILL      EQU 14           ; power pill (CUSTOM glyph, see charset.asm -
                              ; the built-in code 9 "ring" turned out to be
                              ; authored full-8-bit-wide and gets its right
                              ; edge clipped off in WIDTH40's 6-pixel cells)

; wall pieces: plain single-line box-drawing glyphs (verified on-screen).
; Walls are drawn as OUTLINES: only the faces of a wall cell that touch
; open space get a line, and a wall cell with no open neighbour at all
; is left hollow (T_WALL_HOLLOW) so thick blocks read as empty rooms
; instead of a cross-hatched raster.
T_WALL_HOLLOW EQU 0           ; blank glyph (verified all-zero pattern) used
                               ; for wall cells fully enclosed by other walls.
                               ; NOT equal to T_SPACE, so CHECK_WALKABLE still
                               ; treats it as solid - it only looks empty.
T_WALL_DOT  EQU 6             ; custom: small box, for an isolated wall cell
; custom "capped end" glyphs for a wall run that truly dead-ends (only
; one stub) - a plain H/V there looked like the line was just cut off,
; so these close it off with a small perpendicular tick (like "----]").
; Aligned to the same row/col as the verified built-in V(22)/H(23).
T_WALL_CAP_R EQU 8            ; stub=right only (dead end on the left)
T_WALL_CAP_L EQU 9            ; stub=left only  (dead end on the right)
T_WALL_CAP_D EQU 10           ; stub=down only  (dead end on top)
T_WALL_CAP_U EQU 15           ; stub=up only    (dead end on the bottom)
T_WALL_V    EQU 22            ; |
T_WALL_H    EQU 23            ; -
T_WALL_TL   EQU 24            ; top-left corner
T_WALL_TR   EQU 25            ; top-right corner
T_WALL_BL   EQU 26            ; bottom-left corner
T_WALL_BR   EQU 27            ; bottom-right corner
; NOTE: verified with a dedicated on-screen test (codes 16-20 rendered
; individually and zoomed in) that 17/18 and 19/20 were swapped from
; what an earlier, less rigorous check assumed - this is the corrected,
; confirmed mapping.
T_WALL_TEE_R EQU 19           ; T opening right (connects U+D+R)
T_WALL_TEE_L EQU 20           ; T opening left  (connects U+D+L)
T_WALL_TEE_D EQU 18           ; T opening down  (connects D+L+R)
T_WALL_TEE_U EQU 17           ; T opening up    (connects U+L+R)
T_WALL_CROSS EQU 16           ; four-way cross
T_WALL_BLOCK EQU 35           ; # (ghost-pen walls - deliberately heavier)
T_SOLID_BLOCK EQU 219         ; genuine fully-filled 8x8 glyph (verified via
                               ; VRAM dump - every row is 11111111), used for
                               ; the maze's solid interior obstacle blocks

; custom tiles (patterns redefined at init, codes 1-6 and 11-13 are
; otherwise-unused CP437 control-picture slots -> safe to overwrite,
; we never PRINT them through BIOS text routines, only poke the
; name table directly)
T_PAC_CLOSED  EQU 1
T_PAC_OPEN_R  EQU 2
T_PAC_OPEN_L  EQU 3
T_PAC_OPEN_U  EQU 4
T_PAC_OPEN_D  EQU 5
T_GHOST_BODY  EQU 11
T_GHOST_SCARED EQU 12
T_GHOST_EYES  EQU 13
; (T_PILL, defined above as 14, is also a custom glyph loaded by
; LOAD_CHARSET together with the ghost frames)

; ============================================================
; Directions
; ============================================================
DIR_NONE    EQU 0
DIR_RIGHT   EQU 1
DIR_LEFT    EQU 2
DIR_UP      EQU 3
DIR_DOWN    EQU 4

; ============================================================
; Game states
; ============================================================
GS_INTRO    EQU 0
GS_TITLE    EQU 1
GS_PLAYING  EQU 2
GS_DYING    EQU 3
GS_GAMEOVER EQU 4
GS_HISCORE  EQU 5
GS_LEVELINTRO EQU 6

; ============================================================
; Ghost states
; ============================================================
GHST_PEN       EQU 0
GHST_CHASE     EQU 1
GHST_FRIGHT    EQU 2
GHST_EATEN     EQU 3

NUM_GHOSTS  EQU 4
FRIGHT_FRAMES EQU 500        ; ~10 sec at 50Hz (PAL); good enough on NTSC too

; ============================================================
; RAM layout (system RAM, well within a 16KB-RAM MSX1)
; All addresses below are plain EQU literals (no ORG!) so that
; including this file never shifts the assembler's output address
; for the ROM code that follows it.
; ============================================================

; ---- maze state: 1 byte per cell, row-major, full screen 40x24 so
; that "row" is always the absolute screen row (0-23) everywhere -
; rows 0 (HUD) and 23 (message) are allocated but never used for
; collision. Real maze data lives at rows MAZE_TOP..MAZE_TOP+MAZE_ROWS-1.
MAZE_STATE  EQU $E000        ; 960 bytes ($E000-$E3BF)
MAZE_SIZE   EQU SCR_COLS*MAZE_ROWS     ; number of real (parsed) cells

; ---- player ----
PAC_COL     EQU $E3C0
PAC_ROW     EQU $E3C1
PAC_START_COL EQU $E4F0      ; maze start cell, set once by MAZE_INIT,
PAC_START_ROW EQU $E4F1      ; used by PAC_RESET to respawn correctly
PAC_DIR     EQU $E3C2        ; current movement direction
PAC_NEXTDIR EQU $E3C3        ; queued direction (from input)
PAC_ANIM    EQU $E3C4        ; animation frame toggle
PAC_MOVETMR EQU $E3C5        ; frames until next cell-step
PAC_MOVESPD EQU $E3C6        ; frames per cell-step (lower = faster)

; ---- ghosts: 8 bytes each x 4 ----
; +0 col, +1 row, +2 dir, +3 state, +4 movetmr, +5 movespd, +6 frighttmr, +7 scatter-target-index
GHOST_BASE  EQU $E3C7
GHOST_STRIDE EQU 8

; ---- score / lives / level ----
SCORE_BCD   EQU $E3E7        ; 3 bytes packed BCD (6 digits)
LIVES       EQU $E3EA
LEVEL       EQU $E3EB
DOTS_LEFT   EQU $E3EC        ; 2 bytes (16-bit), dots+pills remaining
GAME_STATE  EQU $E3EE
EAT_COMBO   EQU $E3EF        ; ghost-eat streak index 0..3 (10/25/50/100)
RNG_SEED    EQU $E3F0        ; 1 byte LFSR seed
INPUT_ROW8  EQU $E3F2        ; last read of keyboard row 8

; ---- high score table: 10 x (3 name + 3 BCD score) ----
HISCORE_TBL EQU $E400        ; 60 bytes
HISCORE_ENTRIES EQU 10
HISCORE_STRIDE EQU 6

; ---- ghost-AI scratch (GHOST_CHOOSE_DIR working set) ----
GC_TARGET_ROW EQU $E43C
GC_TARGET_COL EQU $E43D
GC_MODE     EQU $E43E         ; 1=minimize dist to target (chase/eaten), 0=maximize (fright)
GC_REVERSE  EQU $E43F         ; direction opposite of current (avoid unless dead end)
GC_EXCLFLAG EQU $E440
GC_CANDS    EQU $E441         ; up to 4 valid directions found this scan
GC_CANDCOUNT EQU $E445
GC_PREF_V   EQU $E446
GC_PREF_H   EQU $E447
GC_CHOSEN   EQU $E448
GC_CANDDIR_TMP EQU $E44C

FRIGHT_TIMER EQU $E449        ; 2 bytes, global countdown while any ghost is scared
GHOST_SPEED EQU $E44B         ; frames-per-cell applied to ghosts on release/level start

; ---- HUD scratch ----
TXT_BUF     EQU $E44D         ; 16 bytes, shared scratch text buffer
DLV_COUNT   EQU $E45D
DLV_IDX     EQU $E45E

; ---- high-score name entry scratch ----
NAME_BUF    EQU $E45F         ; 3 bytes
NAME_LEN    EQU $E462
HDL_IDX     EQU $E463

; ---- sound ----
SND_TIMER   EQU $E464         ; frames remaining for the current bleep
SND_VOL     EQU $E465
SND_DOT     EQU 0
SND_PILL    EQU 1
SND_GHOST   EQU 2
SND_LIFE    EQU 3
SND_GAMEOVER EQU 4

; ---- intro/title scratch ----
INTRO_ROW   EQU $E466
INTRO_TIMER EQU $E467
INTRO_PHASE EQU $E468

; ---- misc state-machine pause timer (DYING and GAMEOVER, mutually
; exclusive in time so they can share one counter) ----
DYING_TIMER EQU $E469

; ---- name-entry keyboard-matrix edge detection (rows 2,3,4,5=letters,
; 7=enter/backspace); PREV_* holds last frame's raw row value so we
; can detect "just pressed" instead of repeating every frame the key
; is held. This bypasses the BIOS keyboard *buffer* (CHGET/CHSNS)
; entirely and reads the same raw NEWKEY matrix table that the
; cursor-key movement code already uses successfully. ------------------
PREV_ROW2   EQU $E46A
PREV_ROW3   EQU $E46B
PREV_ROW4   EQU $E46C
PREV_ROW5   EQU $E46D
PREV_ROW7   EQU $E46E
RNK_E2      EQU $E46F
RNK_E3      EQU $E470
RNK_E4      EQU $E471
RNK_E5      EQU $E472
RNK_E7      EQU $E473

; ---- maze auto-tiling scratch ----
MZ_MASK      EQU $E474        ; mask being accumulated (exposed sides / stubs)
MZ_CURBORDER EQU $E475        ; 1 if the cell being tiled is on the outer border

; Per-cell "which sides are exposed" table, filled by a first pass over
; MAZE_SRC so the second pass can look up its neighbours' exposure
; instead of recomputing it. 880 bytes, one per maze cell.
EXP_BUF      EQU $E500
EXP_OFFSET   EQU EXP_BUF - (MAZE_STATE + (MAZE_TOP*SCR_COLS))

; side bits shared by both masks
SIDE_U      EQU %00001000
SIDE_D      EQU %00000100
SIDE_L      EQU %00000010
SIDE_R      EQU %00000001

; ---- FONY "cheat" scratch (CHEAT_CLEAR_LEFT/RIGHT working set) -------
CC_ROW      EQU $E850
CC_COL      EQU $E851
CC_COUNT    EQU $E852        ; 2 bytes
CC_SKIPPED  EQU $E854

; ---- high-score insert scratch (HISCORE_INSERT working set) ---------
HINS_IDX    EQU $E855        ; insertion index (0..9), found in phase 1
HSHIFT_I    EQU $E856        ; shift-loop counter (phase 2)

STACK_TOP   EQU $F380

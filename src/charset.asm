; ============================================================
; C0MAN  --  charset.asm
; Custom 8x8 character bitmaps (only the top 6 bits of each row
; byte are visible in SCREEN 0 WIDTH 40 - the bottom 2 bits are
; the inter-character gap and are always left clear).
; Order here must match LOAD_CHARSET in vdp.asm:
;   5x Pac-Man frames (closed, open-R, open-L, open-U, open-D)
;   3x ghost frames (body, scared=inverted body, eyes-only)
; ============================================================

CHARSET_DATA:
; --- T_PAC_CLOSED (user-specified exact pattern, narrower) ---
        DB      %00000000
        DB      %01110000
        DB      %10001000
        DB      %10001000
        DB      %10001000
        DB      %10001000
        DB      %01110000
        DB      %00000000

; --- T_PAC_OPEN_R (user-specified exact pattern) ---
        DB      %00000000
        DB      %00110000
        DB      %01001000
        DB      %10000000
        DB      %10000000
        DB      %01001000
        DB      %00110000
        DB      %00000000

; --- T_PAC_OPEN_L (user-specified exact pattern) ---
        DB      %00000000
        DB      %00110000
        DB      %01001000
        DB      %00000100
        DB      %00000100
        DB      %01001000
        DB      %00110000
        DB      %00000000

; --- T_PAC_OPEN_U (user-specified exact pattern) ---
        DB      %00000000
        DB      %00000000
        DB      %01001000
        DB      %10000100
        DB      %10000100
        DB      %01001000
        DB      %00110000
        DB      %00000000

; --- T_PAC_OPEN_D (user-specified exact pattern) ---
        DB      %00000000
        DB      %00110000
        DB      %01001000
        DB      %10000100
        DB      %10000100
        DB      %01001000
        DB      %00000000
        DB      %00000000

; --- T_GHOST_BODY (dome top, wavy 3-leg bottom, with eyes) ---
        DB      %01111000
        DB      %11111100
        DB      %10110100       ; eyes (two 1px gaps in the filled body)
        DB      %11111100
        DB      %11111100
        DB      %11111100
        DB      %11111100
        DB      %10110100

; --- T_GHOST_SCARED (frightened - outline only, not inverted, so it
;     stays readable at this resolution; also has eyes) ---
        DB      %01111000
        DB      %10000100
        DB      %11001100       ; sides + eyes
        DB      %10000100
        DB      %10000100
        DB      %10000100
        DB      %10000100
        DB      %10110100

; --- T_GHOST_EYES (eaten - eyes only, scurrying back to the pen) ---
        DB      %00000000
        DB      %00000000
        DB      %01001000
        DB      %01001000
        DB      %00000000
        DB      %00000000
        DB      %00000000
        DB      %00000000

; --- T_PILL (power pill - a small filled circle, vertically centred so
;     it reads clearly as "bigger than a dot" at this resolution) ---
        DB      %00000000
        DB      %01111000
        DB      %11111100
        DB      %11111100
        DB      %11111100
        DB      %11111100
        DB      %01111000
        DB      %00000000

; --- T_WALL_DOT (small hollow box, for a wall cell that stands alone
;     with open space on all four sides) ---
        DB      %00000000
        DB      %00000000
        DB      %01111000
        DB      %01001000
        DB      %01001000
        DB      %01111000
        DB      %00000000
        DB      %00000000

; --- T_WALL_CAP_R/L/D/U: dead-end "cap" glyphs. A single-stub wall
;     cell used to just draw a plain H or V line that looked cut off
;     mid-air; these close it off with a short perpendicular tick,
;     e.g. "----]". Aligned to the SAME row3/col3 anchor verified
;     against the built-in T_WALL_V(22)/T_WALL_H(23)/corners(24-27)
;     via a VRAM dump (line sits at visible col3 for V, row3 for H).

; T_WALL_CAP_R (stub=right only; dead end on the left, capped with a
; vertical tick at col3, line continuing right from col3) ---
        DB      %00000000
        DB      %00000000
        DB      %00010000
        DB      %00011100
        DB      %00010000
        DB      %00000000
        DB      %00000000
        DB      %00000000

; T_WALL_CAP_L (stub=left only; dead end on the right, mirror of CAP_R) ---
        DB      %00000000
        DB      %00000000
        DB      %00010000
        DB      %11110000
        DB      %00010000
        DB      %00000000
        DB      %00000000
        DB      %00000000

; T_WALL_CAP_D (stub=down only; dead end on top, capped with a
; horizontal tick at row3, line continuing down from row3) ---
        DB      %00000000
        DB      %00000000
        DB      %00000000
        DB      %01110000
        DB      %00010000
        DB      %00010000
        DB      %00010000
        DB      %00010000

; T_WALL_CAP_U (stub=up only; dead end on the bottom, mirror of CAP_D) ---
        DB      %00010000
        DB      %00010000
        DB      %00010000
        DB      %00010000
        DB      %01110000
        DB      %00000000
        DB      %00000000
        DB      %00000000

; --- T_DOT (custom glyph, code 7 - NOT the built-in '.' at code 46,
;     which stays untouched so the title screen text keeps the normal
;     period glyph): a small 2x2 block centred on the same row3/col3
;     anchor used above. ---
        DB      %00000000
        DB      %00000000
        DB      %00000000
        DB      %00110000
        DB      %00110000
        DB      %00000000
        DB      %00000000
        DB      %00000000

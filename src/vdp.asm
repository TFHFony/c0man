; ============================================================
; C0MAN  --  vdp.asm
; Low level screen/VRAM helpers, random number, vblank sync
; ============================================================

; ---- MUL40: B=row(0..23) -> HL = row*40 -----------------------------
MUL40:
        LD      H,0
        LD      L,B
        ADD     HL,HL           ; *2
        ADD     HL,HL           ; *4
        ADD     HL,HL           ; *8
        LD      D,H
        LD      E,L             ; DE = row*8
        ADD     HL,HL           ; *16
        ADD     HL,HL           ; *32
        ADD     HL,DE           ; HL = row*32 + row*8 = row*40
        RET

; ---- CELL_ADDR: B=row, C=col -> HL = VRAM name-table address --------
CELL_ADDR:
        CALL    MUL40
        LD      A,C
        ADD     A,L
        LD      L,A
        LD      A,0
        ADC     A,H
        LD      H,A
        RET

; ---- MAZE_PTR: B=row, C=col -> HL = RAM pointer into MAZE_STATE -----
MAZE_PTR:
        CALL    MUL40
        LD      A,C
        ADD     A,L
        LD      L,A
        LD      A,0
        ADC     A,H
        LD      H,A
        LD      DE,MAZE_STATE
        ADD     HL,DE
        RET

; ---- PUT_TILE: B=row, C=col, A=tile -> write tile into name table ---
PUT_TILE:
        PUSH    AF
        CALL    CELL_ADDR
        POP     AF
        CALL    WRTVRM
        RET

; ---- PUT_TILE_HL: HL already = vram addr, A = tile ------------------
PUT_TILE_HL:
        CALL    WRTVRM
        RET

; ---- PRINT_AT: B=row, C=col, HL=ptr to 0-terminated string ----------
; Prints raw bytes (already tile codes / ASCII) until a 0 byte.
PRINT_AT:
        PUSH    HL
        CALL    CELL_ADDR
        CALL    SETWRT
        POP     HL
PRINT_AT_LOOP:
        LD      A,(HL)
        OR      A
        RET     Z
        OUT     (VDP_DATA),A
        INC     HL
        JR      PRINT_AT_LOOP

; ---- LOAD_CHARSET: copy custom character patterns into PATGEN -------
LOAD_CHARSET:
        LD      HL,CHARSET_DATA
        LD      DE,PATGEN + (T_PAC_CLOSED*8)
        LD      BC,5*8          ; 5 pacman frames, contiguous codes 1..5
        CALL    LDIRVM
        LD      HL,CHARSET_DATA + (5*8)
        LD      DE,PATGEN + (T_GHOST_BODY*8)
        LD      BC,3*8          ; ghost body / scared / eyes, contiguous 11..13
        CALL    LDIRVM
        LD      HL,CHARSET_DATA + (8*8)
        LD      DE,PATGEN + (T_PILL*8)
        LD      BC,1*8          ; power pill, code 14
        CALL    LDIRVM
        LD      HL,CHARSET_DATA + (9*8)
        LD      DE,PATGEN + (T_WALL_DOT*8)
        LD      BC,1*8          ; isolated-wall-cell box, code 6
        CALL    LDIRVM
        LD      HL,CHARSET_DATA + (10*8)
        LD      DE,PATGEN + (T_WALL_CAP_R*8)
        LD      BC,1*8          ; dead-end cap, code 8
        CALL    LDIRVM
        LD      HL,CHARSET_DATA + (11*8)
        LD      DE,PATGEN + (T_WALL_CAP_L*8)
        LD      BC,1*8          ; dead-end cap, code 9
        CALL    LDIRVM
        LD      HL,CHARSET_DATA + (12*8)
        LD      DE,PATGEN + (T_WALL_CAP_D*8)
        LD      BC,1*8          ; dead-end cap, code 10
        CALL    LDIRVM
        LD      HL,CHARSET_DATA + (13*8)
        LD      DE,PATGEN + (T_WALL_CAP_U*8)
        LD      BC,1*8          ; dead-end cap, code 15
        CALL    LDIRVM
        LD      HL,CHARSET_DATA + (14*8)
        LD      DE,PATGEN + (T_DOT*8)
        LD      BC,1*8          ; centred dot glyph, code 7 (unused slot)
        CALL    LDIRVM
        RET

; ---- CLEAR_MAZE_AREA: fill name table rows MAZE_TOP..MSG_ROW-1 with space
CLEAR_SCREEN:
        LD      HL,NAMTBL
        LD      BC,SCR_COLS*SCR_ROWS
        LD      A,T_SPACE
        CALL    FILVRM
        RET

; ---- WAIT_VBLANK: waits for the BIOS's JIFFY counter to tick over.
; (A first version patched the H.TIMI BIOS hook, but that hook never
; fired on this system. A second version polled the VDP status
; register (S#0 bit7) directly instead - that worked as long as
; interrupts stayed off, but this game keeps interrupts enabled with
; EI so the BIOS's own periodic keyboard scan keeps NEWKEY fresh, and
; on real-BIOS machines (confirmed on a Panasonic FS-A1GT, a Turbo-R)
; the BIOS's own interrupt handler reads/clears that same status bit
; on every VBlank as part of its normal housekeeping - a race our own
; poll consistently lost, hanging forever with the flag already
; cleared before we ever saw it set. JIFFY sidesteps the race
; entirely: it's a RAM counter the BIOS's interrupt handler itself
; increments every VBlank, so watching it change works regardless of
; who else is also consuming the hardware status flag.)
WAIT_VBLANK:
        LD      A,(JIFFY)
        LD      B,A
WV_SPIN:
        LD      A,(JIFFY)
        CP      B
        JR      Z,WV_SPIN
        RET

; ---- READ_ROW8: reads keyboard matrix row 8 (cursors+space) into A --
READ_ROW8:
        LD      A,(NEWKEY+KEYROW_CURSOR)
        LD      (INPUT_ROW8),A
        RET

; ---- RANDOM: 8-bit Galois LFSR, returns pseudo-random byte in A ------
; taps = $B8 (maximal length, period 255); the all-zero state is a
; lock so it is kicked back to 1 if ever reached.
RANDOM:
        LD      A,(RNG_SEED)
        OR      A
        JR      NZ,RANDOM_NZ
        LD      A,1
RANDOM_NZ:
        SRL     A
        JR      NC,RANDOM_NOXOR
        XOR     $B8
RANDOM_NOXOR:
        LD      (RNG_SEED),A
        RET

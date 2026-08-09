; ============================================================
; C0MAN  --  main.asm
; MSX1 ROM header, boot init, VBlank hook, game state dispatch
; ============================================================

    ORG $4000
    DB  "AB"
    DW  INIT
    DW  0,0,0,0,0,0

    INCLUDE "equ.asm"

; ============================================================
INIT:
        DI
        LD      SP,STACK_TOP
        CALL    INITXT                  ; SCREEN 0, WIDTH 40

        XOR     A
        LD      (CLIKSW),A              ; keyclick off - it would otherwise
                                         ; hit the PSG independently of our
                                         ; own sound code, every keypress

        LD      B,$21                   ; COLOR 2,1,1 (fg green, bg/border black)
        LD      C,7
        CALL    WRTVDP

        CALL    LOAD_CHARSET
        CALL    HISCORE_INIT
        CALL    SOUND_INIT

        EI                              ; keeps the BIOS's own periodic
                                         ; keyboard scan (-> NEWKEY) alive;
                                         ; our own frame sync polls the VDP
                                         ; status port directly (see WAIT_VBLANK)

        LD      A,GS_INTRO
        LD      (GAME_STATE),A
        CALL    INTRO_INIT

; ---- MAIN_LOOP: one iteration per VBlank -----------------------------
MAIN_LOOP:
        CALL    WAIT_VBLANK
        CALL    SOUND_UPDATE            ; every frame, regardless of game
                                         ; state, so a bleep's duration timer
                                         ; always runs down and silences the
                                         ; PSG - previously only ticked during
                                         ; GS_PLAYING, so e.g. the death jingle
                                         ; would drone on forever once the
                                         ; state left GS_PLAYING
        LD      A,(GAME_STATE)

        CP      GS_INTRO
        JR      NZ,ML_1
        CALL    INTRO_UPDATE
        JR      MAIN_LOOP
ML_1:
        CP      GS_TITLE
        JR      NZ,ML_2
        CALL    TITLE_UPDATE
        JR      MAIN_LOOP
ML_2:
        CP      GS_PLAYING
        JR      NZ,ML_2B
        CALL    PLAYING_UPDATE
        JR      MAIN_LOOP
ML_2B:
        CP      GS_LEVELINTRO
        JR      NZ,ML_3
        CALL    LEVELINTRO_UPDATE
        JR      MAIN_LOOP
ML_3:
        CP      GS_DYING
        JR      NZ,ML_4
        CALL    DYING_UPDATE
        JR      MAIN_LOOP
ML_4:
        CP      GS_GAMEOVER
        JR      NZ,ML_5
        CALL    GAMEOVER_UPDATE
        JR      MAIN_LOOP
ML_5:
        CP      GS_HISCORE
        JR      NZ,MAIN_LOOP
        CALL    HISCORE_ENTRY_UPDATE
        JR      MAIN_LOOP

; ============================================================
; GS_PLAYING
; ============================================================
PLAYING_UPDATE:
        CALL    PAC_UPDATE
        CALL    PAC_DRAW
        CALL    FRIGHT_TICK
        CALL    GHOST_UPDATE_ALL

        LD      A,(GAME_STATE)
        CP      GS_PLAYING
        RET     NZ                      ; a life was lost this frame

        LD      HL,(DOTS_LEFT)
        LD      A,H
        OR      L
        RET     NZ

        CALL    NEXT_LEVEL
        LD      A,GS_LEVELINTRO
        LD      (GAME_STATE),A
        JP      LEVELINTRO_INIT

; ---- LEVEL_START: fresh maze + reset actors + full HUD redraw --------
LEVEL_START:
        CALL    MAZE_INIT
        CALL    PAC_RESET
        CALL    GHOST_INIT
        CALL    HUD_INIT
        CALL    DRAW_SCORE
        CALL    DRAW_HIGHSCORE
        CALL    DRAW_LEVEL
        CALL    DRAW_LIVES
        CALL    GHOST_DRAW_ALL
        JP      PAC_DRAW

; ============================================================
; GS_LEVELINTRO - brief "LEVEL XX" screen shown between levels
; ============================================================
LEVELINTRO_TEXT: DB "LEVEL ",0

LEVELINTRO_INIT:
        CALL    CLEAR_SCREEN
        LD      HL,LEVELINTRO_TEXT
        LD      B,11
        LD      C,16
        CALL    PRINT_AT

        LD      A,(LEVEL)
        LD      B,0
LI_TENS:
        CP      10
        JR      C,LI_DONE
        SUB     10
        INC     B
        JR      LI_TENS
LI_DONE:
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
        LD      B,11
        LD      C,22
        CALL    PRINT_AT

        LD      A,90
        LD      (DYING_TIMER),A
        RET

LEVELINTRO_UPDATE:
        LD      A,(DYING_TIMER)
        DEC     A
        LD      (DYING_TIMER),A
        RET     NZ

        LD      A,GS_PLAYING
        LD      (GAME_STATE),A
        JP      LEVEL_START

; ============================================================
; GS_DYING - brief pause after the player is caught, then respawn
; ============================================================
DYING_UPDATE:
        LD      A,(DYING_TIMER)
        OR      A
        JR      NZ,DY_TICK
        LD      A,60
        LD      (DYING_TIMER),A
        RET
DY_TICK:
        DEC     A
        LD      (DYING_TIMER),A
        RET     NZ

        CALL    PAC_ERASE               ; wipe actors from their old spots
        CALL    GHOST_ERASE_ALL         ; BEFORE repositioning them
        CALL    PAC_RESET
        CALL    GHOST_INIT
        CALL    GHOST_DRAW_ALL
        CALL    PAC_DRAW
        LD      A,GS_PLAYING
        LD      (GAME_STATE),A
        RET

; ============================================================
; GS_GAMEOVER
; ============================================================
GAMEOVER_TEXT: DB "GAME OVER",0

GAMEOVER_UPDATE:
        LD      A,(DYING_TIMER)
        OR      A
        JR      NZ,GO_TICK
        LD      A,90
        LD      (DYING_TIMER),A
        LD      HL,GAMEOVER_TEXT
        LD      B,MSG_ROW
        LD      C,15
        JP      PRINT_AT
GO_TICK:
        DEC     A
        LD      (DYING_TIMER),A
        RET     NZ

        ; (no need to clear "GAME OVER" here - both HISCORE_ENTRY_INIT
        ; and TITLE_INIT below start with CLEAR_SCREEN)
        CALL    HISCORE_QUALIFIES
        OR      A
        JR      Z,GO_NOTQUALIFY
        LD      A,GS_HISCORE
        LD      (GAME_STATE),A
        JP      HISCORE_ENTRY_INIT
GO_NOTQUALIFY:
        LD      A,GS_TITLE
        LD      (GAME_STATE),A
        JP      TITLE_INIT

; ============================================================
; module includes
; ============================================================
    INCLUDE "vdp.asm"
    INCLUDE "charset.asm"
    INCLUDE "maze.asm"
    INCLUDE "input.asm"
    INCLUDE "pacman.asm"
    INCLUDE "ghosts.asm"
    INCLUDE "score.asm"
    INCLUDE "highscore.asm"
    INCLUDE "sound.asm"
    INCLUDE "intro.asm"

    DEFS $8000-$,0

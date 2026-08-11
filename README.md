# C0MAN

A Pac-Man-style game for unexpanded MSX1, running entirely in SCREEN 0
(WIDTH 40) — no sprites, no per-cell color, just redefined text
characters. Plain 16KB ROM cartridge, no mapper.

▶ **[Play it online](https://www.file-hunter.com/Homebrew/?id=c0man)**

## Screenshots

| Title screen | Fresh game | Mid-game |
|---|---|---|
| ![Title screen](assets/title-screen.png) | ![Gameplay](assets/gameplay-start.png) | ![Gameplay](assets/gameplay-cheat.png) |

## Building

Requires [sjasmplus](https://github.com/z00m128/sjasmplus). From the
project root:

```
build.bat
```

produces `c0man.rom`.

## Credits

This project is an experiment in human/AI collaboration between
**Arnaud de Klerk** and **Claude** (Anthropic) — the whole game, from
first line of code to the final build, was written in a few hours.

Do not expect a refined game. It's very BASIC, but it works. There
might even be a bug or two. I've tested quite a lot, but not
everything.
The actual code is something like 5KBytes.

Have fun!

https://www.arnauddeklerk.com
https://www.file-hunter.com

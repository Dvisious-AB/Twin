# Screenshots

App Store-screenshots enligt beskrivningen i huvud-README (Mac: 1280x800
eller 2880x1800), i ordning:

1. `01-dual-pane.png` — Dual-pane översikt
2. `02-drag-drop.png` — Drag-and-drop med drop-highlight + progress
3. `03-icon-quicklook.png` — Icon view + Quick Look (Space)
4. `04-search.png` — Instant search i filterfältet
5. `05-finder.png` — Finder med Twin View / Open in Twin

## Status: BLOCKERAD av macOS TCC (2026-10-23)

Appen kör bevisligen (fönster hittat via CGWindowList, 900x652), men den här
agent-sessionen får inte fånga skärmen:

- `screencapture` -> "could not create image from display/window"
- ScreenCaptureKit -> "The user declined TCCs for application, window, display capture"
- AppleScript/UI-skript -> "osascript is not allowed assistive access" (-1719)

Åtgärd (engångs, av användaren): Systeminställningar > Integritet och
säkerhet > Skärminspelning (och Hjälpmedel) — aktivera för terminalen/Muse.
Kör sedan `./Scripts/screenshots.sh` mot den körande appen; skriptet guidar
igenom alla fem motiven.

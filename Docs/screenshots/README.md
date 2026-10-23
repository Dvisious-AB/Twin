# Screenshots

App Store-screenshots enligt beskrivningen i huvud-README (Mac: 1280x800
eller 2880x1800), i ordning:

1. `01-dual-pane.png` — Dual-pane översikt ✅ (1800x1304, riktiga mappar)
2. `02-copy-progress.png` — F5-kopiering med progress ✅
3. `03-icon-view.png` — Icon view ✅
4. `04-search.png` — Instant filter i höger panel ✅
5. `05-finder.png` — Finder med Twin View / Open in Twin ⏳ manuell

## Status 2026-10-23

Fyra av fem motiv fångade på riktigt ur den körande appen efter att
användaren slagit på Skärminspelning. Kvar:

- **05-finder**: FinderSync-tillägget är nu registrerat och aktiverat
  (`pluginkit -e use -i se.dvisious.twin.findersync`), men verktygsfälts-
  knappen kräver Customize Toolbar i Finder och högerklicksmenyn går inte
  att träffa syntetiskt över Spaces. Tas manuellt: högerklicka en mapp
  under /Users i Finder → "Open in Twin".
- **Quick Look** i motiv 03: QL-panelen renderas av QuickLookUIService i
  eget fönster och gick inte att komponera in syntetiskt; motivet visar
  därför bara ikonvyn.

Upptäckt under tagningen (fixad): bakgrundsberäkning av katalogstorlekar
triggar macOS TCC-dialoger (Music/Desktop/Photos) när hemkatalogen listas.
`DirectorySizeService` hoppar nu över TCC-skyddade standardmappar.

# Undersökning: Total Commander — funktioner och tangentbord

Källor: Ghisler FAQ (ghisler.com/efaquser.htm), TC-forum (ghisler.ch/board),
genvägsöversikter för Total Commander. Undersökt 2026-10-23.

## Standardknappar (funktionsraden, TC)

| TC | Funktion | Twin (macOS-mappning) |
|---|---|---|
| F3 | Visa fil (Lister) | Space / Quick Look (finns) |
| F4 | Redigera fil | Cmd+E — inbyggd textredigerare (nytt) |
| F5 | Kopiera till andra panelen | Cmd+5 + knapp (finns) |
| F6 | Flytta/döp om | Cmd+6 + knapp (finns; rename kvarstår) |
| F7 | Ny mapp | Cmd+7 (kvarstår) |
| F8 / Del | Radera (papperskorg) | Cmd+Delete — till papperskorgen, med bekräftelse (nytt) |
| Alt+F5 | Packa (komprimera) | Cmd+Shift+C — .zip bredvid markeringen (nytt) |
| Alt+F6 | Packa upp | kvarstår |
| Alt+F1/F2 | Byt enhet vänster/höger panel | Volymer i breadcrumb (kvarstår) |

SwiftUI saknar F-tangenter i `KeyEquivalent`, därav Cmd-mappningarna.
Knapparna i funktionsraden ska alltid visa TC-namnen (F5 Copy osv).

## Navigation (verifierat mot Ghislers dokumentation/forum)

- **Backspace eller Ctrl+PgUp: upp en nivå** (`cd ..`). På Mac är
  Delete-tangenten (⌫) just Backspace — i Twin går ⌫ upp en nivå.
  Radera filer är i TC F8/Del (framåt-delete); i Twin Cmd+⌫ till
  papperskorgen. Den uppdelningen är medveten och dokumenterad i hjälptexter.
- **Ctrl+PgDn / Enter: öppna mapp.** I Twin: Enter eller dubbelklick.
- **Alt+Pil vänster/höger: bakåt/framåt i historiken**, Alt+Ned: historiklista.
  I Twin: Alt+Pil samt < >-knapparna i panelhuvudet (historik per panel).
- **Ctrl+\\: till roten.** Spårat, ej implementerat som tangent ännu.
- Pil upp/ned: flytta markering (Table sköter det). När man går upp en
  nivå placerar TC markören på mappen man kom ifrån — implementerat i Twin.
- Tab: byt panel. Cmd+1/Cmd+2 som komplement (finns).
- Fokus ska ligga på fillistan direkt när panelen blir aktiv — inget
  musklick först. Krav från ProductOwner, implementerat via `@FocusState`.

## Katalogstorlekar

TC visar `<DIR>` tills man ber om storlek:

- Space på en mapp: räkna just den mappen.
- Alt+Shift+Enter: räkna alla mappar i listningen, sen kan man sortera
  på storlek (Ctrl+F6 i TC).

Twin: `DirectorySizeService` (actor) räknar rekursivt i bakgrunden och
cachar per sökväg. Cachen ogiltigförklaras när mappens ändringsdatum
flyttar sig. Size-kolumnen visar `…` medan räkning pågår, därefter
storleken — automatiskt, utan tangenttryck, med Space/Alt+Shift+Enter-
semantiken som förlaga (vi räknar direkt eftersom cachen gör det billigt
andra gången).

## Övriga operationer (denna omgång)

- MD5: skapa `<fil>.md5` bredvid filen (CryptoKit, strömmande läsning).
- Kryptera: AES-GCM (CryptoKit), nyckel från lösenfras via SHA-256,
  utdata `<fil>.twinenc`. Dekryptering av `.twinenc` med samma fras.
- Radera: papperskorgen via `FileManager.trashItem`, aldrig direkt rm,
  och alltid bekräftelse först.
- Editor: enkel inbyggd textredigerare (TextEditor) för textfiler,
  Cmd+S sparar tillbaka till samma fil.

# Undersökning: Total Commander jämfört med Twin — komplett gap-matris

Undersökt 2026-10-24 (ersätter den avgränsade versionen från 2026-10-23).
Källor för TC: Ghisler FAQ (ghisler.com/efaquser.htm), TC-forum
(ghisler.ch/board), Ghislers officiella feature list
(ghisler.com/featurel.htm — avstämd 2026-10-24, se markeringar
"Officiell lista" nedan), DefKey:s genvägslista (defkey.com/total-commander-shortcuts),
skärmbild av TC 7.0 från ProductOwner. §10 bygger på ProductOwners
skärmbild av EF Commander samma dag.
Källor för Twin: kodinventering av `Sources/TwinApp`, `Sources/TwinCore`,
`Sources/TwinPro` samma dag — status nedan säger var funktionen bor.

## Slutsats

Twin har TC:s kärna: två paneler, F3–F8, markering, historik, tabbar,
katalogstorlekar, packa/unpacka (zip), massbyte av namn och mappsynk.
Twin saknar TC:s verktygsdjup runt panelerna: rekursiv sökning,
kommandorad, arkiv som mappar, filjämförelse och nätverkspaneler.
Twin har också funktioner TC saknar: AI-assistent, filtypsguide med
egna handlers, git-badges, proaktiva mappinsikter och FinderSync.

Status: ✅ klart · 🟡 delvis · ❌ saknas · 🚫 medvetet avstående
(Windows-specifikt utan macOS-motsvarighet).

Prioritet för det som saknas:
P0 = TC-användare förväntar sig det dag 1 · P1 = tydligt proffsbehov ·
P2 = nisch, byggs vid efterfrågan.

## 1. Funktionsrad och filoperationer

| TC-funktion | TC | Twin | Status | Prio |
|---|---|---|---|---|
| Visa fil (Lister) | F3 | F3 Twin Viewer + Quick Look (Space) | ✅ | |
| Redigera fil | F4 | F4/Cmd+E inbyggd editor, extern via filtypsguide | ✅ | |
| Kopiera till andra panelen | F5 | Riktiga F5 + Cmd+5, progress med hastighet | ✅ | |
| Flytta | F6 | Riktiga F6 + Cmd+6 | ✅ | |
| Döp om | Shift+F6 | Rename i meny/funktionsrad (Cmd+Shift+R) | ✅ | |
| Ny mapp | F7 | Riktiga F7 + Cmd+7 | ✅ | |
| Radera till papperskorg | F8 | Riktiga F8 + Cmd+Delete, bekräftelse, alltid Trash | ✅ | |
| Packa | Alt+F5 | Cmd+Shift+C, .zip bredvid markeringen | ✅ | |
| Packa upp | Alt+F6 | Cmd+Shift+U via funktionsrad/meny | ✅ | |
| Packa fler format (RAR, 7z, tar) | Alt+F5 | Endast zip | ❌ | P1 |
| Bläddra i arkiv som mapp | Enter på arkiv | Arkiv kan bara packas upp till mapp | ❌ | P0 |
| Kopieringskö (bakgrund, F2 i dialogen) | F5→F2 | En operation i taget, avbrytbar | 🟡 | P1 |
| Överskrivningsdialog (jämför, döp om, hoppa) | vid konflikt | Hoppar över befintliga + rapporterar i statusrad | 🟡 | P1 |
| Dela/kombinera filer | Files-menyn | — | ❌ | P2 |
| Skriv ut fillista | Files-menyn | — | ❌ | P2 |
| Packa stora arkiv i bakgrunden (Officiell lista) | automatiskt | Packning är synkron i dag | 🟡 | P1 |
| Dra och släpp mot skrivbord/Finder (Officiell lista) | Explorer | Panel↔panel + Finder fungerar; Option-drag saknar musbevis (#12) | 🟡 | P0 |

## 2. Navigation och paneler

| TC-funktion | TC | Twin | Status | Prio |
|---|---|---|---|---|
| Upp en nivå | Backspace / Ctrl+PgUp | ⌫ eller Ctrl+PgUp; markören hamnar på mappen man kom från | ✅ | |
| Öppna mapp/fil | Enter / Ctrl+PgDn | Enter, dubbelklick; editorval åsidosätter macOS | ✅ | |
| Bakåt/framåt i historik | Alt+←/→ | Alt+←/→ samt chevronknappar | ✅ | |
| Historiklista | Alt+↓ | — (bara stega med Alt+←/→) | ❌ | P1 |
| Till roten | Ctrl+\ | Ctrl+\ implementerat | ✅ | |
| Byt panel | Tab | Tab + Cmd+1/Cmd+2 | ✅ | |
| Fokus på listan direkt | alltid | Ja, utan musklick (XCUITest-verifierat lokalt) | ✅ | |
| Enhetsväljare per panel | Alt+F1/F2 | Go-menyn (Home/Desktop/Documents/Downloads/iCloud) + bokmärken | 🟡 | P0 |
| Volymer (externa diskar, nätverk) | Alt+F1-listan | Syns via breadcrumbs från /Volumes | 🟡 | P0 |
| Mapplista-favoriter (Directory Hotlist) | Ctrl+D | Workspaces (Pro) + Go-menyn, ingen snabbmeny per panel | 🟡 | P1 |
| Grenvy: alla filer rekursivt i en lista | Ctrl+B | — | ❌ | P1 |
| Trädvy | Alt+F10 | Breadcrumbs ersätter delvis | ❌ | P2 |
| Flikar per panel | Ctrl+T/W | Ja, Cmd+T/Cmd+W, sessionen återställs | ✅ | |
| Låsta flikar, fliknamn | högerklick på flik | — | ❌ | P2 |
| Två paneler speglar samma mapp | cm_MatchSrc | — (Workspaces täcker en del) | ❌ | P2 |

## 3. Visning och sortering

| TC-funktion | TC | Twin | Status | Prio |
|---|---|---|---|---|
| Kort/full vy, kolumner | Ctrl+F1/F2 | Lista (Name/Size/Type/Modified) + ikonvy | 🟡 | P1 |
| Separat Ext-kolumn | alltid | Type-kolumn med ändelse | 🟡 | P1 |
| Sortera namn/ändelse/storlek/datum | Ctrl+F3–F6 | Kolumnklick; kataloger först är standard | ✅ | |
| Katalogstorlekar | Space / Alt+Shift+Enter | Automatiskt i bakgrunden med cache (`DirectorySizeService`) | ✅ | |
| Miniatyrer (thumbnails) | Ctrl+Shift+F1 | Systemikoner, inga miniatyrer | ❌ | P1 |
| Anpassade kolumner | Configuration | Fasta kolumner | ❌ | P2 |
| Färgregler per filtyp | Configuration | Bara git-badges färgas | ❌ | P2 |
| Snabbvy i andra panelen | Ctrl+Q | Quick Look-fönster (Space) i stället | 🟡 | P2 |
| Visa dolda filer | cm_SwitchHidSys | Ingen växling (dolda filtreras i listningen) | ❌ | P0 |
| HTML-vy i Lister (Officiell lista) | Lister | .html visas som kod, ingen renderad vy | ❌ | P2 |
| Visa filer oavsett storlek i Lister (Officiell lista) | Lister | Textvy/editor kapar vid 2 MB (`TextFileService`) | 🟡 | P1 |

## 4. Markering och urval

| TC-funktion | TC | Twin | Status | Prio |
|---|---|---|---|---|
| Markera med Space/Insert | Space/Ins | Cmd+klick i ikonvy; Space är upptaget av Quick Look | 🟡 | P1 |
| Markera efter mönster | Numpad + | — | ❌ | P0 |
| Markera efter ändelse | Alt+Numpad + | — | ❌ | P1 |
| Markera allt/avmarkera allt | Ctrl+A / Numpad − | Systemets val i listan | 🟡 | P1 |
| Invertera markering | Numpad * | — | ❌ | P2 |
| Jämför markering mellan paneler | Shift+F2 (Compare dirs) | — | ❌ | P1 |
| Återställ markering efter operation (Officiell lista) | NUM / | — | ❌ | P2 |
| Markerade räknas i statusraden | alltid | Ja, antal + storlek för markeringen | ✅ | |

## 5. Sök

| TC-funktion | TC | Twin | Status | Prio |
|---|---|---|---|---|
| Snabbsök i listan | Ctrl+S / bokstäver | Cmd+F filterfält per panel med träffmarkering | ✅ | |
| Hitta filer rekursivt | Alt+F7 | Cmd+Shift+F Find Files, namn under aktiv panel | ✅ | |
| Sök text i filer | Alt+F7-flik | Fältet Text in files (textfiler, inkl. träffrad) | ✅ | |
| Sök med datum/storlek/attribut | Alt+F7-flikar | — | ❌ | P1 |
| Hitta dubbletter | Alt+F7 (duplicates) | Mappinsikter varnar för stora/gamla filer, ej dubbletter | 🟡 | P1 |
| Sökresultat som lista ("Feed to listbox") | i sökdialogen | Resultatlista: Show in Pane / Open / dubbelklick | ✅ | |
| Sparade sökningar | Alt+F7 (Load/Save) | — | ❌ | P2 |
| Sök inuti arkiv (Officiell lista) | Alt+F7 i arkiv | — (kräver arkivsom-mapp först) | ❌ | P2 |

## 6. Verktyg i TC:s menyer

| TC-funktion | TC | Twin | Status | Prio |
|---|---|---|---|---|
| Multi-Rename-Tool | Ctrl+M | Batch Rename (Pro): sök/ersätt, prefix/suffix, numrering, förhandsvisning | 🟡 | P1 |
| Synkronisera mappar | Commands | Folder Sync (Pro): jämför + kopiera, spegel till Trash | ✅ | |
| Jämför filer efter innehåll | Shift+F2 / Files | — | ❌ | P0 |
| Kontrollsummor skapa | Files (CRC/MD5) | MD5-fil per fil (CryptoKit) | ✅ | |
| Kontrollsummor verifiera | Files | MD5 beräknas i kod men ingen verifierings-UI | 🟡 | P1 |
| Kryptera | Files (med lösenord) | AES-GCM .twinenc (Cmd+Shift+E), mer än TC:s bas | ✅ | |
| Byt attribut (datum, tider, rwx) | Files | Permissions (Cmd+I): rwx triader + presets, nybörjarvänligt | 🟡 | P1 |
| Kommandorad + historik | nederst, Alt+F8 | — | ❌ | P0 |
| Kör externt program för filtyp | interna kopplingar | **Filtypsguiden**: egen app eller kommando med `{file}` — går längre än TC | ✅ | |
| Systeminfo, processlista | Start-menyn | — (utanför filhantering) | 🚫 | |
| FTP/FTPS-panel | Ctrl+F | — | ❌ | P1 |
| SFTP/WebDAV (plugins) | plugin | — | ❌ | P2 |
| Windows-registret, .lnk, ADS | plugin/Windows | Ingen macOS-motsvarighet | 🚫 | |
| Egna kommandon i knapp-/funktionsrad (Officiell lista) | konfigurerbar | Filtypsguidens handlers täcker per filtyp, inte globala kommandon | 🟡 | P2 |
| Konfigurerbar huvudmeny (Officiell lista) | konfigurerbar | Fasta TC-menyer | 🚫 | |
| Encode/Decode UUE/XXE/MIME (Officiell lista) | Files | — | ❌ | P2 |
| Synkronisera mapp mot ZIP-fil (Officiell lista) | Commands | Folder Sync är mapp↔mapp | ❌ | P2 |
| Kopiera arkiv → arkiv direkt (Officiell lista) | arkivvy | — (kräver arkiv som mappar) | ❌ | P2 |
| Språk i gränssnittet (Officiell lista: bl.a. svenska) | 20+ språk | Endast engelska i UI:t i dag | ❌ | P1 |

## 7. Lister (F3) och plugins

| TC-funktion | TC | Twin | Status | Prio |
|---|---|---|---|---|
| Text, hex, binär | Lister | Text med radnummer, hexdump för binärt | ✅ | |
| Bilder, media | Lister + plugins | Bildzoom, PDF, AVPlayer inbyggt | ✅ | |
| Markdown renderad | plugin | Inbyggt med Raw-växling | ✅ | |
| Välja extern viewer per typ | Configuration | Filtypsguiden (steg 2, gäller F3) | ✅ | |
| Lister-plugins (WLX/WCX/WDX) | plugin-ekosystem | Egna handlers i guiden ersätter enklaste fallen; inget binärt plugin-API | 🟡 | P2 |

## 8. Det Twin har som TC saknar

| Twin-funktion | Var |
|---|---|
| AI-assistent: svar från inbyggd hjälp + on-device-modell när den finns, åtgärdsknappar (kartotek, risker) | Assistant, Commands-menyn |
| Siri/App Intents för filåtgärder | `Sources/TwinApp/Intents` |
| Filtypsguide: koppla ändelse → visare/editor, åsidosätt macOS i Twin | Files ▸ File Type Handlers… |
| Proaktiva mappinsikter: föräldralösa filer → Kartotek, behörighetsrisker | `FolderInsightsService` |
| Git-badges (M/?) i namnkolumnen, skrivskyddat mot repot | Pro, `GitStatusService` |
| Enkel behörighetsredigering för nybörjare | Permissions (Cmd+I) |
| FinderSync: "Open in Twin" i Finder | FinderSyncExtension |
| iCloud Drive i Go-menyn, start i hem/Desktop — aldrig sandboxcontainern | `UserPlaces` |
| Sessionsåterställning per panel inkl. flikar | `PaneTabs` + UserDefaults |

## 9. Verifierade navigationsregler (från förra undersökningen, fortfarande sanna)

- **Backspace eller Ctrl+PgUp: upp en nivå.** På Mac är Delete-tangenten (⌫)
  just Backspace — i Twin går ⌫ upp en nivå. Radera filer är Cmd+⌫ till
  papperskorgen. Uppdelningen är medveten och dokumenterad i hjälptexterna.
- **Ctrl+PgDn / Enter: öppna.** I Twin: Enter eller dubbelklick.
- **Alt+←/→: bakåt/framåt i historiken** per panel, även chevronknappar.
- **Ctrl+\: till roten.** Implementerat som tangent.
- När man går upp en nivå placerar TC markören på mappen man kom ifrån —
  implementerat i Twin (`goUp`).
- Fokus ska ligga på fillistan direkt när panelen blir aktiv — inget
  musklick först. Implementerat via fokus på Table/ScrollView.
- TC visar `<DIR>` tills man ber om storlek (Space, Alt+Shift+Enter).
  Twin räknar automatiskt i bakgrunden och cachar per sökväg med
  ogiltigförklaring på ändringsdatum (`DirectorySizeService`), så
  Space/Alt+Shift+Enter behövs inte. TCC-skyddade mappar räknas aldrig
  i bakgrunden (de skulle trigga samtyckesdialoger).

## 10. Kompletterande referens: EF Commander

Tillagt 2026-10-24 efter ProductOwners skärmbild av EF Commander
(en TC-klon). Flera av dess idéer saknas i TC och fanns inte i
matrisen ovan — de är nu inprioriterade i arbetsordningen:

| EF-funktion | Vad det är | Twin i dag | Bedömning |
|---|---|---|---|
| Container (F9) | Virtuell panel: samla filer från olika mappar i en lista utan att flytta dem | Sökresultat blir motsvarigheten när rekursiv sökning byggs | P1 — bygg på sökresultaten |
| Only selected files | Visa bara de markerade filerna i panelen | Filter finns på namn, inte på markering | P1 — litet jobb på befintligt filter |
| Job Center | Central kö för bakgrundsjobb | En operation i taget (se §1) | Samma leverans som kopieringskön, §1/P1 |
| Favorites-meny | Snabb favoritmappar per panel | Workspaces (Pro) + Go-menyn | Delvis täckt; per-panel-favoriter P2 |
| Synchronous folder changing | Båda panelerna byter mapp i takt | — | P2 |
| Synchronized scrolling | Panelerna scrollar synkat (jämför mappar) | — | P2 — hör ihop med mappjämförelse |
| Tile Horizontally/Vertically | Växla panelriktning (sida-vid-sida eller staplade) | Alltid sida-vid-sida (HSplitView) | P2 |
| 10 funktionsknappar (1 Help … 10 Exit) | Även hjälp och meny är funktionsknappar | F3–F8 + More-meny | Mönstret bekräftar vår funktionsrad; 9 Container följer av Container-stödet |
| Filtypsfärger i listan | Färg per filtyp/kategori | Bara git-badges färgas | Redan P2 i §3 |

Lärdom: EF Commander visar att TC-klonerna själva har fortsatt
utvecklas. Matrisen mot TC förblir huvudspåret, men Container och
Only selected files är värda att ta in — båda bygger på saker Twin
redan har (sökresultat respektive filter).

## 11. Prioriterad arbetsordning

Beta av i den här ordningen — varje punkt är en egen leverans med
tester innan nästa börjar:

**P0 — TC-kärnans förväntningar**
1. ~~Rekursiv sökning~~ KLART 2026-10-24: Cmd+Shift+F Find Files —
   namn + textinnehåll, resultatlista med Show in Pane/Open
   (`FileSearchService`, UI-test `testFindFilesRecursiveSearch`).
2. Kommandorad längst ner som på TC-bilden: kör kommando i aktiv mapp,
   historik med Alt+F8-beteende, utdata synlig.
3. Öppna arkiv som mappar (zip först, sedan tar/7z via formatstöd),
   kopiera ut filer utan full uppackning.
4. Visa/dölj dolda filer som växling (TC: cm_SwitchHidSys).
5. Markera efter mönster (glob) — litet jobb, stor TC-vana.
6. Volymväljare per panel: Alt+F1/F2-tänk med /Volumes, externa diskar
   och iCloud som förstklassiga val.

**P1 — proffsdjup**
7. Jämför två filer efter innehåll (diff-vy för text).
8. Överskrivningsdialog vid kopiering: jämför/döp om/hoppa över per fil.
9. Kopieringskö: flera operationer i bakgrunden med gemensam progress.
10. Fler arkivformat vid packning (tar.gz), checksum-verifiering i UI.
11. Miniatyrer i ikonvyn, separat Ext-kolumn som val.
12. Markera efter ändelse, jämför markering mellan paneler (Shift+F2).
13. Attribut komplett: datum/tider utöver rwx i Permissions.
14. FTP-panel (FTPS först) — kräver nätverksentitlement och säkerhetsgranskning.
15. Grenvy (Ctrl+B): alla filer rekursivt i en lista.
16. Container (från EF Commander): sökresultat/egen samling som
    virtuell panel man kan kopiera från — naturlig fortsättning på 1.
17. Only selected files (från EF Commander): filterläge som visar
    bara markeringen i aktiv panel.
18. Svensk lokalisering av UI:t (Officiell lista har svenska; Twin
    säljs i SEK på svenska App Store men talar bara engelska).
19. Strömmande visning av stora textfiler i viewern — Listers
    "oavsett storlek" i stället för 2 MB-taket för visning
    (editorn behåller sin gräns).

**P2 — vid efterfrågan**
20. Egna kolumner och färgregler per filtyp.
21. Dela/kombinera filer, skriv ut fillista, sparade sökningar.
22. SFTP/WebDAV, låsta flikar, historiklista (Alt+↓) som meny.
23. Synkroniserad navigering/scrollning mellan panelerna och
    växling av panelriktning (Tile) — från EF Commander.
24. Renderad HTML-vy i viewern, återställ markering (NUM /),
    encode/decode (UUE/XXE/MIME), synk mapp↔ZIP, arkiv→arkiv —
    samtliga från Ghislers officiella lista.
25. Binärt plugin-API motsvarande WLX/WCX — först om egna handlers
    i guiden visar sig otillräckliga.

**Medvetna avståenden (🚫)**
- Enhetsbokstäver som begrepp — macOS har volymer, Twin använder
  platser och /Volumes i stället.
- Windows-register, .lnk-genvägar, alternativa dataströmmar.
- Systemverktyg utanför filhantering (processlistor, systeminfo).

## 12. Metod och begränsningar

- Twin-status kommer från kodläsning, inte från dokument: menyerna i
  `Sources/TwinApp/TwinApp.swift`, funktionsraden i
  `Sources/TwinApp/Features/DualPane/DualPaneView.swift`, panelbeteende
  i `PaneView.swift`/`PaneViewModel.swift`, tjänsterna i
  `Sources/TwinCore/*.swift`.
- TC-listan bygger på genvägs- och funktionsöversikter ovan plus
  ProductOwners TC 7.0-skärmbild. TC har hundratals interna kommandon
  (cm_*); matrisen täcker allt som är synligt i menyer, funktionsrad
  och standardgenvägar — inte varje cm_-kommando.
- Där Twin medvetet valt annorlunda än TC (Space = Quick Look i stället
  för markering, Cmd+⌫ i stället för Del) står det i matrisen som 🟡,
  inte som fel.

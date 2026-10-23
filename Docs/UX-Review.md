# Twin — UX-granskning (seniornivå)

[LeadUX -> ProductOwner]: Kritisk granskning av nuvarande gränssnitt.
Skärmfångst från sessionen är fortfarande blockerad av macOS TCC
(`screencapture`: "could not create image from display", ScreenCaptureKit:
"The user declined TCCs", AppleScript -1719). Granskningen bygger därför på
full kodgenomgång av `PaneView`/`PaneViewModel`/`DualPaneView` samt en
offscreen-rendering av panelhuvudet. Slutsats: nuvarande nivå är en prototyp,
inte en användbar filhanterare. Punkterna nedan är i prioritetsordning.

## Kritiskt — gör produkten oanvändbar

1. **Listan är ingen filvy.** Raderna saknar kolumner för storlek/datum,
   sortering och tangentbordsnavigering värd namnet. En filhanterare lever
   på att man kan sortera på datum och storlek och köra allt från tangentbordet.
   Åtgärd: SwiftUI `Table` med kolumner, sortering och inbyggd markering.
2. **Kopiering skriver över utan att fråga.** `performFileOperation` raderar
   befintlig målfil tyst. Det är dataförlust utan dialog — oacceptabelt.
   Åtgärd: hoppa över konflikter och rapportera dem synligt.
3. **Ingen statusinformation.** Varken markerat antal/storlek eller ledigt
   utrymme visas. Användaren flyger blint vid varje kopiering.
   Åtgärd: statusrad per panel.
4. **Aktiv panel syns knappt.** En 1px-ram och svag toning räcker inte när
   F5/F6 verkar mot "andra panelen" — fel panelval ger fel målmapp.
   Åtgärd: tydligare aktivmarkering i panelhuvudet.

## Allvarligt — daglig friktion

5. **Redundant sökväg.** Breadcrumbs, full sökväg i klartext och antalsrad
   visas samtidigt i varje panel. Tar höjd, ger brus. Behåll breadcrumbs,
   flytta resten till statusraden.
6. **Sök utan träff är en tom yta.** Filtrerar man bort allt visas bara tomhet,
   utan förklaring eller väg tillbaka.
7. **Cmd+F saknas.** Filtret går bara att nå med musen. En filhanterare ska
   ha Cmd+F till aktiva panelens filter, Esc för att lämna/rensa.
8. **Verktygsraden är textknappar.** "Left/Right/F5 Copy/F6 Move/Twin Pro"
   som text är svårscannat och bryter mot macOS-konventioner. Bör vara
   ikoner med hjälptexter (kräver riktig skärmgranskning för slutlig form).
9. **Quick Look är svår att trigga.** Space fungerar bara när panelen råkar
   ha fokus; efter klick i listan är fokusläget otydligt. Behöver visuell
   fokusindikation och test i körande app.
10. **Dra-och-släpp ger ingen valmöjlighet.** Drop kopierar alltid; inget
    flytt-alternativ (Alt/Option), ingen förhandsvisning av vad som händer.

## Kvarstår till riktig skärmgranskning (kräver TCC från användaren)

- Ikonval, avstånd och typografi i verktygsrad och panelhuvud.
- Kontrast och läsbarhet i båda vyerna, ljus/mörk läge.
- Att Quick Look, Tab-fokus och drag-highlight faktiskt beter sig som kodat.

## Genomfört i denna omgång

Table-vy med sorterbara kolumner, statusrad, sök-tomt-tillstånd, Cmd+F till
filtret, konfliktrapport i stället för tyst överskrivning, starkare
aktivmarkering och borttagen sökvägsredundans.

## Skärmbildsgranskning 2026-10-23 — fyra riktiga captures mot UX-Spec.md

Underlag: `Docs/screenshots/01-dual-pane.png`, `02-copy-progress.png`,
`03-icon-view.png`, `04-search.png`, jämförda rad för rad mot
`Docs/UX-Spec.md` (aktiv panel = accentram + header, oberoende
navigation/markering/view-mode per panel, drop-highlight, operation =
etikett + procent + linjär progress i panelens fot, keyboard-first med
F5/F6/Tab/Cmd+1/Cmd+2/Cmd+F). Tidigare kodfynd ovan står kvar; detta är
det som syns — och inte syns — i körande app. Prioritet: P0 = fel fil/
fel mål risk eller kärnflöde blockerat, P1 = daglig friktion, P2 = puts.

### P0 — åtgärda före nästa testrunda

1. **Kopieringen går inte att avbryta och säger nästan ingenting
   (02).** Panelens fot visar bara `Copying 1 item(s)… 0%` för en fil
   på 2,15 GB: ingen filnamnsetikett, inga kopierade bytes/total,
   ingen hastighet/ETA och — värst — ingen Cancel-knapp. Vid 0 %
   går det inte att skilja "arbetar" från "har hängt sig".
   Ändra: namnge filen (`Copying bigfile.bin — 340 MB of 2,15 GB ·
   82 MB/s · ~20 s left`), lägg till en synlig Cancel-knapp som
   avbryter pågående operation, och behåll linjär progress enligt
   spec. Filer: `Sources/TwinApp/Features/DualPane/PaneView.swift`
   (`progressBar`), `Sources/TwinApp/Features/DualPane/PaneViewModel.swift`
   (`performFileOperation`, `operationProgress`/`operationLabel` —
   byt från enbart `Double`-procent till bytes/hastighet + avbrytbar
   `Task`), bakomliggande loop i TwinCore anropas därifrån.
2. **Funktionsraden ryms inte — åtgärder försvinner utanför fönstret
   (01, 02, 03, 04).** Vid fönstrets minimibredd klipps raden mitt i
   `Sync` (`Sy…`/`S` i 02/04); Batch Rename, Workspaces, Permissions,
   Assistant och Delete ligger dolda i en horisontell scroll utan
   synlig scrollindikator eller "»"-affordance. En TC-användare ser
   aldrig Delete. Ändra: låt raden krympa i fast prioritetsordning
   (F5/F6/Edit/New Folder/Rename/Delete alltid synliga, övrigt under
   en explicit `More`-meny), sluta scrolla tyst, och höj vid behov
   minimibredden. Filer: `Sources/TwinApp/Features/DualPane/DualPaneView.swift`
   (`functionBar`, `ScrollView(.horizontal)` tas bort),
   `Sources/TwinApp/TwinApp.swift` (`minWidth: 900`).
3. **Knapparna lovar F5/F6 men tangenterna gör ingenting (01–04).**
   Specen medger själv att SwiftUI saknar F5/F6 och att Cmd+5/Cmd+6
   är ersättningen — men knapptexten säger fortsatt `F5 Copy`/
   `F6 Move`. För en keyboard-first-produkt vars förebild är Total
   Commander är det ett brutet kärnlöfte: användaren trycker F5,
   inget händer, förtroendet dör. Ändra: antingen riktig
   AppKit-`keyDown`-hantering för F5/F6 (behåll då texterna), eller
   byt texterna till `⌘5 Copy`/`⌘6 Move` överallt tills F-tangenterna
   fungerar — aldrig text och genväg som motsäger varandra.
   Filer: `Sources/TwinApp/Features/DualPane/DualPaneView.swift`
   (`functionBar`, toolbar, `.keyboardShortcut("5"/"6")`),
   `Sources/TwinApp/Features/DualPane/PaneView.swift` (befintliga
   `onKeyPress`-hanterare är mönstret att bygga vidare på).
4. **Markeringen syns inte — men F5/F6 verkar på den (01, 03).**
   Statusraden påstår `1 selected`, men i 01 går den markerade raden
   knappt att urskilja mot växelskuggningen, och i ikonvyn (03,
   vänster panel) syns ingen markering alls trots att panelen är
   aktiv med blå ram. Användaren kan kopiera/flytta fel fil utan att
   kunna verifiera valet. Ändra: full accentfärgad markeringsbakgrund
   + fetstil i listvyn, samma tydliga markering (ram + toning +
   check vid flerval) i ikonvyn, och låt inaktiv panels markering
   tonas ned så aktiv markering alltid vinner visuellt.
   Filer: `Sources/TwinApp/Features/DualPane/PaneView.swift`
   (`listView`-radbakgrund, `iconView`-cellernas
   `selection.contains`-bakgrund 0.2 → tydligare behandling).

### P1 — daglig friktion

5. **Storlekskolumnen är död för mappar (01, 04).** Varje mapp visar
   `...`/`--`; kolumnen går formellt att sortera på men sorterar på
   värden användaren aldrig ser, och inför en kopiering går det inte
   att bedöma datamängd. Ändra: visa beräknad mappstorlek när den är
   klar (redan påbörjat via `directorySizes`), visa `—` endast för
   skyddade mappar med hjälptext som förklarar varför, och sortera
   osorterbara mappar sist i stället för på `size = 0`.
   Filer: `Sources/TwinApp/Features/DualPane/PaneViewModel.swift`
   (`directorySizeText`, `computeDirectorySizes`),
   `Sources/TwinApp/Features/DualPane/PaneView.swift` (`listView`,
   Size-kolumnen), `Sources/TwinApp/Shared/SizeFormatting.swift`.
6. **Namn trunkeras till oigenkännlighet (01, 03, 04).** `Archive -
   Ma…`, `REAPER Me…`, två `Applications…` som inte går att skilja
   åt; ingen typ-/ändelsekolumn och ingen fullständig sökväg som
   hjälptext i listan. Ändra: bredare Name-kolumn med mitten-trunkering
   (`Archive - Ma…ster.zip`), lägg till Type/Ext-kolumn, och sätt
   `.help(item.url.path)` på radtexten. I ikonvyn: tillåt 2 rader
   konsekvent (finns) men lägg till filändelse för filer.
   Filer: `Sources/TwinApp/Features/DualPane/PaneView.swift`
   (`listView`, `iconView`), `Sources/TwinApp/Shared/FileItemIcon.swift`.
7. **Filtret döljer sammanhanget (04).** `Code` ger 2 träffar, men
   statusraden säger `2 items` som om mappen krympt — inget `2 of 22`,
   ingen träffmarkering i namnen, och inget som säger att filtret bara
   gäller aktuell mapp (inte rekursiv sök). Ändra: status `2 of 22
   items · filter: "Code"`, fetmarkera träffsubstringen i raden, och
   byt placeholder/toolbar-etikett till samma begrepp överallt
   (i dag: "Filter…" i fältet, "Filter" i toolbaren, "Instant search"
   i specen — välj ett ord). Filer:
   `Sources/TwinApp/Features/Search/PaneSearch.swift`
   (`PaneSearchField`, `filter`), `Sources/TwinApp/Features/DualPane/PaneView.swift`
   (`statusBar` — räkna mot `viewModel.items.count`, inte bara
   `filteredItems.count`), `Sources/TwinApp/Features/DualPane/PaneViewModel.swift`
   (`filteredItems`).
8. **Ikonvyn är en återvändsgränd för tangentbordsanvändare (03).**
   Inga storlekar/datum, ingen synlig sortering, piltangentsnavigering
   osynlig/oklar, enkelklick *togglar* markering (avviker från listvyns
   och Finders ersätt-markering; dubbelklick riskerar att först
   avmarkera), nedersta raden klipps mitt i ikonerna utan
   scrollindikator, och alla objekt är samma blå mapp eller grå
   dokumentikon — inga riktiga filikoner/miniatyrer. Ändra:
   enkelklick = ersätt markering (Cmd-klick = toggla, som i listvyn),
   synlig fokusring vid piltangenter, storlek/datum som caption under
   namnet, riktiga `NSWorkspace`-ikoner/miniatyrer i stället för
   SF-symboler. Filer: `Sources/TwinApp/Features/DualPane/PaneView.swift`
   (`iconView`, `iconColumns`), `Sources/TwinApp/Shared/FileItemIcon.swift`
   (enda ikonkomponenten — `folder.fill`/`doc` räcker inte).
9. **Övre toolbar: åtta kryptiska ikoner utan etiketter (01–04).**
   `+`, `⨯`, två panelikoner, hem, sök, kopiera, krona, urklipp —
   gissningslek, och F5 Copy finns dessutom dubbelt (toolbar +
   funktionsrad). Kronan (Pro-upsell) tar permanent plats i primära
   verktygsraden. Ändra: behåll ikoner men ge dem textetikett under/
   bredvid vid breda fönster (som specens wireframe antyder),
   ta bort dubbleringen av F5/F6 (funktionsraden äger dem), och
   flytta Pro till menyn/statusytan. Verifiera hjälptexter
   (`.help` finns i kod men ersätter inte synliga etiketter för
   förstagångsanvändare). Fil:
   `Sources/TwinApp/Features/DualPane/DualPaneView.swift` (`toolbar`).
10. **Tomma spökrader fyller listorna (02, 04).** Växelskuggade tomma
    rader under sista filen ser ut som saknade/osynliga filer — i 02
    sju tomma rader under `bigfile.bin`. Ändra: låt tabellen sluta vid
    sista raden (fast radhöjd utan filler-rader) eller gör den nedre
    ytan neutral utan radmönster. Fil:
    `Sources/TwinApp/Features/DualPane/PaneView.swift` (`listView`,
    `Table`-stilen).
11. **Statusraden talar utvecklarspråk (01, 03, 04).** `· 1 orphans`
    (även grammatiskt fel: "1 orphans") utan förklaring i vyn,
    `759,27 GB free` duplicerat identiskt i båda panelerna trots
    samma volym, och ingen total storlek för markeringen — det
    enda tal som betyder något före F5. Ändra: `1 selected · 2,15 GB`,
    visa volyminfo en gång per volym (dölj i panel 2 om samma volym),
    och ersätt `orphans` med begriplig text + klickbar väg till
    Assistant, eller ta bort det från statusraden helt.
    Filer: `Sources/TwinApp/Features/DualPane/PaneView.swift`
    (`statusBar`, `freeSpaceText`),
    `Sources/TwinApp/Features/DualPane/PaneViewModel.swift`
    (`insights`, markeringens storlekssumma saknas).

### P2 — puts och konsekvens

12. **Blandad lokalisering (01–04).** Engelsk UI-text men svenskt
    decimaltecken (`759,27 GB`), engelska månadsförkortningar
    (`31 Jan at 18:57`). Välj en locale konsekvent för tal- och
    datumformat. Filer: `Sources/TwinApp/Shared/SizeFormatting.swift`
    (`ByteCountFormatter`), `Sources/TwinApp/Features/DualPane/PaneView.swift`
    (Modified-kolumnens `.dateTime`-format).
13. **Rot-brödsmulan är ett ensamt `/` (01, 03, 04)** och djupa
    sökvägar scrollar horisontellt utan indikator; fliktiteln
    duplicerar dessutom sista brödsmulan (`aelmen`/`Documents`
    två gånger i varje panel). Ändra: namnge roten (`Macintosh HD`
    eller hemkatalogens namn), och låt fliken visa mappnamn +
    full sökväg som hjälptext — eller slopa dupliceringen.
    Filer: `Sources/TwinApp/Shared/BreadcrumbBar.swift`,
    `Sources/TwinApp/Features/DualPane/PaneViewModel.swift`
    (`breadcrumbs`, rot-crumben `Breadcrumb(name: "/")`),
    `Sources/TwinApp/Features/DualPane/DualPaneView.swift` (`tabStrip`).
14. **Filterfältet äter permanent höjd i båda panelerna (01–04)**
    trots att wireframen i specen inte har det framme; det är 6–8 %
    av fönsterhöjden per panel för något som används ibland.
    Ändra: kollapsa till en sökikon i panelhuvudet som expanderar
    vid Cmd+F (genvägen finns redan), eller behåll fältet men bara
    i aktiva panelen. Filer:
    `Sources/TwinApp/Features/DualPane/PaneView.swift` (`header`),
    `Sources/TwinApp/Features/Search/PaneSearch.swift`.
15. **`item(s)`-språk och generiska operationstexter (02).**
    `Copying 1 item(s)…` är utvecklarprosa; skriv `Copying
    bigfile.bin…` / `Copying 3 files…`. Samma mönster i raderings-
    och Trash-texterna. Filer:
    `Sources/TwinApp/Features/DualPane/PaneViewModel.swift`
    (`operationLabel` i `performFileOperation`),
    `Sources/TwinApp/Features/DualPane/DualPaneView.swift`
    (Trash-alertens `item(s)`-text).

### Vad som nu stämmer mot specen — rör inte

- Aktiv panel är omisskännlig: 2 px accentram + tonat huvud i alla
  fyra bilderna, och rätt panel är aktiv i varje scenario (01/04
  vänster, 02 höger). Specens viktigaste regel håller.
- Per-panel-oberoende fungerar synligt: list/ikon blandat i 02/03,
  filter i bara höger panel i 04, oberoende markering och tabs.
- Progress sitter i panelens fot med etikett + procent + linjär
  indikator exakt som specificerat (innehållet i den är P0-1 ovan,
  inte placeringen).
- Funktionsraden med `aktiv mapp → målmapp` längst ned är rätt
  TC-signal — problemet är bara att den inte får plats (P0-2).

## Andra skärmbilden — seniorfynd (nu åtgärdade)

- Högerpanelens huvudinnehåll låg vertikalt centrerat när mappen var tom:
  `ContentUnavailableView` expanderade inte. Alla innehållsgrenar fyller
  nu sin yta och panelen är toppförankrad.
- Containerfällan har nu en synlig banner i panelen ("Sandbox container —
  not your files" + Choose Folder…) i stället för en engångsmodal som var
  lätt att missa/avbryta. Vald mapp bokmärks per panel.
- Breadcrumbs börjar på "Twin Data" inne i containern i stället för
  `/Users/…/Library/Containers/se.dvisious.twin/…`.
- Total Commander-funktionsrad längst ned: aktiv mapp → målmapp, F5 Copy /
  F6 Move (inaktiva utan markering). En TC-veteran ska känna igen sig.

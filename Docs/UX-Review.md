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

## Skärmbild från användaren 2026-10-23 — nya fynd

Användarens capture av körande app bekräftade och utökade granskningen:

- **Layoutkollaps (kritiskt, nu åtgärdat):** allt innehåll låg i ett band
  i fönstrets mitt med stora tomma ytor över/under. Orsak:
  `NavigationStack` inuti `HSplitView`. Borttaget; panelerna fyller nu
  hela fönstret och mappnamnet läcker inte längre som fönstertitel ("Data").
- **"View"-texten radbröts vertikalt** ("V/ie/w") i view-väljaren.
  Åtgärdat med `labelsHidden`.
- **"Try Again" på tom mapp** var meningslöst — visas nu bara vid fel.
- **Textpiller i verktygsraden** ersatta med ikon+text (Label/systembilder).
- Datumformatet förkortat.
- Fortfarande öppet: appen startar i sandbox-containerns Data-mapp
  (`~/Library/Containers/se.dvisious.twin/Data`) eftersom sandlådan pekar
  hemkatalogen dit. För en filhanterare krävs en medveten startpunkt —
  förslagsvis senaste bokmärkta mappen, annars en välj-mapp-uppmaning.
  Spåras på #9.

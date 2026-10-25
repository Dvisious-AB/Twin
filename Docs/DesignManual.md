# Twin Designmanual — macOS 2026

Gäller all UI i Twin. När manualen och gammal kod krockar vinner
manualen vid nästa beröring av ytan. TC-Research.md äger beteende
och genvägar; den här manualen äger utseende och interaktion.

## Principer

1. **Tangentbordet först, alltid.** Varje yta ska gå att använda
   utan mus. synlig fokus, förutsägbar Tab-ordning, Esc stänger.
2. **Assistent-först, men aldrig i vägen.** Gemma är alltid synlig
   längst ner. TC-lagret (funktionsrad, F-tangenter, menyer) ligger
   orört ovanför henne och fungerar utan henne.
3. **Plan före utförande.** AI och batchåtgärder visar vad som ska
   hända innan något körs. Destruktivt bekräftas alltid.
4. **Ärliga tillstånd.** Laddning, tomt, fel och avsaknad av
   behörighet ritas alltid med en väg vidare — aldrig en död yta.
5. **Datorns språk.** Hjälp och assistentsvar följer systemets
   språk (TwinLanguage). Engelska är reserv, inte standard.

## Fokusregeln (standardfält)

- Varje formulär och sheet har **ett** standardfält: det fält
  användaren nästan alltid ska börja i.
- Standardfältet har fokus i samma ögonblick som ytan öppnas.
  Ingen ska behöva klicka sig in i ett formulär.
- Standardfält per yta:
  - Assistenten: frågefältet.
  - Gemma-raden: skrivfältet (Cmd+K hoppar dit från var som helst).
  - Find Files: fältet "Name contains".
  - File Type Handlers: filtypsfältet högst upp.
  - Batch Rename: sökfältet.
  - Texteditorn: textytan.
  - Namnge/ny mapp-dialoger: namn fältet, med texten markerad.
- Enter i standardfältet = primäråtgärden när det är säkert
  (sök, spara). Esc = avbryt/stäng, överallt.
- Fokus syns: systemets fokusring, eller accentkant (1.4 pt) på
  egna fält som Gemma-radens kapsel.

## Layout och material

- Fönstret: paneler i mitten, funktionsrad under dem, Gemma-rad
  längst ner i full bredd. Inget får scrolla bort funktionsraden
  eller Gemma-raden — de är dockade.
- Material: `.bar` för funktionsrad, statusrader och Gemma-rad.
  Platta kontrollbakgrunder bara inne i listor och kort.
- Hårlinjer är 0.5–1 pt separatorfärg. Inga tunga ramar; den
  aktiva panelen markeras med accentkant runt listan.
- Avstånd i 4-steg: 4, 8, 10, 12, 16. Knappar i en rad delar
  alltid samma höjd (`controlSize(.small)` i funktionsraden).

## Kontroller

- Funktionsraden: kantade pill-knappar med ikon + text
  (`Label`). Destruktivt (Delete) har destruktiv roll och
  papperskorgsikon. Mapp-paret till vänster är ett kapselchip;
  under 1040 pt visar chipet bara den aktiva mappen.
- Flikar är flikar: de står på radens baslinje med rundade
  överhörn. Aktiv flik är högre, bär fönsterbakgrunden och täcker
  den undre linjen så flik och panel är en yta. Stängkryss vid
  hovring/aktiv flik.
- Växlare lista/ikon är segmenterade ikoner i panelhuvudet.
- Formulär: etikett över eller vänster om fältet, primärknapp
  längst ner till höger (Enter), Cancel till vänster om den.
  Spara är inaktivt tills formuläret är giltigt — med synlig
  anledning (t.ex. "välj en app först").

## Typografi och färg

- Systemfonten överallt. Rubriker: headline. Brödtext: body.
  Metatext och status: caption i sekundärfärg. Siffror som ska
  jämföras (storlekar, datum) är monospaced digits.
- Accentfärgen är systemets. Ingen egen lila/blå gradient, inga
  skuggglöd. Semantiska färger sparsamt: orange för varning/risk,
  rött bara för destruktivt, grönt för klart/aktiv.
- Katalogikoner får betydelsefärg per typ (git orange, samples
  rosa, musik röd) — se FolderKind. Filer behåller Finderikoner.

## Listor och paneler

- Mappar först, sedan filer; sortering på kolumnklick. Markering
  är systemblå heldragen rad. Storlekar för mappar fylls i
  asynkront (`…` under räkning) utan att listan hoppar: reservera
  cellbredd med monospaced digits.
- Tom lista visar ContentUnavailableView med nästa åtgärd.
  Fel visar orsak + återhämtning (Grant Access, Choose Folder,
  Go Up) — aldrig bara "Try Again".

## Gemma

- Gemma är en geometrisk robot med tvådelat huvud (panelerna),
  ett öga per halva. Hon andas/blinkar i vila, antennen pulserar
  när hon tänker. Reduce Motion = stillbild.
- Hennes svar på utförda åtgärder innehåller tangentmotsvarigheten
  ("Med tangenterna: Cmd+Shift+C") — hon lär ut TC i stället för
  att ersätta det.
- Fakta om aktuell katalog (störst fil, ägare, datum) svaras
  alltid från den riktiga listningen, aldrig av modellgissning.
- Modellen är Apples on-device-modell när den finns; annars den
  inbyggda hjälpen. Statusraden säger alltid vilket läge som gäller.

## Formulärspecifikt: File Type Handlers

- Vänster: filtyperna, med prick för dem som har eget val.
- Höger: detalj i kort — 1) typ, 2) visare (F3), 3) editor
  (F4/Enter), sedan egen handler och macOS-standard.
- Summering + Spara sitter i en klibbig rad längst ner och
  uppdateras medan man väljer. Återställ är textknapp, inte
  destruktiv färg.
- Guiden styr Twin. macOS-standard sätts bara på uttrycklig
  knapp och resultatet redovisas ärligt (sandbox kan neka).

## Rörelse och tillgänglighet

- Animation bara där den förklarar: Gemmas blink/puls, flikars
  hovring, progress. Allt övrigt är omedelbart.
- Reduce Motion respekteras. Minsta träffyta 20×20 i verktygs-
  rader, annars 28. Kontrast: sekundärtext aldrig under
  `.secondary` på material.

## Checklista för ny yta (innan den anses klar)

- [ ] Standardfältet har fokus vid öppning, Enter/Esc fungerar.
- [ ] Ytan går att nå och stänga med bara tangentbord.
- [ ] Tom-, laddnings- och feltillstånd har en väg vidare.
- [ ] Texten följer datorns språk där hjälpinnehåll visas.
- [ ] UI-test eller skärmbild bevisar ytan i riktiga appen.

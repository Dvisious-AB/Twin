# Twin — Team & Definition of Done

## Bemanning

| Roll | Vem | Ansvar |
|---|---|---|
| Sponsor | Anders (Dvisious AB) | Finansiering, Developer-konto, slutgodkännande |
| Produktägare | Muse (denna session) | Prioritering, sprintplan, DoD-kontroll, leverans |
| Systemingenjör | Agent-roll | Arkitektur, paketgränser, concurrency (Architecture.md) |
| Systemutvecklare | Agent-roll | TwinCore-tjänster + SwiftUI enligt arkitekturen |
| UX-designer | Agent-roll | Flöden för nybörjare → utvecklare → avancerad |
| UX-slutanvändaringenjör | Agent-roll | Kör appen som användare, XCUITest som bevis |
| Enhetstestare | Agent-roll | TwinCoreTests för varje ny tjänst |
| Prestandatestare | Agent-roll | Storlek/synk-mätningar på syntetiska träd |
| Säkerhetsrådgivare | Agent-roll | Behörigheter, kryptering, riskskanning, sandbox |
| Dokumenterare | Agent-roll | Docs/, README, hjälptexter (TwinHelp) |

Agent-rollerna exekveras i produktägarens session. Spawnade subagenter har
upprepat fallerat på infrastruktursidan (dokumenterat i sessionen), så
arbetet körs inline med samma roll- och filägarskap tills vidare.

## Definition of Done — "en snarlik Total Commander för macOS med AI"

Twin är klar för en funktion när allt detta gäller:

1. **Tangentbord först.** Allt går utan mus: navigering, markering,
   kopiera/flytta, byt namn, radera (papperskorg), packa, kryptera.
2. **AI utför, inte bara svarar.** Assistenten organiserar kataloger,
   döper om, hittar föräldralösa filer, bygger kartotek och flaggar
   säkerhetsrisker — med förhandsbesked före destruktiva steg.
3. **Proaktivitet.** Panel/assistent visar förslag utan att man frågar:
   många lösa filer → organisera; världsskrivbara filer → varning;
   stora kataloger → storleksinfo.
4. **Säker standard.** Inget skrivs över tyst, inget hård-raderas,
   behörigheter är begripliga för nybörjare och exakta för avancerade.
5. **Bevis.** Enhetstester för tjänsten, XCUITest för flödet, grön CI
   (lint + build + swift test + UI-test). Live-prov i appen där det går.
6. **Dokumenterat.** Docs uppdaterad i samma commit; hjälptexterna i
   TwinHelp matchar verkliga genvägar.

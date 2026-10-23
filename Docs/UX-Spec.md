# Twin — UX-spec Dual-Pane (LeadUX → PaneUIEngineer)

[LeadUX -> PaneUIEngineer]: Wireframe och interaktion för MVP. Implementerat
i `Sources/TwinApp/Features/DualPane/` om inget annat anges.

## Wireframe

```
┌ Twin ────────────────────────────────────────────────────────┐
│ [F5 Copy] [F6 Move]                                          │
├──────────────────────────────┬───────────────────────────────┤
│ ◀ / ▸ Users ▸ anders  [≣|▦][↻]│ ◀ / ▸ Users ▸ anders ▸ Docs   │
│ /Users/anders        12 items │ /Users/anders/Documents 8 items│
│ ▸ 📁 Projects                 │ ▸ 📁 Archive                  │
│   📄 notes.txt        4 KB   │   📄 report.pdf       91 KB   │
│ ▸ 📁 Downloads                │ ▸ 📁 Images                   │
│ (drop-highlight vid drag)     │                               │
│ Copying 2 item(s)…       50%  │                               │
│ ▓▓▓▓▓░░░░░                    │                               │
└──────────────────────────────┴───────────────────────────────┘
```

## Interaktion

| Tangent / gest | Beteende | Status |
|---|---|---|
| F5 (Cmd+5) | Kopiera markerat till andra panelen | Implementerat* |
| F6 (Cmd+6) | Flytta markerat till andra panelen | Implementerat* |
| Tab | Växla aktiv panel | Nästa — kräver key handling i DualPaneView |
| Dubbelklick mapp | Navigera in | Implementerat |
| Dubbelklick fil | Öppna i standardapp | Implementerat |
| Drag fil → andra panelen | NSFilePromise-drop, kopiera med progress | Implementerat |
| Breadcrumb-klick | Navigera till den nivån | Implementerat |
| List/Icon-toggle | Växla listvy / ikonrutnät per panel | Implementerat |
| Space | Quick Look | Nästa — @SearchPreviewEngineer |

\* SwiftUI `KeyEquivalent` saknar F5/F6; Cmd+5/Cmd+6 används tills
AppKit key-down-hantering läggs till. Knapptexterna behåller F5/F6.

## Regler

- Aktiv panel markeras med accentfärgad ram och header-bakgrund.
- Varje panel har oberoende navigation, markering och view-mode.
- Drop-mål markeras med accentram + tonad bakgrund under draget.
- Pågående filoperation visar etikett + procent + linjär progress i panelens fot.

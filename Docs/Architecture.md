# Twin — Arkitektur & best practice

## Lager

```
TwinApp (SwiftUI)          UI endast: vyer, fokus, sheets, drag/drop-presentation
  ├─ import TwinCore       all fillogik: koordination, bokmärken, storlekar,
  │                        behörigheter, packa/kryptera/MD5, organisering
  └─ import TwinPro        StoreKit 2: produkt, köp, entitlement, Pro-grind
FinderSyncExtension        tunn: meny/toolbar → twin:// till appen
```

Regler:

- **Ingen fillogik i vyer.** `PaneViewModel` delegerar: batch-kopiering är
  `FileCoordinatorService.batchCopyMove` (AsyncThrowingStream av
  `BatchEvent`), storlekar är `DirectorySizeService` (actor + cache),
  behörigheter är `FilePermissionService`, arkiv är `ArchiveService`.
- **Paket på riktigt.** `Package.swift` (paketet Twin) bygger TwinCore och
  TwinPro som bibliotek. Appen länkar produkterna via project.yml
  (`packages: Twin: path: .`) — källfilerna kompileras aldrig in dubbelt.
- **Concurrency:** UI-state är `@MainActor`. Tjänster som delas är actor
  (`DirectorySizeService`) eller `Sendable` med lås (`BookmarkStore`,
  `ProFeatureGate`). Tunga filoperationer körs aldrig på MainActor utom
  per-item via koordinatorn i batch-strömmen.
- **Delade vyer bor i `Sources/TwinApp/Shared/`** (BreadcrumbBar,
  FileItemIcon) och används av alla paneler/dialoger. Ingen kopierad
  breadcrumb- eller ikon-kod per vy.
- **Fel är data.** `DirectoryLoadState` klassificerar tom/nekad/borta
  en gång i TwinCore; vyn bara presenterar.
- **Säkerhet:** radera = papperskorg med bekräftelse; kopiering skriver
  aldrig över tyst (konflikter hoppas över och rapporteras av tjänsten).

## Tester

`Tests/TwinCoreTests` körs med `swift test` och i CI. Tjänster i TwinCore
ska ha tester; vyer verifieras live i appen (se UX-Review för metoden).

## Bygge

`project.yml` är enda källan. `xcodegen generate` → `xcodebuild`.
Xcode används bara för arkivering (`Scripts/archive.sh`).

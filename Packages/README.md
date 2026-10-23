# Packages

TwinCore is the logic package. It currently lives at the repo root via
`Package.swift` (target path `Sources/TwinCore`) so both SwiftPM (`swift build`)
and XcodeGen (`project.yml` → `Sources/TwinCore`) consume the same sources
without duplication.

Future local packages (e.g. a StoreKit package extracted from `TwinPro`)
go in this folder as `Packages/<Name>/Package.swift` and must be registered
in `project.yml` in the same commit.

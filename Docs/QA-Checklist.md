# Twin — App Store QA-checklista (LeadQA)

[LeadQA -> ProductOwner]: Check inför arkivering. Uppdateras av @QAEngineer.

## Bygg & verktyg

- [x] `./Scripts/generate.sh` grön (XcodeGen från project.yml)
- [x] `./Scripts/build.sh` — `BUILD SUCCEEDED` (scheme Twin, macOS)
- [x] `swift build` grön (TwinCore Swift Package)
- [ ] SwiftLint — ej installerat på denna maskin (`brew install swiftlint`), kör före release
- [x] Ingen `*.xcodeproj` trackad i git (`git ls-files | grep xcodeproj` tom)

## Sandbox & entitlements

- [x] `com.apple.security.app-sandbox` på (TwinApp + FinderSyncExtension)
- [x] Endast App Store-kompatibla nycklar: `files.user-selected.read-write`,
      `files.bookmarks.app-scope`, `files.bookmarks.document-scope`
- [x] Inga privata entitlements

## Privacy & metadata

- [x] `Sources/TwinApp/PrivacyInfo.xcprivacy` — ingen tracking, inga insamlade
      datatyper, UserDefaults (CA92.1) + FileTimestamp (C617.1) deklarerade
- [x] `twin://` URL-scheme registrerad via project.yml (överlever generate.sh)
- [x] StoreKit: `Configuration.storekit` med `com.anderselmen.twin.pro`

## Kvar före submit

- [ ] Hardened runtime vid arkivering (Xcode Archive, endast där)
- [ ] App Store Connect: produkt `com.anderselmen.twin.pro`, pris 249 kr (launch 149 kr)
- [ ] Screenshots enligt README-sektionen "Screenshots"

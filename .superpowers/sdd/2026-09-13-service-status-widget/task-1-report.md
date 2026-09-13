# Task 1 Report: Project Skeleton and Normalized Domain Model

## Implementation

- Added `project.yml` for XcodeGen with Swift 6/macOS 15.0 targets: dynamic `PSSCore` framework, `PSS` macOS app, embedded `PSSWidget` extension, and `PSSCoreTests` with copied `PSSTests/Fixtures` resources.
- Added product and framework `Info.plist` files plus app/widget sandbox App Group entitlements for `group.com.sergeykuzmich.pss`.
- Added compilable placeholder `MenuBarExtra` app and WidgetKit timeline widget. The placeholder uses `StatusSnapshot.unknown(at:)`.
- Added normalized public domain types in `Shared`: catalog-ordered `Service`, exact presentation/severity `ServiceState`, `ServiceStatus`, and a `StatusSnapshot` that normalizes to exactly one status per catalog service. Service supplies display names, official status page URLs, and adapter configuration for later providers.
- Added focused XCTest coverage in `PSSTests/ServiceStateTests.swift`.
- Installed XcodeGen 2.46.0 via Homebrew because it was absent.

## Commands and Results

1. `brew install xcodegen` — succeeded; XcodeGen 2.46.0 installed.
2. `xcodegen generate` — succeeded; generated `PSS.xcodeproj`.
3. RED: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/ServiceStateTests` — failed as expected while domain models were absent. Initial framework compilation was enabled with a temporary empty framework symbol; the decisive RED then failed at `StatusWidget.swift: cannot find type 'StatusSnapshot' in scope`.
4. GREEN: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/ServiceStateTests` — passed: 3 tests, 0 failures.
5. Build: `xcodebuild build -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS'` — `BUILD SUCCEEDED`; app, framework, and embedded widget build.
6. `git diff --check` — passed with no whitespace errors.

## RED/GREEN Evidence

- **RED:** Model-free build failed because `StatusSnapshot` was unavailable to the required placeholder widget entry point. This confirms the project required the domain foundation before it could compile.
- **GREEN:** `ServiceStateTests` passed all required behavioral checks: distinct labels/symbols, stable seven-service catalog ordering, and Unknown severity distinct from Outage.

## Files

- `project.yml`
- `PSS/Info.plist`, `PSS/PSS.entitlements`, `PSS/PSSApp.swift`
- `PSSCore/Info.plist`
- `PSSWidget/Info.plist`, `PSSWidget/PSSWidget.entitlements`, `PSSWidget/PSSWidgetBundle.swift`, `PSSWidget/StatusWidget.swift`
- `Shared/Service.swift`, `Shared/ServiceState.swift`, `Shared/ServiceStatus.swift`
- `PSSTests/ServiceStateTests.swift`, `PSSTests/Fixtures/.gitkeep`
- Generated `PSS.xcodeproj/`

## Self-Review

- Confirmed exact state labels, symbols, and severities from the task brief.
- Confirmed catalog order and all requested bundle IDs/App Group values.
- Confirmed every `StatusSnapshot` is normalized against `Service.allCases`, filling missing services with Unknown and preventing duplicate status rows from changing the catalog shape.
- Confirmed `PSSCore` is embedded in the app; without this Xcode's framework validation correctly failed, and the project metadata was fixed before final GREEN verification.

## Concerns

- Xcode build/test emits Xcode's standard ambiguous macOS destination warning because both arm64 and x86_64 destinations are visible; it does not affect the successful selected arm64 build.
- Status URLs and adapter configurations are intentionally foundations for Tasks 2–5; no network access or parsing is implemented in this task.

## Fix Round: Review Findings

### Changes

- Added sandbox App Group entitlement `group.com.sergeykuzmich.pss` to `PSS/PSS.entitlements` and `PSSWidget/PSSWidget.entitlements`.
- Added the WidgetKit extension declaration in `PSSWidget/Info.plist`: `NSExtension` / `NSExtensionPointIdentifier` = `com.apple.widgetkit-extension`.
- Added custom `StatusSnapshot` decoding in `Shared/ServiceStatus.swift`; decoded statuses now route through `init(updatedAt:statuses:)`, preserving catalog order, filling omitted services as Unknown, and retaining the first of duplicate service entries.
- Extended `PSSTests/ServiceStateTests.swift` with `testDecodingNormalizesMissingAndDuplicateServiceStatuses`.

### RED/GREEN Evidence

- **RED:** `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/ServiceStateTests` failed as expected before custom decoding: decoded services were `[github, github]`, rather than the full catalog, and missing services were not Unknown.
- **GREEN:** After custom decoding, the same command passed: `Executed 4 tests, with 0 failures` and `** TEST SUCCEEDED **`.

### Verification Commands and Results

1. `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/ServiceStateTests` — passed: `Executed 4 tests, with 0 failures` / `** TEST SUCCEEDED **`.
2. `xcodebuild build -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS'` — `** BUILD SUCCEEDED **`.
3. `plutil -lint PSS/PSS.entitlements PSSWidget/PSSWidget.entitlements PSSWidget/Info.plist` — all three files reported `OK`.
4. `git diff --check` — passed with no output.

### Test Coverage

- `PSSTests/ServiceStateTests.swift`: verifies decoded snapshots normalize duplicate `github` rows to the first entry, fill each remaining catalog service as Unknown, and retain catalog order.

### Concerns

- Xcode continues to emit its standard ambiguous macOS destination warning because arm64 and x86_64 are both available; the selected arm64 test and build completed successfully.

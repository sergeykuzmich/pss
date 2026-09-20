# Service Status Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS 15 menu-bar app and WidgetKit extension that display monochrome, textual status rows for seven public services.

**Architecture:** Shared Swift source defines service models, provider adapters, concurrent refresh, and an App Group JSON cache. The menu-bar app fetches live status and writes the cache; the widget reads the cache and requests periodic timelines. Provider-specific parsing is isolated behind one protocol so malformed or changed upstream data affects only one row.

**Tech Stack:** Swift 6, SwiftUI, WidgetKit, Foundation (`URLSession`, `JSONDecoder`, `XMLParser`), XCTest, XcodeGen for deterministic project generation.

**Spec:** `docs/superpowers/specs/2026-09-13-service-status-widget-design.md`

## Global Constraints

- Deployment target is macOS 15.0.
- Ship both a `MenuBarExtra` app and medium/large WidgetKit widget.
- Display GitHub, OpenAI, Claude, AWS, Grok, DeepSeek, and Cursor in that stable order.
- Use text and monochrome SF Symbols; never rely on color to convey status.
- Normalized states are Operational, Maintenance, Minor disruption, Major disruption, Outage, and Unknown.
- A provider fetch or parse failure maps only that provider to Unknown and never to Outage.
- Clicking a row opens the provider's official status page.
- Use only Apple runtime frameworks and no third-party application dependencies.
- Do not add notifications, incident history UI, provider configuration, analytics, or custom refresh intervals.

## File Structure

- `project.yml`: XcodeGen definition for shared framework, app, widget extension, App Group, test resources, and deployment settings.
- `PSS/Info.plist`, `PSS/PSS.entitlements`: app metadata and App Group entitlement.
- `PSS/PSSApp.swift`: menu-bar app entry point.
- `PSS/MenuBarContentView.swift`: compact status list, refresh control, and update timestamp.
- `PSSWidget/Info.plist`, `PSSWidget/PSSWidget.entitlements`: widget metadata and App Group entitlement.
- `PSSWidget/PSSWidgetBundle.swift`: extension entry point.
- `PSSWidget/StatusWidget.swift`: timeline provider and widget configuration.
- `Shared/Service.swift`: stable provider catalog and public URLs.
- `Shared/ServiceState.swift`: normalized states, copy, symbols, and severity order.
- `Shared/ServiceStatus.swift`: status row and cached snapshot models.
- `Shared/StatusProvider.swift`: provider protocol and HTTP transport boundary.
- `Shared/StatuspageProvider.swift`: JSON adapter for GitHub, OpenAI, Claude, and Cursor.
- `Shared/FeedProvider.swift`: RSS adapter for Grok and DeepSeek.
- `Shared/AWSProvider.swift`: UTF-16 JSON adapter for AWS current events.
- `Shared/StatusClient.swift`: concurrent orchestration and stable ordering.
- `Shared/StatusCache.swift`: atomic App Group JSON persistence.
- `Shared/StatusStore.swift`: app observable state, refresh coalescing, cache updates, widget reload.
- `Shared/StatusRowView.swift`: reusable monochrome row UI.
- `PSSTests/*.swift`: model, provider, client, and cache unit tests.
- `PSSTests/Fixtures/*`: representative upstream payloads.

---

### Task 1: Project Skeleton and Normalized Domain Model

**Files:**
- Create: `project.yml`
- Create: `PSS/Info.plist`
- Create: `PSS/PSS.entitlements`
- Create: `PSSWidget/Info.plist`
- Create: `PSSWidget/PSSWidget.entitlements`
- Create: `PSS/PSSApp.swift`
- Create: `PSSWidget/PSSWidgetBundle.swift`
- Create: `PSSWidget/StatusWidget.swift`
- Create: `Shared/Service.swift`
- Create: `Shared/ServiceState.swift`
- Create: `Shared/ServiceStatus.swift`
- Test: `PSSTests/ServiceStateTests.swift`

**Interfaces:**
- Produces: `enum Service: String, CaseIterable, Codable, Identifiable`
- Produces: `enum ServiceState: String, Codable, CaseIterable` with `label`, `symbolName`, and `severity`
- Produces: `struct ServiceStatus: Codable, Equatable, Identifiable`
- Produces: `struct StatusSnapshot: Codable, Equatable`

- [ ] **Step 1: Define the generated Xcode project and target metadata**

Create `project.yml` with four targets: `PSSCore` dynamic framework from `Shared/`, `PSS` app, `PSSWidget` app extension, and `PSSCoreTests` unit tests with `PSSTests/Fixtures` copied as test resources. Set `MACOSX_DEPLOYMENT_TARGET: 15.0`, Swift 6, bundle IDs `com.sergeykuzmich.pss`, `com.sergeykuzmich.pss.widget`, and `com.sergeykuzmich.pss.core`, and App Group `group.com.sergeykuzmich.pss` in both product entitlements. Make both products depend on `PSSCore`, make tests depend on `PSSCore` with `@testable import PSSCore`, and make the app embed the widget extension. Add minimal compilable `@main` app and widget entries in this task: the app shows a static `MenuBarExtra`, while `StatusWidget` uses a placeholder timeline entry with `StatusSnapshot.unknown(at:)`. Later tasks replace only their view/provider bodies.

- [ ] **Step 2: Write failing normalized-state tests**

```swift
import XCTest
@testable import PSSCore

final class ServiceStateTests: XCTestCase {
    func testEveryStateHasDistinctAccessiblePresentation() {
        XCTAssertEqual(Set(ServiceState.allCases.map(\.label)).count, ServiceState.allCases.count)
        XCTAssertEqual(Set(ServiceState.allCases.map(\.symbolName)).count, ServiceState.allCases.count)
    }

    func testProviderCatalogHasStableOrder() {
        XCTAssertEqual(Service.allCases, [.github, .openAI, .claude, .aws, .grok, .deepSeek, .cursor])
    }

    func testUnknownIsNotAnOutage() {
        XCTAssertNotEqual(ServiceState.unknown.severity, ServiceState.outage.severity)
    }
}
```

- [ ] **Step 3: Generate the project and verify tests fail**

Run: `xcodegen generate && xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/ServiceStateTests`

Expected: compilation fails because `Service`, `ServiceState`, and status models do not exist.

- [ ] **Step 4: Implement the domain model**

Define the exact states and presentation:

```swift
enum ServiceState: String, Codable, CaseIterable {
    case operational, maintenance, minorDisruption, majorDisruption, outage, unknown

    var label: String {
        switch self {
        case .operational: "Operational"
        case .maintenance: "Maintenance"
        case .minorDisruption: "Minor disruption"
        case .majorDisruption: "Major disruption"
        case .outage: "Outage"
        case .unknown: "Unknown"
        }
    }

    var symbolName: String {
        switch self {
        case .operational: "checkmark.circle"
        case .maintenance: "wrench.and.screwdriver"
        case .minorDisruption: "exclamationmark.circle"
        case .majorDisruption: "exclamationmark.triangle"
        case .outage: "xmark.octagon"
        case .unknown: "questionmark.circle"
        }
    }

    var severity: Int {
        switch self {
        case .operational: 0
        case .maintenance: 1
        case .minorDisruption: 2
        case .majorDisruption: 3
        case .outage: 4
        case .unknown: -1
        }
    }
}
```

`Service` supplies `displayName`, `statusPageURL`, and adapter configuration. `ServiceStatus` contains `service`, `state`, and optional upstream `detail`. `StatusSnapshot` contains `updatedAt` and exactly one status per catalog service. Add `StatusSnapshot.unknown(at:)` for cold-start display.

- [ ] **Step 5: Run tests and build both targets**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/ServiceStateTests && xcodebuild build -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS'`

Expected: tests pass and app plus embedded widget compile.

- [ ] **Step 6: Commit the domain foundation**

```bash
git add project.yml PSS PSSWidget Shared PSSTests PSS.xcodeproj
git commit -m "feat: scaffold macOS status app"
```

---

### Task 2: Statuspage JSON Providers

**Files:**
- Create: `Shared/StatusProvider.swift`
- Create: `Shared/StatuspageProvider.swift`
- Test: `PSSTests/StatuspageProviderTests.swift`
- Create: `PSSTests/Fixtures/statuspage-none.json`
- Create: `PSSTests/Fixtures/statuspage-minor.json`
- Create: `PSSTests/Fixtures/statuspage-major.json`
- Create: `PSSTests/Fixtures/statuspage-critical.json`

**Interfaces:**
- Produces: `protocol HTTPTransport: Sendable { func data(from url: URL) async throws -> (Data, HTTPURLResponse) }`
- Produces: `struct URLSessionTransport: HTTPTransport` configured with a 10-second request/resource timeout
- Produces: `protocol StatusProvider: Sendable { var service: Service { get }; func fetch(using transport: any HTTPTransport) async throws -> ServiceStatus }`
- Produces: `struct StatuspageProvider: StatusProvider`

- [ ] **Step 1: Write failing mapping and response-validation tests**

Test these exact mappings: `none -> operational`, `maintenance -> maintenance`, `minor -> minorDisruption`, `major -> majorDisruption`, `critical -> outage`, unknown indicator -> `unknown`. Also test non-2xx, malformed JSON, and `URLError(.timedOut)` throw rather than manufacture an outage. Instantiate each of the four concrete provider configurations and assert its service and endpoint so GitHub, OpenAI, Claude, and Cursor are all covered.

```swift
func testMinorMapsToMinorDisruption() async throws {
    let provider = StatuspageProvider(service: .claude, endpoint: fixtureURL)
    let status = try await provider.fetch(using: StubTransport(data: fixture("statuspage-minor"), statusCode: 200))
    XCTAssertEqual(status.state, .minorDisruption)
}
```

- [ ] **Step 2: Run the focused tests and observe failure**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/StatuspageProviderTests`

Expected: compilation fails because provider protocols and adapter do not exist.

- [ ] **Step 3: Implement transport validation and Statuspage decoding**

Decode only:

```swift
private struct Payload: Decodable {
    struct Status: Decodable { let indicator: String; let description: String }
    let status: Status
}
```

Implement `URLSessionTransport` with an ephemeral `URLSessionConfiguration` whose `timeoutIntervalForRequest` and `timeoutIntervalForResource` are both 10 seconds. Validate `200...299`, decode with `JSONDecoder`, and map indicators using an exhaustive switch with default `.unknown`. Configure endpoints:

- GitHub: `https://www.githubstatus.com/api/v2/status.json`
- OpenAI: `https://status.openai.com/api/v2/status.json`
- Claude: `https://status.claude.com/api/v2/status.json`
- Cursor: `https://status.cursor.com/api/v2/status.json`

- [ ] **Step 4: Run focused provider tests**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/StatuspageProviderTests`

Expected: all Statuspage tests pass.

- [ ] **Step 5: Commit Statuspage support**

```bash
git add Shared/StatusProvider.swift Shared/StatuspageProvider.swift PSSTests
 git commit -m "feat: fetch Statuspage service states"
```

---

### Task 3: RSS Providers for Grok and DeepSeek

**Files:**
- Create: `Shared/FeedProvider.swift`
- Test: `PSSTests/FeedProviderTests.swift`
- Create: `PSSTests/Fixtures/xai-active-major.xml`
- Create: `PSSTests/Fixtures/xai-resolved.xml`
- Create: `PSSTests/Fixtures/deepseek-active.xml`
- Create: `PSSTests/Fixtures/deepseek-resolved.xml`

**Interfaces:**
- Consumes: `StatusProvider`, `HTTPTransport`, `ServiceStatus`
- Produces: `struct FeedProvider: StatusProvider`
- Produces: `enum FeedKind { case xAI(productPath: String), flashDuty }`

- [ ] **Step 1: Write failing XML feed tests**

For xAI, only items whose link contains `/grok-com/` participate because the requested URL is specifically Grok Web, not the separate iOS/Android/API products. Ignore items containing `Status: RESOLVED`. Map active severity/category text containing `outage`, `critical`, or `unavailable` to Outage; `major` to Major disruption; `degraded`, `partial`, or `minor` to Minor disruption; `maintenance` to Maintenance. For DeepSeek, parse `feed.rss`; ignore descriptions whose status is `resolved` and use active title/description keywords with the same conservative mapping. An empty feed means Operational; malformed XML and `URLError(.timedOut)` throw.

- [ ] **Step 2: Verify the tests fail**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/FeedProviderTests`

Expected: compilation fails because `FeedProvider` does not exist.

- [ ] **Step 3: Implement the minimal Foundation XML parser**

Use an `XMLParserDelegate` that collects each item's title, link, description, and categories. Decode XML entities through `XMLParser`; lowercase text for keyword matching. Choose the maximum active severity and preserve the first matching title as `detail`.

Configure:

- Grok: `https://status.x.ai/feed.xml`, filter `/grok-com/`
- DeepSeek: `https://status.deepseek.com/feed.rss`

- [ ] **Step 4: Run RSS tests**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/FeedProviderTests`

Expected: all feed adapter tests pass.

- [ ] **Step 5: Commit feed providers**

```bash
git add Shared/FeedProvider.swift PSSTests
 git commit -m "feat: fetch Grok and DeepSeek status feeds"
```

---

### Task 4: AWS Current Events Provider

**Files:**
- Create: `Shared/AWSProvider.swift`
- Test: `PSSTests/AWSProviderTests.swift`
- Create: `PSSTests/Fixtures/aws-no-events.json`
- Create: `PSSTests/Fixtures/aws-current-events.json`

**Interfaces:**
- Consumes: `StatusProvider`, `HTTPTransport`, `ServiceStatus`
- Produces: `struct AWSProvider: StatusProvider`

- [ ] **Step 1: Write failing AWS tests**

Test UTF-16 big-endian response decoding from `https://health.aws.amazon.com/public/currentevents`. Empty array maps to Operational. Events with status/event-log status indicating investigation map to Minor disruption, events describing broad increased errors map to Major disruption, and explicit service disruption/outage maps to Outage. Malformed encoding or JSON throws.

```swift
func testEmptyEventListIsOperational() async throws {
    let data = "[]".data(using: .utf16BigEndian)!
    let status = try await AWSProvider().fetch(using: StubTransport(data: data, statusCode: 200))
    XCTAssertEqual(status.state, .operational)
}
```

- [ ] **Step 2: Verify AWS tests fail**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/AWSProviderTests`

Expected: compilation fails because `AWSProvider` does not exist.

- [ ] **Step 3: Implement UTF-16 decoding and conservative event mapping**

Detect a UTF-16 BOM, otherwise try UTF-16 big-endian before UTF-8. Decode these exact minimal structures:

```swift
private struct Event: Decodable {
    let status: String
    let serviceName: String?
    let summary: String
    let eventLog: [Log]

    enum CodingKeys: String, CodingKey {
        case status, summary
        case serviceName = "service_name"
        case eventLog = "event_log"
    }
}

private struct Log: Decodable {
    let summary: String
    let message: String
    let status: Int
}
```

Combine current event text, map explicit `outage`/`disruption` to Outage, `increased error` affecting `Multiple services` to Major disruption, other returned current operational issues to Minor disruption, and no events to Operational. Add a timeout test that confirms `URLError(.timedOut)` is propagated.

- [ ] **Step 4: Run AWS tests**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/AWSProviderTests`

Expected: all AWS provider tests pass.

- [ ] **Step 5: Commit AWS support**

```bash
git add Shared/AWSProvider.swift PSSTests
 git commit -m "feat: fetch AWS public health events"
```

---

### Task 5: Concurrent Client and Shared Cache

**Files:**
- Create: `Shared/StatusClient.swift`
- Create: `Shared/StatusCache.swift`
- Test: `PSSTests/StatusClientTests.swift`
- Test: `PSSTests/StatusCacheTests.swift`

**Interfaces:**
- Consumes: `[any StatusProvider]`, `HTTPTransport`, `StatusSnapshot`
- Produces: `struct StatusClient: Sendable { init(providers: [any StatusProvider] = ProviderFactory.live, transport: any HTTPTransport = URLSessionTransport()); func fetchAll(at date: Date = .now) async -> StatusSnapshot }`
- Produces: `enum ProviderFactory { static let live: [any StatusProvider] }` containing all seven configured adapters
- Produces: `struct StatusCache: Sendable { func load() -> StatusSnapshot?; func save(_ snapshot: StatusSnapshot) throws }`

- [ ] **Step 1: Write failing orchestration tests**

Test that providers execute concurrently, output order always follows `Service.allCases`, one thrown provider becomes Unknown while successful rows survive, and every catalog service appears exactly once.

- [ ] **Step 2: Write failing cache tests**

Inject a temporary directory into `StatusCache`. Test round-trip JSON, missing file returns nil, corrupt file returns nil, and save replaces the previous complete snapshot atomically.

- [ ] **Step 3: Run tests and verify failure**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/StatusClientTests -only-testing:PSSCoreTests/StatusCacheTests`

Expected: compilation fails because client and cache do not exist.

- [ ] **Step 4: Implement concurrent fetch with task groups**

Create `ProviderFactory.live` with four `StatuspageProvider`s, two `FeedProvider`s, and one `AWSProvider`. Create one task per provider. All domain structs and concrete providers conform to `Sendable`; transport/provider existential properties are declared `any ... & Sendable` where captured. Catch errors inside each child task and return `ServiceStatus(service: provider.service, state: .unknown)`. Reassemble by `Service.allCases`, filling any missing service with Unknown.

- [ ] **Step 5: Implement App Group cache**

Default directory is `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.sergeykuzmich.pss")`; tests inject another URL. Encode ISO-8601 dates and use `Data.write(options: .atomic)`. Loading catches read/decode errors and returns nil.

- [ ] **Step 6: Run client and cache tests**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/StatusClientTests -only-testing:PSSCoreTests/StatusCacheTests`

Expected: focused tests pass.

- [ ] **Step 7: Commit orchestration and cache**

```bash
git add Shared/StatusClient.swift Shared/StatusCache.swift PSSTests
 git commit -m "feat: refresh and cache service snapshots"
```

---

### Task 6: Menu-Bar Application

**Files:**
- Create: `Shared/StatusStore.swift`
- Create: `Shared/StatusRowView.swift`
- Create: `PSS/PSSApp.swift`
- Create: `PSS/MenuBarContentView.swift`
- Test: `PSSTests/StatusStoreTests.swift`

**Interfaces:**
- Consumes: `StatusClient`, `StatusCache`, `StatusSnapshot`
- Produces: `@MainActor final class StatusStore: ObservableObject`
- Produces: `struct StatusRowView: View`

- [ ] **Step 1: Write failing store tests**

Inject fake client/cache closures. Test initial state uses cache or unknown snapshot, refresh updates rows and timestamp, refresh saves the snapshot, and a second simultaneous refresh reuses the active task rather than fetching twice.

- [ ] **Step 2: Verify store tests fail**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/StatusStoreTests`

Expected: compilation fails because `StatusStore` does not exist.

- [ ] **Step 3: Implement observable refresh state**

Expose read-only `snapshot` and `isRefreshing`. On successful aggregate completion, update on the main actor, save cache, and call `WidgetCenter.shared.reloadAllTimelines()`. Coalesce refresh calls behind one stored `Task`.

- [ ] **Step 4: Implement the menu-bar UI**

Use `MenuBarExtra("Service Status", systemImage: worstState.symbolName) { MenuBarContentView(store: store) }`. The panel is approximately 320 points wide and contains seven `Link` rows, a divider, “Updated …” text, Refresh button/spinner, and Quit. `StatusRowView` uses `.foregroundStyle(.primary)` for both symbol and text and combines accessibility into “Provider, state”. Trigger refresh on launch and when the panel content appears.

- [ ] **Step 5: Run store tests and app build**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/StatusStoreTests && xcodebuild build -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS'`

Expected: tests pass and app builds.

- [ ] **Step 6: Commit the menu-bar app**

```bash
git add Shared/StatusStore.swift Shared/StatusRowView.swift PSS PSSTests
 git commit -m "feat: add service status menu bar"
```

---

### Task 7: WidgetKit Extension

**Files:**
- Modify: `PSSWidget/PSSWidgetBundle.swift`
- Modify: `PSSWidget/StatusWidget.swift`
- Create: `Shared/WidgetSnapshotLoader.swift`
- Test: `PSSTests/WidgetSnapshotTests.swift`

**Interfaces:**
- Consumes: `StatusCache`, `StatusSnapshot`, `StatusRowView`
- Produces in `PSSCore`: `enum WidgetSnapshotLoader { static func snapshot(cache: StatusCache, now: Date) -> StatusSnapshot }`
- Produces in `PSSWidget`: `struct StatusTimelineProvider: TimelineProvider`
- Produces in `PSSWidget`: `struct StatusWidget: Widget`

- [ ] **Step 1: Write failing widget snapshot-selection tests**

Create the pure helper in the shared `PSSCore` framework and test `WidgetSnapshotLoader.snapshot(cache:now:)`: cached value is returned unchanged; missing/corrupt cache yields seven Unknown rows stamped with `now`.

- [ ] **Step 2: Verify widget helper tests fail**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/WidgetSnapshotTests`

Expected: compilation fails because the widget snapshot helper does not exist.

- [ ] **Step 3: Implement timeline behavior**

The provider loads the App Group cache for placeholder, snapshot, and timeline. Schedule the next timeline refresh with `.after(Date().addingTimeInterval(15 * 60))`. Network fetching remains in the app/shared client; the widget presents the latest cache and WidgetKit controls actual refresh timing.

- [ ] **Step 4: Implement medium and large widget layouts**

Support only `.systemMedium` and `.systemLarge`. Render all seven link rows using `Link(destination:)`. Use compact 4-point row spacing for medium and 8-point spacing for large. Apply `.containerBackground(.background, for: .widget)` and no status colors. Add previews for Operational, mixed disruptions, Outage, and Unknown in both families.

- [ ] **Step 5: Run widget tests and build**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/WidgetSnapshotTests && xcodebuild build -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS'`

Expected: tests pass and both product targets build.

- [ ] **Step 6: Commit WidgetKit support**

```bash
git add PSSWidget PSSTests
 git commit -m "feat: add service status widgets"
```

---

### Task 8: End-to-End Verification and Documentation

**Files:**
- Modify: `README.md`
- Verify: all source and tests

**Interfaces:**
- Consumes: complete app, widget, test suite
- Produces: documented, buildable first release

- [ ] **Step 1: Document setup and behavior**

Update README with macOS 15 requirement, `brew install xcodegen`, `xcodegen generate`, Xcode run instructions, listed providers, widget installation steps, refresh limitations imposed by WidgetKit, and the monochrome status legend.

- [ ] **Step 2: Generate a clean project**

Run: `rm -rf PSS.xcodeproj && xcodegen generate`

Expected: `PSS.xcodeproj` regenerates without warnings or missing paths.

- [ ] **Step 3: Run the complete test suite**

Run: `xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS'`

Expected: all tests pass with zero failures.

- [ ] **Step 4: Build a Release configuration**

Run: `xcodebuild build -project PSS.xcodeproj -scheme PSS -configuration Release -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: `** BUILD SUCCEEDED **` for the app and embedded widget.

- [ ] **Step 5: Inspect repository state**

Run: `git status --short && git diff --check`

Expected: only intended documentation/source/project changes; no whitespace errors, fixtures generated at runtime, DerivedData, or temporary endpoint downloads.

- [ ] **Step 6: Commit final documentation**

```bash
git add README.md project.yml PSS.xcodeproj
git commit -m "docs: explain service status app setup"
```

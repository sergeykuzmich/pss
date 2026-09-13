# Task 7 Report: WidgetKit timelines/layout

## RED
Created `PSSTests/WidgetSnapshotTests.swift` first. After regenerating the Xcode project, the targeted command failed as expected because `WidgetSnapshotLoader` was not in scope:

```text
error: cannot find 'WidgetSnapshotLoader' in scope
** TEST FAILED **
```

## GREEN
Implemented `WidgetSnapshotLoader.snapshot(cache:now:)`, which returns a cached snapshot unchanged and normalizes missing or corrupt cache data to all-Unknown rows at `now`. Added a cache-backed `StatusTimelineProvider`, with 15-minute best-effort refreshes, and medium/large WidgetKit layouts that reuse `StatusRowView` for monochrome symbol, visible label/state, and status-page links. Added previews for operational, mixed disruption, outage, and unknown states across both families.

## Verification

```text
xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/WidgetSnapshotTests
Executed 3 tests, with 0 failures
** TEST SUCCEEDED **

xcodebuild build -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS'
** BUILD SUCCEEDED **
```

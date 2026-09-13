# Task 5: Concurrent Client and Shared Cache report

## Scope

Implemented the Sendable `StatusClient`, live seven-provider factory, and App Group-backed `StatusCache`, with strict unit coverage.

## RED evidence

1. Added `StatusClientTests` for concurrent execution, catalog-order reassembly, per-provider error isolation, and exactly-once catalog coverage. Added `StatusCacheTests` for round-trip JSON, absent/corrupt cache handling, and replacement saves.
2. Regenerated the Xcode project and ran:

   ```sh
   xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/StatusClientTests -only-testing:PSSCoreTests/StatusCacheTests
   ```

   The suite failed to compile with `cannot find 'StatusCache' in scope` (and the corresponding client symbol was absent), proving the required production interfaces did not exist.

## GREEN evidence

Implemented `Shared/StatusClient.swift` and `Shared/StatusCache.swift`, regenerated the project, and reran the focused command. It passed.

Final regression verification:

```sh
xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS'
```

Result:

```text
Executed 41 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

`git diff --check` also passed.

## Delivered behavior

- `ProviderFactory.live` supplies the four Statuspage adapters, Grok and DeepSeek feed adapters, and AWS adapter.
- `StatusClient.fetchAll` starts one task-group child for every provider and catches failures in that child, returning Unknown only for that provider.
- `StatusSnapshot` reassembles every result in stable `Service.allCases` order and fills omitted services as Unknown.
- `StatusClient`, providers, and transport capture paths satisfy Swift 6 Sendable constraints.
- `StatusCache` defaults to App Group `group.com.sergeykuzmich.pss`, uses ISO-8601 snapshot JSON, returns `nil` for unavailable/corrupt data, and writes complete replacements with `.atomic`.

## Review-fix RED/GREEN evidence

### RED

Added regressions for (1) delayed duplicate providers retaining the first configured result, (2) unavailable cache containers throwing `StatusCache.Error.containerUnavailable`, (3) fractional-second cache round trips, and (4) the seven canonical live providers and their concrete endpoints. Cache test directories are now per-test UUID paths and removed during teardown.

The focused test run first failed to compile because `StatusCache.Error` did not exist:

```text
error: 'Error' is not a member type of struct 'PSSCore.StatusCache'
```

After adding that API, the fractional-second test failed because the prior ISO-8601 strategy lost precision:

```text
XCTAssertEqual failed: loaded snapshot is not equal to the fractional-second snapshot
```

### GREEN

`StatusClient` now preserves each provider's configured index through its task group, then reorders results by that index before `StatusSnapshot` resolves duplicates. Fetching remains concurrent and duplicate services deterministically use the first configured provider.

`StatusCache.save` now throws `StatusCache.Error.containerUnavailable` without a container. It encodes and decodes dates as seconds since 1970, preserving fractional seconds; `load` still returns `nil` for unavailable, missing, corrupt, or unreadable data.

Fresh verification:

```sh
xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/StatusClientTests -only-testing:PSSCoreTests/StatusCacheTests
# Executed 12 tests, with 0 failures

xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS'
# Executed 45 tests, with 0 failures

git diff --check
# passed
```

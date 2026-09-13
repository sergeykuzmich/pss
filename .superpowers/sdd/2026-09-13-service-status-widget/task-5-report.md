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

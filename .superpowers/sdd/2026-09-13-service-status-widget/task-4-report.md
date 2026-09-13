# Task 4: AWS Current Events Provider report

## Scope

Implemented `AWSProvider`, the public AWS current-events status adapter, and fixture-driven coverage.

## RED evidence

1. Added `AWSProviderTests` with UTF-16BE empty-event, investigation, multi-service increased-error, service-disruption, malformed encoding/JSON, and timeout contracts. Generated the Xcode project and ran:

   ```sh
   xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/AWSProviderTests
   ```

   It failed at compilation with `cannot find 'AWSProvider' in scope`, proving the adapter was absent.

2. Added a UTF-8 fallback regression test. Before the decoding fix, the same focused suite failed at `testUTF8ResponseFallsBackWhenBigEndianDecodingIsNotJSON` with `DecodingError.dataCorrupted` because the bytes had been misinterpreted as UTF-16BE.

## GREEN evidence

After implementing the provider and correcting the fallback, the focused command above completed with:

```text
Executed 8 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

`git diff --check` also completed cleanly.

## Delivered behavior

- Fetches `https://health.aws.amazon.com/public/currentevents` for `.aws`.
- Rejects non-2xx responses and leaves transport errors, including `URLError(.timedOut)`, unmodified.
- Decodes BOM-marked UTF-16 (both byte orders), otherwise prioritizes valid UTF-16BE JSON and falls back to UTF-8.
- Decodes required AWS contract shapes: top-level string values and nested integer log status values.
- Maps no events to operational, explicit `outage`/`disruption` to outage, `increased error` plus `multiple services` to major disruption, and all other current events conservatively to minor disruption.
- Adds UTF-16BE JSON fixtures for empty and active AWS event lists.

## Task 4 review follow-up

### RED evidence

1. Added `testWhitespacePrefixedNonASCIIUTF16BigEndianResponseWithoutBOMDecodes`. Before the decoder change, focused AWS tests failed with `NSURLErrorDomain Code=-1016` because the no-BOM UTF-16BE candidate was identified only when its first decoded character was `[` or `{`.
2. Added `testMixedEventsDoNotCombineIncreasedErrorsAndMultipleServices`. Before event-local classification, focused AWS tests failed with `XCTAssertEqual failed: ("majorDisruption") is not equal to ("minorDisruption")`, proving text from distinct events had been combined.
3. Strengthened the timeout assertion to require `URLError.Code.timedOut` rather than merely any error.
4. Added `testUTF16BigEndianBOMResponseDecodes` and `testUTF16LittleEndianBOMResponseDecodes`, exercising both `FE FF` and intentional `FF FE` BOM branches.

Command:

```sh
xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' -only-testing:PSSCoreTests/AWSProviderTests
```

The RED run executed 11 tests with 2 failures: the mixed-event false escalation and the whitespace/non-ASCII no-BOM UTF-16BE rejection.

### GREEN evidence

- Decode each permitted encoding into UTF-8 and accept it only when `JSONSerialization` validates the candidate; this supports leading whitespace and non-ASCII UTF-16BE JSON without sacrificing UTF-8 fallback.
- Classify each AWS event individually, then select the highest `ServiceState` severity.
- Preserve the existing BOM-specific byte orders; FE FF and FF FE tests validate UTF-16BE and UTF-16LE BOM input.

The focused command above then executed **11 tests with 0 failures**.

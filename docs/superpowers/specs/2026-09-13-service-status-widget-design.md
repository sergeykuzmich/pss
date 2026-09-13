# Service Status Widget Design

## Goal

Build a native macOS 15 application that reports the current public status of GitHub, OpenAI, Claude, AWS, Grok, DeepSeek, and Cursor in both a menu-bar panel and WidgetKit widgets.

## User experience

The interface is intentionally compact. Each provider occupies one row containing:

1. A monochrome SF Symbol describing the state.
2. The provider name.
3. A short textual state.

Rows do not rely on color because macOS widgets may be tinted. Clicking a row opens that provider's official status page. The menu-bar panel mirrors the widget and adds a refresh button plus a last-updated timestamp.

The widget supports medium and large families. Both show one provider per line; the large family uses more generous spacing. If the available height is insufficient, rows remain readable rather than adding incident detail.

## Normalized states

| State | Suggested SF Symbol | Label |
|---|---|---|
| Operational | `checkmark.circle` | Operational |
| Maintenance | `wrench.and.screwdriver` | Maintenance |
| Minor disruption | `exclamationmark.circle` | Minor disruption |
| Major disruption | `exclamationmark.triangle` | Major disruption |
| Outage | `xmark.octagon` | Outage |
| Unknown | `questionmark.circle` | Unknown |

Symbols and labels communicate the complete meaning without color. Provider-specific status values map into this enum conservatively; unrecognized responses map to Unknown.

## Architecture

The Xcode project contains:

- **PSS app target:** a SwiftUI `MenuBarExtra` application with a small status panel.
- **PSSWidget extension:** WidgetKit timeline provider and medium/large widget views.
- **PSSCore shared code:** provider definitions, normalized models, HTTP clients/adapters, cache, and shared row views compiled into both targets.
- **PSSCoreTests:** deterministic unit tests using stored response fixtures and a mocked URL protocol.

Only Apple frameworks are used: SwiftUI, WidgetKit, Foundation, and AppIntents where required. No third-party dependencies are needed.

## Data acquisition

Each provider conforms to a small `StatusProvider` interface and returns one normalized `ServiceStatus` value. Requests run concurrently and failures are isolated per provider.

- GitHub, OpenAI, Claude, and Cursor use their public Statuspage-compatible JSON endpoints.
- Grok uses xAI's public status feed/page through a dedicated adapter.
- DeepSeek uses its public status page/feed through a dedicated adapter.
- AWS uses the public AWS Health status data through a dedicated adapter.

Adapters prefer documented or structured JSON/RSS feeds over HTML. HTML parsing is a last resort and is isolated so upstream changes only affect one provider. Every adapter has representative fixture tests.

## Refresh and caching

The app refreshes on launch, when the menu opens, and when the user presses Refresh. Requests use sensible timeouts and are coalesced so overlapping refreshes do not duplicate work.

After each refresh, the complete snapshot is encoded as JSON in an App Group container. The app requests `WidgetCenter.reloadTimelines` after updating the cache. The widget reads this cache and schedules a best-effort refresh approximately every 15 minutes; WidgetKit retains control over actual execution frequency.

A failed provider request produces Unknown for that refresh, as requested. Other providers continue displaying their current fetched states. If the whole refresh cannot start, the UI remains available and reports Unknown rather than implying an outage.

## Accessibility

Every row exposes a combined accessibility label such as “GitHub, operational.” Controls have textual labels and keyboard focus. Symbols are decorative when the combined label is present. Dynamic type-friendly SwiftUI text and native materials preserve legibility in standard, dark, high-contrast, and tinted presentations.

## Error handling

- Non-2xx responses, timeouts, malformed payloads, and schema changes map only the affected service to Unknown.
- Parsing never infers an outage from network failure.
- Unexpected provider values map to Unknown.
- The menu panel remains interactive during refresh and indicates progress with a native spinner.

## Testing

Unit tests cover:

- Every external status value to normalized-state mapping.
- Successful fixtures for all seven providers.
- Malformed, empty, non-2xx, and timeout responses.
- Independent failure when one provider fails.
- Cache encoding, decoding, and missing/corrupt cache behavior.
- Stable provider ordering.

A build check covers both the app and widget targets. SwiftUI previews provide visual inspection for all six normalized states and widget families.

## Out of scope

The first version does not include notifications, incident history, provider selection, reordering, user accounts, analytics, or configurable refresh intervals. These can be added later only if users need them.

# PSS

PSS is a macOS menu-bar app and WidgetKit widget that summarizes the current
status of commonly used developer and AI services. It requires **macOS 15.0 or
later** and Xcode with the **macOS 15 SDK or later**.

## Build and run

Install [XcodeGen](https://github.com/yonaskolb/XcodeGen), then generate the
Xcode project from the checked-in specification:

```sh
brew install xcodegen
xcodegen generate
open PSS.xcodeproj
```

In Xcode, select the **PSS** scheme and **My Mac**, then Run. The app appears in
the menu bar. For a command-line test build:

```sh
xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild build -project PSS.xcodeproj -scheme PSS -configuration Release \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

These are **unsigned compile-verification** commands only. For local Xcode Run
and widget testing, select a development team for both `PSS` and `PSSWidget` and
enable the `group.com.sergeykuzmich.pss` App Group capability for their App IDs.
Normal Xcode Run then signs the app and embedded widget with their assigned
entitlements. Distribution additionally requires the appropriate provisioning
and signing identity.

## Services and status

PSS reads each provider's public status source:

- GitHub, OpenAI, Claude, and Cursor: Statuspage APIs
- AWS: AWS Health status
- Grok Web only: xAI's status RSS feed, scoped to `/grok-com/` entries (not
  the broader Grok product or other xAI products)
- DeepSeek: its FlashDuty RSS feed

All status presentation is monochrome; the SF Symbol and text carry the meaning:

| Status | Symbol |
| --- | --- |
| Operational | `checkmark.circle` |
| Maintenance | `wrench.and.screwdriver` |
| Minor disruption | `exclamationmark.circle` |
| Major disruption | `exclamationmark.triangle` |
| Outage | `xmark.octagon` |
| Unknown | `questionmark.circle` |

A provider fetch failure is represented as **Unknown**; it does not mean the
provider is confirmed healthy or unavailable.

## Refreshing and the widget

PSS refreshes at launch. Select its menu-bar icon to present the status menu,
then choose **Refresh** for a manual refresh. The latest snapshot is cached in
the shared App Group container and the app asks WidgetKit to reload after a
successful refresh. Both the app and `PSSWidget`
must be signed with the same App Group entitlement:
`group.com.sergeykuzmich.pss`.

To add the widget, Control-click the desktop, choose **Edit Widgets**, find
**Service Status**, and add either the **medium** or **large** size. Widgets read
the cached snapshot; they do not fetch provider endpoints themselves. Their
timeline requests a refresh after 15 minutes, but WidgetKit schedules timeline
updates at its discretion, so it cannot guarantee exact refresh timing. Open
PSS and use Refresh whenever you need the newest available status.

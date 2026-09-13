# PSS

PSS is a macOS menu-bar app and WidgetKit widget that summarizes the current
status of commonly used developer and AI services. It requires **macOS 15.0 or
later** and Xcode with the macOS 15 SDK.

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
xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS'
xcodebuild build -project PSS.xcodeproj -scheme PSS -configuration Release \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

The included project configuration disables signing so the commands above work
for local verification. To distribute the app, configure a development or
Developer ID team and provisioning that enables the shared App Group described
below.

## Services and status

PSS reads each provider's public status source:

- GitHub, OpenAI, Claude, and Cursor: Statuspage APIs
- AWS: AWS Health status
- Grok: xAI's status RSS feed, scoped to entries for the **Grok** product (not
  other xAI products)
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

PSS refreshes when the app starts and when you choose **Refresh** from the menu.
The latest snapshot is cached in the shared App Group container and the app asks
WidgetKit to reload after a successful refresh. Both the app and `PSSWidget`
must be signed with the same App Group entitlement:
`group.com.sergeykuzmich.pss`.

To add the widget, Control-click the desktop, choose **Edit Widgets**, find
**Service Status**, and add either the **medium** or **large** size. Widgets read
the cached snapshot; they do not fetch provider endpoints themselves. Their
timeline requests a refresh after 15 minutes, but WidgetKit schedules timeline
updates at its discretion, so it cannot guarantee exact refresh timing. Open
PSS and use Refresh whenever you need the newest available status.

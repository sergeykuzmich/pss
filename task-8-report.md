# Task 8 review-finding verification

## Changes

- Removed the global `CODE_SIGNING_ALLOWED=NO` and `CODE_SIGNING_REQUIRED=NO` settings from `project.yml`, then regenerated `PSS.xcodeproj` with XcodeGen 2.46.0.
- Kept unsigned verification explicit in the README commands with `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`.
- Documented normal signed local Xcode Run/widget testing: select a development team for `PSS` and `PSSWidget`, and enable `group.com.sergeykuzmich.pss` for both App IDs.
- Clarified that the xAI feed is Grok Web only (`/grok-com/`), requires the macOS 15 SDK or later, and documented launch refresh, menu presentation, and manual **Refresh**.

## Verification evidence

All commands were run from the repository root on 2026-09-13 with Xcode 26.6 (build 17F113).

```text
$ xcodegen generate
Created project at .../PSS.xcodeproj

$ xcodebuild -project PSS.xcodeproj -scheme PSS -showBuildSettings -configuration Debug
CODE_SIGNING_ALLOWED = YES
CODE_SIGNING_REQUIRED = YES
CODE_SIGN_ENTITLEMENTS = PSS/PSS.entitlements
CODE_SIGNING_ALLOWED = YES
CODE_SIGNING_REQUIRED = YES
CODE_SIGN_ENTITLEMENTS = PSSWidget/PSSWidget.entitlements

$ xcodebuild test -project PSS.xcodeproj -scheme PSS -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
Executed 52 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **

$ xcodebuild build -project PSS.xcodeproj -scheme PSS -configuration Release -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
CODE_SIGNING_ALLOWED = NO
CODE_SIGNING_REQUIRED = NO
** BUILD SUCCEEDED **

$ test -d .../Release/PSS.app/Contents/PlugIns/PSSWidget.appex
embedded PSSWidget.appex: present

$ plutil -p .../Release/PSS.app/Contents/Info.plist
CFBundleIdentifier = com.sergeykuzmich.pss

$ plutil -p .../Release/PSS.app/Contents/PlugIns/PSSWidget.appex/Contents/Info.plist
CFBundleIdentifier = com.sergeykuzmich.pss.widget
NSExtensionPointIdentifier = com.apple.widgetkit-extension

$ plutil -p PSS/PSS.entitlements
com.apple.security.application-groups = [group.com.sergeykuzmich.pss]

$ plutil -p PSSWidget/PSSWidget.entitlements
com.apple.security.application-groups = [group.com.sergeykuzmich.pss]
```

The unsigned Release build uses ad-hoc signatures (`TeamIdentifier=not set`), as expected when the explicit unsigned flags are supplied. Normal Debug configuration leaves signing enabled and retains both assigned entitlement files for automatic development signing.

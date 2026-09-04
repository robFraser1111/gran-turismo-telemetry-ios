# SlickDash (iOS)

SwiftUI companion for **Gran Turismo 7** live telemetry.

Not affiliated with Sony Interactive Entertainment or Polyphony Digital.

The GitHub repo starts empty of an `.xcodeproj` binary; generate one on a Mac:

```bash
brew install xcodegen
cd gran-turismo-telemetry-ios
xcodegen generate
open SlickDash.xcodeproj
```

Find PS5 on launch. Simple is the default. Needs a device (or simulator for UI only) on the same LAN as the PS5. Local network permission is required.

Heartbeat UDP 33739, receive 33740.

## Crash reporting (Sentry)

Errors go to the `gran-telemetry-ios` project in org `robert-fraser`. The client DSN is baked in (public event-submit key only). Override with env `SENTRY_DSN` if needed. Do **not** commit Sentry org auth tokens, `.sentryclirc`, or dSYM-upload credentials. After `xcodegen generate`, resolve the `sentry-cocoa` SPM package in Xcode.

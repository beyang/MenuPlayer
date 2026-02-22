# Focus

## Building

Always build with the `FocusDev` self-signed certificate so that macOS Accessibility permissions persist across rebuilds:

```bash
xcodebuild -project Focus.xcodeproj -scheme Focus -configuration Debug \
  CODE_SIGN_IDENTITY="FocusDev" DEVELOPMENT_TEAM="" CODE_SIGN_STYLE="Manual" build
```

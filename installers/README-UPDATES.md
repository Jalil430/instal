Desktop auto-updates (macOS Sparkle, Windows WinSparkle) via Flutter `auto_updater`.

1) Generate keys

```
dart run auto_updater:generate_keys
```

- macOS: copy SUPublicEDKey into `macos/Runner/Info.plist` as `SUPublicEDKey`.
- Windows: place public key (e.g., `dsa_pub.pem`) and reference it from `windows/runner/Runner.rc` if required by your signing mode (see WinSparkle docs).

2) Build release and sign update files

```
flutter build macos --release
flutter build windows --release

# Sign update payloads and copy signature into appcast entries
dart run auto_updater:sign_update installers/dist/Instal-1.0.0.zip
dart run auto_updater:sign_update installers/dist/Instal-1.0.0-setup.exe
```

3) Publish appcasts and binaries

- Authoritative appcasts live in `docs/downloads/` (served by GitHub Pages):
  - macOS: `docs/downloads/mac/appcast-macos.xml`
  - Windows: `docs/downloads/win/appcast-windows.xml`
- Update those two files with the new URL, length, signature, version, and pubDate for every release.
- The `installers/appcast-*.xml` files were early templates and are not used. You may delete them.

4) App integration

- `lib/core/services/update_service.dart` sets the feed URL by platform and schedules checks.
- `lib/main.dart` initializes updater and performs an immediate check on startup.
- Settings screens expose a "Check for updates" button.

Notes
- macOS builds should be code signed and notarized to avoid gatekeeper prompts.
- Windows installers should be code signed for SmartScreen reputation.
- Keep separate feeds per platform/channel (stable/beta) if desired.



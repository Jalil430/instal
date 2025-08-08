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

- Update `installers/appcast-macos.xml` and `installers/appcast-windows.xml` with URLs, file sizes, and signatures.
- Upload both XML and binaries to your website paths configured in `UpdateService.initialize`.

4) App integration

- `lib/core/services/update_service.dart` sets the feed URL by platform and schedules checks.
- `lib/main.dart` initializes updater and performs an immediate check on startup.
- Settings screens expose a "Check for updates" button.

Notes
- macOS builds should be code signed and notarized to avoid gatekeeper prompts.
- Windows installers should be code signed for SmartScreen reputation.
- Keep separate feeds per platform/channel (stable/beta) if desired.



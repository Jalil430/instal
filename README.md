# instal_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Desktop Auto-Update (macOS + Windows)

This app uses Sparkle (macOS) and WinSparkle (Windows) via the Flutter `auto_updater` plugin to enable desktop auto-updates.

### Quick start

1) Keys
- Install Dart/Flutter
- Generate update keys (run on a trusted machine):

```bash
dart run auto_updater:generate_keys
```

- macOS: copy the printed `SUPublicEDKey` into `macos/Runner/Info.plist` under `SUPublicEDKey`.
- Windows: place the generated public key (e.g., `dsa_pub.pem`) in the repo and reference it in `windows/runner/Runner.rc` if required by your signing mode.

2) Feed URLs (GitHub Pages option)
- This repo can host appcasts via GitHub Pages using the `docs/` folder.
- macOS feed: `https://jalil430.github.io/instal/downloads/mac/appcast-macos.xml`
- Windows feed: `https://jalil430.github.io/instal/downloads/win/appcast-windows.xml`
- The app is configured in `lib/core/services/update_service.dart` and initialized in `lib/main.dart`.

3) Signing updates
- After building release artifacts, sign the files and capture the signature to include in your appcast entries:

```bash
dart run auto_updater:sign_update path/to/YourApp-macos.zip
dart run auto_updater:sign_update path/to/YourApp-windows-installer.exe
```

4) Appcast templates
- Publish an appcast per platform. Example item:

```xml
<item>
  <title>Version 1.0.1</title>
  <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
  <pubDate>Fri, 08 Aug 2025 07:50:00 GMT</pubDate>
  <enclosure url="https://yourdomain.com/downloads/mac/YourApp-1.0.1.zip"
             sparkle:edSignature="REPLACE_WITH_SIGNATURE"
             length="12345678"
             type="application/octet-stream" />
  <sparkle:releaseNotesLink>https://yourdomain.com/releases/1.0.1.html</sparkle:releaseNotesLink>
  <!-- Repeat a separate item for Windows using sparkle:dsaSignature and the Windows download URL. -->
  <!-- Ensure you host separate appcast files per platform, or separate channels if you prefer. -->
  <!-- For Windows appcast, use sparkle:dsaSignature (or the algorithm required by your WinSparkle build). -->
</item>
```

5) Build and upload
- Build release binaries for macOS and Windows, notarize/sign as needed.
- Upload binaries to GitHub Releases. Edit `docs/downloads/*/appcast-*.xml` to point to those release asset URLs and commit/push to update the feed.
- The app will check for updates on startup and every 24 hours, and the Settings screen includes a "Check for updates" button.

### Enable GitHub Pages (once)
1. Go to your repo on GitHub → Settings → Pages
2. Source: Deploy from a branch → Branch: `main` and folder: `/docs`
3. Save. Your site will be at `https://jalil430.github.io/instal/`
4. Feeds will be:
   - macOS: `https://jalil430.github.io/instal/downloads/mac/appcast-macos.xml`
   - Windows: `https://jalil430.github.io/instal/downloads/win/appcast-windows.xml`

# Instal App - Installation Guide

## macOS Installation

### Available Files
- `Instal-macOS-Installer-v1.0.0.dmg` - Professional installer with Applications folder shortcut

### Installation Steps
1. Download the `Instal-macOS-Installer-v1.0.0.dmg` file
2. Double-click the DMG file to mount it
3. Drag the "instal_app" application to the Applications folder
4. Eject the DMG file
5. Launch the app from Applications folder or Spotlight

### System Requirements
- macOS 10.14 or later
- 64-bit Intel or Apple Silicon Mac

## Windows Installation

### Building for Windows
Since this was built on macOS, the Windows version needs to be built on a Windows machine:

1. Install Flutter on Windows following the official guide
2. Clone the project repository
3. Run the following commands:
   ```cmd
   flutter clean
   flutter pub get
   flutter build windows --release
   ```

### Creating Windows Installer
After building on Windows, you can create an installer using:

#### Option 1: Using Inno Setup (Recommended)
1. Install Inno Setup from https://jrsoftware.org/isinfo.php
2. Create an installer script (example provided below)
3. Compile the installer

#### Option 2: Using NSIS
1. Install NSIS from https://nsis.sourceforge.io/
2. Create an NSIS script for the installer
3. Compile the installer

### Windows System Requirements
- Windows 10 or later (64-bit)
- Visual C++ Redistributable (usually included with Windows)

## App Information
- **Name**: Instal App
- **Version**: 1.0.0
- **Description**: Islamic installments tracking application
- **Bundle ID**: com.example.instal_app

## Support
For technical support or issues, please contact the development team.

---

**Note**: The macOS version is ready for distribution. For Windows distribution, please build on a Windows machine using the instructions above.
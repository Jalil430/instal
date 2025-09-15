@echo off
echo Building QistPay for Windows...
echo.

REM Clean previous builds
echo Cleaning previous builds...
flutter clean

REM Get dependencies
echo Getting dependencies...
flutter pub get

REM Build Windows release
echo Building Windows release...
flutter build windows --release

REM Check if build was successful
if exist "build\windows\x64\runner\Release\QistPay.exe" (
    echo.
    echo ✓ Build successful!
    echo ✓ Executable created at: build\windows\x64\runner\Release\QistPay.exe
    echo.
    echo To create an installer:
    echo 1. Install Inno Setup from https://jrsoftware.org/isinfo.php
    echo 2. Open windows-installer-script.iss with Inno Setup
    echo 3. Compile the script to create the installer
    echo.
) else (
    echo.
    echo ✗ Build failed!
    echo Please check the error messages above.
    echo.
)

pause

; Inno Setup Script for Instal App
; This script should be used on Windows after building the app with Flutter

[Setup]
AppName=Instal App
AppVersion=1.0.0
AppPublisher=Your Company Name
AppPublisherURL=https://yourwebsite.com
AppSupportURL=https://yourwebsite.com/support
AppUpdatesURL=https://yourwebsite.com/updates
DefaultDirName={autopf}\Instal App
DefaultGroupName=Instal App
AllowNoIcons=yes
; Optional: include license if present
; LicenseFile=LICENSE.txt
; Output directory relative to the repo root
OutputDir=..\\installers
OutputBaseFilename=Instal-Windows-Installer-v1.0.0
; Paths are relative to this script's directory
SetupIconFile=..\\windows\\runner\\resources\\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\\build\\windows\\x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\Instal App"; Filename: "{app}\instal_app.exe"
Name: "{group}\{cm:UninstallProgram,Instal App}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Instal App"; Filename: "{app}\instal_app.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\instal_app.exe"; Description: "{cm:LaunchProgram,Instal App}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
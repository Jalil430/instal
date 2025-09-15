; Inno Setup Script for QistPay
; Preprocessor defines for name and version (can be overridden via ISCC /D)
#define MyAppName "QistPay"
#define MyAppVersion "1.0.3"
; This script should be used on Windows after building the app with Flutter

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Your Company Name
AppPublisherURL=https://yourwebsite.com
AppSupportURL=https://yourwebsite.com/support
AppUpdatesURL=https://yourwebsite.com/updates
DefaultDirName={autopf}\QistPay
DefaultGroupName=QistPay
AllowNoIcons=yes
; Optional: include license if present
; LicenseFile=LICENSE.txt
; Output directory relative to the repo root
OutputDir=..\\installers
OutputBaseFilename=QistPay-Windows-Installer-v{#MyAppVersion}
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
Source: "..\installers\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: FileExists(ExpandConstant('..\installers\vc_redist.x64.exe'))

[Icons]
Name: "{group}\QistPay"; Filename: "{app}\QistPay.exe"
Name: "{group}\{cm:UninstallProgram,QistPay}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\QistPay"; Filename: "{app}\QistPay.exe"; Tasks: desktopicon

[Run]
; Install VC++ Redistributable silently if missing (only if bundled)
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Flags: waituntilterminated; StatusMsg: "Installing Microsoft Visual C++ Redistributable..."; Check: (not IsVC2015_2022RedistInstalled()) and FileExists(ExpandConstant('{tmp}\vc_redist.x64.exe'))
Filename: "{app}\QistPay.exe"; Description: "{cm:LaunchProgram,QistPay}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
function IsVC2015_2022RedistInstalled(): Boolean;
var Installed: Cardinal; Exists: Boolean;
begin
if IsWin64 then
Exists := RegQueryDWordValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', Installed)
else
Exists := RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86', 'Installed', Installed);
Result := Exists and (Installed = 1);
end;

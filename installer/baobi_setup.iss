#define MyAppName      "Baobi Medical Wristband"
#define MyAppVersion   "1.0.0"
#define MyAppPublisher "Baobi"
#define MyAppExeName   "baobi_wristband.exe"
#define MyReleaseDir   "..\build\windows\x64\runner\Release"

[Setup]
AppId={{B720A-BAOBI-WRISTBAND-2025-001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://baobi.com
DefaultDirName={autopf}\BaobiMedicalWristband
DefaultGroupName={#MyAppName}
OutputDir=..\installer\output
OutputBaseFilename=Baobi_Wristband_Setup_v{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=120
DisableDirPage=no
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\{#MyAppExeName}
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
; Main executable
Source: "{#MyReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; Flutter runtime DLLs
Source: "{#MyReleaseDir}\flutter_windows.dll";  DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseDir}\dartjni.dll";          DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseDir}\pdfium.dll";           DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseDir}\printing_plugin.dll";  DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyReleaseDir}\sqlite3.dll";          DestDir: "{app}"; Flags: ignoreversion

; Flutter data folder (assets, fonts, engine)
Source: "{#MyReleaseDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}";       Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

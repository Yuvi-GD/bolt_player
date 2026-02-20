; Bolt Player - InnoSetup Installer Script
; Generates a single setup EXE that installs Bolt Player with file associations

#define MyAppName "Bolt Player"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Bolt Player"
#define MyAppURL "https://github.com/Yuvi-GD/bolt_player"
#define MyAppExeName "bolt_player.exe"
#define MyAppId "com.boltplayer.BoltPlayer"

[Setup]
; Unique App ID - DO NOT change between versions
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
VersionInfoVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
; Create a single installer EXE
OutputDir=installer_output
OutputBaseFilename=BoltPlayer_Setup_{#MyAppVersion}
; Use the app icon for the installer
SetupIconFile=assets\logo\Bolt_Player.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
; Compression for smaller installer
Compression=lzma2/ultra64
SolidCompression=yes
; Modern look
WizardStyle=modern
; Require admin for file associations (Program Files install)
PrivilegesRequired=admin
; 64-bit only
ArchitecturesAllowed=x64
; Don't show license page (no license file)
LicenseFile=
; Minimum Windows version (Windows 10)
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "fileassoc"; Description: "Associate media files with {#MyAppName}"; GroupDescription: "File Associations:"; Flags: checkedonce

[Files]
; Main executable
Source: "build\windows\x64\runner\Release\bolt_player.exe"; DestDir: "{app}"; Flags: ignoreversion
; DLLs
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
; Data folder (flutter assets, etc.)
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't include .lib files (smtc_handler.lib) — those are build artifacts

[Icons]
; Start Menu shortcut
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; AppUserModelID: "{#MyAppId}"
; Desktop shortcut (optional)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; AppUserModelID: "{#MyAppId}"
; Uninstall shortcut
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Registry]
; Set AppUserModelID
Root: HKCU; Subkey: "Software\Classes\AppUserModelId\{#MyAppId}"; ValueType: string; ValueName: "DisplayName"; ValueData: "{#MyAppName}"; Flags: uninsdeletekey

; Register the application in App Paths (so Windows knows about it)
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueName: "Path"; ValueData: "{app}"

; Register application capabilities for "Open with" / Default Programs
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "{#MyAppName}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "Bolt Player - A modern media player"; Flags: uninsdeletekey

; Register with RegisteredApplications (required for "Open with" to appear)
Root: HKLM; Subkey: "SOFTWARE\RegisteredApplications"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: "SOFTWARE\{#MyAppName}\Capabilities"; Flags: uninsdeletevalue

; === Video format associations ===
; Each format needs: (1) a ProgID, (2) a capability entry, and (3) an OpenWithProgIds entry

; --- MP4 ---
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mp4"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKCR; Subkey: "BoltPlayer.MediaFile"; ValueType: string; ValueName: ""; ValueData: "Media File - Bolt Player"; Flags: uninsdeletekey
Root: HKCR; Subkey: "BoltPlayer.MediaFile\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKCR; Subkey: "BoltPlayer.MediaFile\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

; Add to OpenWithProgIds for each format so "Open with" shows Bolt Player

; Video formats
Root: HKCR; Subkey: ".mp4\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".mkv\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".avi\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".mov\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".wmv\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".flv\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".webm\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".m4v\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".mpg\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".mpeg\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".3gp\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".3g2\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".ts\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".mts\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".m2ts\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".vob\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".ogv\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".divx\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".asf\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".rm\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".rmvb\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".f4v\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc

; Audio formats
Root: HKCR; Subkey: ".mp3\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".flac\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".wav\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".aac\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".ogg\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".wma\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".m4a\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".opus\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".aiff\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".ape\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc
Root: HKCR; Subkey: ".wv\OpenWithProgIds"; ValueType: string; ValueName: "BoltPlayer.MediaFile"; ValueData: ""; Tasks: fileassoc

; Capability FileAssociations for all formats
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mkv"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".avi"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mov"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".wmv"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".flv"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".webm"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".m4v"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mpg"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mpeg"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".3gp"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".3g2"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".ts"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mts"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".m2ts"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".vob"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".ogv"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".divx"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".asf"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".rm"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".rmvb"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".f4v"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mp3"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".flac"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".wav"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".aac"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".ogg"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".wma"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".m4a"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".opus"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".aiff"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".ape"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}\Capabilities\FileAssociations"; ValueType: string; ValueName: ".wv"; ValueData: "BoltPlayer.MediaFile"; Tasks: fileassoc

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Import SHChangeNotify to refresh shell icon cache
procedure SHChangeNotify(wEventId: Integer; uFlags: Integer; dwItem1: Integer; dwItem2: Integer);
  external 'SHChangeNotify@shell32.dll stdcall';

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    SHChangeNotify($08000000, $0000, 0, 0);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    SHChangeNotify($08000000, $0000, 0, 0);
  end;
end;


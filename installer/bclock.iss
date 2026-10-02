; bClock installer (Inno Setup 6). Packages the Flutter release build:
;
;   .\installer\build.ps1
;
; which runs `flutter build windows --release`, then
; `iscc /DAppVersion=<pubspec version> installer\bclock.iss`.
;
; Output: build\installer\bClock_Setup_<version>.exe
;
; Installs per user by default (no admin prompt) into
; %LOCALAPPDATA%\Programs\bClock; the user can opt into all-users instead.
; A plain folder install lets the alarm scheduled tasks launch
; bclock.exe --fire <id> directly.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppExe "bclock.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
; Never change AppId: upgrades and uninstall are keyed on it.
AppId={{CC70185C-42F0-4F6E-B1DD-6DEAF9458CE9}
AppName=bClock
AppVersion={#AppVersion}
AppPublisher=bClock
DefaultDirName={autopf}\bClock
DefaultGroupName=bClock
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=bClock_Setup_{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
; Close a running bClock before replacing its files.
CloseApplications=yes

[Languages]
; Same languages as the app (lib/l10n).
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "he"; MessagesFile: "compiler:Languages\Hebrew.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The Release folder is only ever added to, never cleaned, so locally it can
; hold leftovers that must not ship: *.msix from the old MSIX packaging, and
; kernel_blob.bin from a debug build (a release build runs data\app.so).
Source: "{#BuildDir}\*"; DestDir: "{app}"; Excludes: "*.pdb,*.msix,kernel_blob.bin"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\bClock"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\bClock"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,bClock}"; Flags: nowait postinstall skipifsilent

[Registry]
; bClock's toast registration, which the notification plugin writes on first
; run (NotificationService.appUserModelId). Not created here, only removed.
Root: HKCU; Subkey: "Software\Classes\AppUserModelId\bClock.bClock"; Flags: uninsdeletekey dontcreatekey
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\PushNotifications\Backup\bClock.bClock"; Flags: uninsdeletekey dontcreatekey

[UninstallRun]
; The alarm tasks (AlarmScheduler.taskPrefix) and the countdown timer's task
; (AlarmScheduler.timerTaskName) launch {app}\bclock.exe; remove them with
; the app so they don't fire into a missing exe.
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Get-ScheduledTask -TaskName 'bClock_alarm_*','bClock_timer' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false"""; Flags: runhidden; RunOnceId: "RemoveAlarmTasks"

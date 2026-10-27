; ═══════════════════════════════════════════════════════════════════════════════
; Servezy POS — Inno Setup Installer Script (Production v1.0.7)
; ═══════════════════════════════════════════════════════════════════════════════
; Includes: Server (FastAPI/Uvicorn EXE), Terminal (Flutter Windows),
;           Guest Menu (Flutter Web), and Firewall rule for port 8000.
; Note: All required C++ Redistributable DLLs are now bundled for portability.

[Setup]
; AppId is used to identify the application for upgrades/uninstalls
AppId={{C8E6D2B1-4A5F-4B1C-BD7A-F1D5D5E1F2A3}
AppName=Servezy POS
AppVersion=1.0.7
AppPublisher=Servezy
AppCopyright=© 2026 Servezy
AppSupportURL=https://servezy.com
DefaultDirName={autopf}\Servezy
DefaultGroupName=Servezy
; All relative paths below resolve from the repo root (this script lives in packaging\)
SourceDir=..
OutputDir=release
OutputBaseFilename=Servezy_Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
SetupIconFile=packaging\app_icon.ico
UninstallDisplayIcon={app}\Terminal\app.exe
; Security/Reliability: Restricted to x64 since we bundled x64 runtimes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; UI
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; ── Server Backend (single-file EXE built by PyInstaller) ──────────────────
; Includes bundled MSVCP140.dll and VCRUNTIME140.dll for client portability
Source: "DEPLOY\Server_Backend\pos_server.exe"; DestDir: "{app}\Server"; Flags: ignoreversion
Source: "DEPLOY\Server_Backend\restaurant_pos.db"; DestDir: "{app}\Server"; Flags: ignoreversion uninsneveruninstall skipifsourcedoesntexist

; ── Guest Menu Web Build (served by the server at /) ───────────────────────
Source: "DEPLOY\Server_Backend\frontend\*"; DestDir: "{app}\Server\frontend"; Flags: ignoreversion recursesubdirs createallsubdirs

; ── POS Terminal (Flutter Windows desktop bundle) ──────────────────────────
; Includes bundled MSVCP140.dll and VCRUNTIME140.dll for client portability
Source: "DEPLOY\POS_Terminal\*"; DestDir: "{app}\Terminal"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu
Name: "{group}\Servezy Server"; FileName: "{app}\Server\pos_server.exe"; WorkingDir: "{app}\Server"
Name: "{group}\Servezy Terminal"; FileName: "{app}\Terminal\app.exe"; WorkingDir: "{app}\Terminal"
; Desktop (optional)
Name: "{autodesktop}\Servezy Server"; FileName: "{app}\Server\pos_server.exe"; WorkingDir: "{app}\Server"; Tasks: desktopicon
Name: "{autodesktop}\Servezy Terminal"; FileName: "{app}\Terminal\app.exe"; WorkingDir: "{app}\Terminal"; Tasks: desktopicon

[Run]
; Open the firewall for the server API (port 8000)
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Servezy POS Server"" dir=in action=allow protocol=TCP localport=8000"; Flags: runhidden
; Post-install: launch both
Filename: "{app}\Server\pos_server.exe"; Description: "Launch Servezy Server"; WorkingDir: "{app}\Server"; Flags: nowait postinstall skipifsilent
Filename: "{app}\Terminal\app.exe"; Description: "Launch Servezy Terminal"; WorkingDir: "{app}\Terminal"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Servezy POS Server"""; Flags: runhidden

[Code]
var
  ActivationPage: TWizardPage;
  EditKey: TEdit;
  MemoID: TMemo;

function GetMachineID: String;
var
  TmpFile: String;
  SL: TStringList;
  ResultCode: Integer;
  I: Integer;
  Line: String;
begin
  Result := 'HARDWARE-ID-NOT-FOUND';
  TmpFile := ExpandConstant('{tmp}\machine_id.txt');
  
  // Use PowerShell to get the system UUID (modern replacement for deprecated wmic)
  Exec('powershell.exe', '-NoProfile -Command "(Get-CimInstance -ClassName Win32_ComputerSystemProduct).UUID | Out-File -Encoding ascii ''' + TmpFile + '''"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  
  SL := TStringList.Create;
  try
    if FileExists(TmpFile) then
    begin
      SL.LoadFromFile(TmpFile);
      for I := 0 to SL.Count - 1 do
      begin
        Line := Trim(SL[I]);
        if (Line <> '') and (Line <> 'UUID') then
        begin
          Result := Line;
          Exit;
        end;
      end;
    end;
    
    // Fallback: Windows Machine GUID from registry
    if Result = 'HARDWARE-ID-NOT-FOUND' then
    begin
      if RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Cryptography', 'MachineGuid', Line) then
      begin
        Result := Uppercase(Line);
      end;
    end;
  finally
    SL.Free;
    if FileExists(TmpFile) then DeleteFile(TmpFile);
  end;
end;

procedure InitializeWizard;
var
  StaticText: TNewStaticText;
  MachineID: String;
begin
  MachineID := GetMachineID;

  // Create Custom Page
  ActivationPage := CreateCustomPage(wpWelcome, 'Software Activation', 'Please provide this Machine ID to Servezy for your License Key.');

  StaticText := TNewStaticText.Create(ActivationPage);
  StaticText.Parent := ActivationPage.Surface;
  StaticText.Caption := 'Your unique Machine ID (Copy this):';
  StaticText.Left := 0;
  StaticText.Top := 0;

  MemoID := TMemo.Create(ActivationPage);
  MemoID.Parent := ActivationPage.Surface;
  MemoID.Left := 0;
  MemoID.Top := StaticText.Height + ScaleY(8);
  MemoID.Width := ActivationPage.SurfaceWidth;
  MemoID.Height := ScaleY(40);
  MemoID.Text := MachineID;
  MemoID.ReadOnly := True;
  MemoID.Color := clBtnFace;

  StaticText := TNewStaticText.Create(ActivationPage);
  StaticText.Parent := ActivationPage.Surface;
  StaticText.Caption := 'Enter your Activation Key:';
  StaticText.Left := 0;
  StaticText.Top := MemoID.Top + MemoID.Height + ScaleY(20);

  EditKey := TEdit.Create(ActivationPage);
  EditKey.Parent := ActivationPage.Surface;
  EditKey.Left := 0;
  EditKey.Top := StaticText.Top + StaticText.Height + ScaleY(8);
  EditKey.Width := ActivationPage.SurfaceWidth;
  EditKey.Text := '';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = ActivationPage.ID then
  begin
    if Trim(EditKey.Text) = '' then
    begin
      MsgBox('Please enter a valid Activation Key to proceed.', mbError, MB_OK);
      Result := False;
    end;
    // We optionally could add hash verification here if we had a Pascal SHA256 impl
  end;
end;


unit AppArgs;

{ How the FMX app was started. It takes the same switches as the VCL screensaver:
    /s            full screen across the screens, ended by any key or mouse movement
    /w            an ordinary window
    /p <hwnd>     the small preview inside the given window (Windows only)
    /c[:<hwnd>]   the settings form only
  With no switch it opens the reef in a window: an app that is double-clicked, or started on a phone, should
  show the reef. The exception is a copy of the program named .scr (build.ps1 makes one): Windows treats that
  as a screensaver and expects its settings when it is started with no switch.
  The name=value options are read by MainForm. }

interface

type
  TAppMode = (amWindow, amSaver, amPreview, amConfig);

var
  AppMode: TAppMode = amWindow;
  ParentWnd: NativeUInt = 0;

procedure ReadAppMode;

implementation

uses
  System.SysUtils;

procedure ReadAppMode;
var
  I, P: Integer;
  Arg, Name: string;
begin
  // named .scr, the program is a Windows screensaver: no switch means "configure"
  if SameText(ExtractFileExt(ParamStr(0)), '.scr') then AppMode := amConfig;
  I := 1;
  while I <= ParamCount do
  begin
    Arg := LowerCase(ParamStr(I));
    if (Arg <> '') and CharInSet(Arg[1], ['/', '-']) then
    begin
      Name := Arg.Substring(1, 1);
      if Name = 's' then
        AppMode := amSaver
      else if Name = 'w' then
        AppMode := amWindow
      else if (Name = 'p') or (Name = 'c') then
      begin
        if Name = 'p' then AppMode := amPreview else AppMode := amConfig;
        // the window handle follows as "/p 1234" or "/c:1234"
        P := Arg.IndexOf(':');
        if P > 0 then
          ParentWnd := StrToInt64Def(Arg.Substring(P + 1), 0)
        else if (I < ParamCount) and (StrToInt64Def(ParamStr(I + 1), -1) >= 0) then
        begin
          Inc(I);
          ParentWnd := StrToInt64Def(ParamStr(I), 0);
        end;
      end;
    end;
    Inc(I);
  end;
end;

end.

unit MainForm;

{ The FMX app's window: the reef fills it, drawn with Skia.

  Command line (the same as the VCL screensaver; see AppArgs.pas):
    /s  full screen across the screens      /w  a window (also with no switch)
    /p <hwnd>  preview inside a window      /c  settings only
  and name=value options: hour=22 show=puffer shark=1 spawn=1 season=xmas diver=1 fish=1 shrimp=1
  light=night clock=both count=lots off=shark,eel screens=span|same|each|main seed=1 size=1280x720 full=1
  ff=20 (skip 20 seconds ahead)  quit=5 (close after 5 seconds; keys and the mouse are ignored)
  shot=file.png (save a picture and close)  log=file.txt (frame rate, with quit=)
  settings=1 (open the settings straight away).

  In a window:  F or F11 = full screen on / off,  S = settings,  Esc = leave full screen, or close;
                double-click = full screen on / off,  right-click (or a long press) = settings.
  With /s any key, click or mouse movement closes it. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math, System.Diagnostics, System.IOUtils,
  System.Generics.Collections, System.Skia,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Skia,
  ReefEngine, ReefRenderSkia, ReefSettings, ReefScene, AppArgs;

type
  { What one screen shows: its own reef, a copy of another screen's reef, or nothing (black) }
  TRole = (roScene, roMirror, roBlank);

  { One screen's part of the window (a plain window has a single view) }
  TView = class
  public
    R: TRect;                 // in window pixels
    Role: TRole;
    Scene: TOceanScene;
    Master: TView;            // mirrors: the view whose reef is drawn again here
    HideClock: Boolean;       // with several screens only the main one shows the date and time
    ClockArea: TRect;         // where the clock may sit (empty = anywhere)
    destructor Destroy; override;
  end;

  TfrmMain = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDeactivate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
  private
    FBox: TSkAnimatedPaintBox;
    FViews: TObjectList<TView>;
    FSettings: TReefSettings;
    FWatch: TStopwatch;
    FLast, FDrawTime: Double;
    FFastForward, FQuitAfter, FFrames, FSteady: Integer;
    FBuiltW, FBuiltH: Integer;
    FShot, FLog: string;
    FClosing, FOpenSettings, FPlaced, FCursorHidden: Boolean;
    FStartPos: TPointF;
    FHaveStartPos: Boolean;
    FParentCheck: TTimer;
    {$IFDEF MSWINDOWS}
    FMutex: THandle;
    {$ENDIF}
    function Timed: Boolean;
    procedure ReadOptions;
    procedure BuildViews(W, H: Integer);
    procedure DrawAll(const C: ISkCanvas; W, H: Integer; Dt: Single; Advance: Boolean);
    procedure BoxDraw(ASender: TObject; const ACanvas: ISkCanvas; const ADest: TRectF; const AProgress: Double;
      const AOpacity: Single);
    procedure BoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure BoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure BoxDblClick(Sender: TObject);
    procedure BoxGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
    procedure ParentCheck(Sender: TObject);
    procedure SaveShot(W, H: Integer);
    procedure OpenSettings;
    procedure CloseSoon;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  {$IFDEF MSWINDOWS}Winapi.Windows, Winapi.MultiMon, FMX.Platform.Win,{$ENDIF}
  SettingsForm;

{$IFDEF MSWINDOWS}
type
  TMonitor = record
    R: TRect;                 // in real pixels, over the whole desktop
    Primary: Boolean;
  end;

var
  Monitors: TArray<TMonitor>;

function AddMonitor(Mon: HMONITOR; DC: HDC; Rect: PRect; Data: LPARAM): BOOL; stdcall;
var
  Info: TMonitorInfo;
  M: TMonitor;
begin
  Info.cbSize := SizeOf(Info);
  if GetMonitorInfo(Mon, @Info) then
  begin
    M.R := Info.rcMonitor;
    M.Primary := (Info.dwFlags and MONITORINFOF_PRIMARY) <> 0;
    Monitors := Monitors + [M];
  end;
  Result := True;
end;

{ every screen, and the rectangle that holds them all }
function ReadMonitors(out Desktop: TRect): Boolean;
var
  M: TMonitor;
begin
  Monitors := nil;
  EnumDisplayMonitors(0, nil, @AddMonitor, 0);
  Desktop := TRect.Empty;
  for M in Monitors do
    if Desktop.IsEmpty then Desktop := M.R else Desktop := TRect.Union(Desktop, M.R);
  Result := Length(Monitors) > 0;
end;
{$ENDIF}

{ ---------- TView ---------- }

destructor TView.Destroy;
begin
  Scene.Free;
  inherited;
end;

{ ---------- TfrmMain ---------- }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Randomize;
  FViews := TObjectList<TView>.Create(True);
  FSettings.Load;
  ReadOptions;
  if AppMode in [amSaver, amPreview] then
  begin
    BorderStyle := TFmxFormBorderStyle.None;
    if AppMode = amSaver then FormStyle := TFormStyle.StayOnTop;
  end;
  {$IFDEF MSWINDOWS}
  if AppMode = amSaver then
  begin
    // one screensaver at a time
    FMutex := CreateMutex(nil, True, 'ReefscapeFMXScreenSaverRunning');
    if GetLastError = ERROR_ALREADY_EXISTS then
    begin
      CloseSoon;
      Exit;
    end;
  end;
  {$ELSE}
  if AppMode = amSaver then FullScreen := True;
  {$ENDIF}
  FBox := TSkAnimatedPaintBox.Create(Self);
  FBox.Parent := Self;
  FBox.Align := TAlignLayout.Client;
  FBox.HitTest := True;
  // the animation only serves to ask for a new frame every time the display refreshes
  FBox.Animation.Loop := True;
  FBox.Animation.Duration := 60;
  FBox.OnAnimationDraw := BoxDraw;
  FBox.OnMouseDown := BoxMouseDown;
  FBox.OnMouseMove := BoxMouseMove;
  FBox.OnDblClick := BoxDblClick;
  FBox.Touch.InteractiveGestures := [TInteractiveGesture.LongTap];
  FBox.OnGesture := BoxGesture;
  if AppMode = amPreview then
  begin
    // close when the window that hosts the preview goes away
    FParentCheck := TTimer.Create(Self);
    FParentCheck.Interval := 500;
    FParentCheck.OnTimer := ParentCheck;
  end;
  FWatch := TStopwatch.StartNew;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FViews.Free;
  {$IFDEF MSWINDOWS}
  if FCursorHidden then ShowCursor(True);
  if FMutex <> 0 then CloseHandle(FMutex);
  {$ENDIF}
end;

{ a timed test run (quit= or shot=): keys and the mouse do not end it }
function TfrmMain.Timed: Boolean;
begin
  Result := (FQuitAfter > 0) or (FShot <> '');
end;

procedure TfrmMain.ReadOptions;
var
  I, P: Integer;
  Arg, Name, Value: string;
begin
  for I := 1 to ParamCount do
  begin
    Arg := ParamStr(I);
    P := Arg.IndexOf('=');
    if (P <= 0) or CharInSet(Arg[1], ['/', '-']) then Continue;
    Name := LowerCase(Arg.Substring(0, P));
    Value := Arg.Substring(P + 1);
    if Name = 'seed' then RandSeed := StrToIntDef(Value, 0)
    else if Name = 'ff' then FFastForward := StrToIntDef(Value, 0)
    else if Name = 'quit' then FQuitAfter := StrToIntDef(Value, 0)
    else if Name = 'shot' then FShot := Value
    else if Name = 'log' then FLog := Value
    else if Name = 'full' then FullScreen := Value = '1'
    else if Name = 'settings' then FOpenSettings := Value = '1'
    else if Name = 'size' then
    begin
      P := Value.IndexOf('x');
      ClientWidth := StrToIntDef(Value.Substring(0, P), 1280);
      ClientHeight := StrToIntDef(Value.Substring(P + 1), 720);
    end
    else
      FSettings.ApplyArg(Name, LowerCase(Value));
  end;
end;

{ Once the window exists: /s stretches it over every screen, /p moves it into the host window (Windows) }
procedure TfrmMain.FormShow(Sender: TObject);
{$IFDEF MSWINDOWS}
var
  Wnd: HWND;
  Desktop, R: TRect;
{$ENDIF}
begin
  if FPlaced then Exit;
  FPlaced := True;
  {$IFDEF MSWINDOWS}
  Wnd := FormToHWND(Self);
  if (AppMode = amSaver) and ReadMonitors(Desktop) then
  begin
    SetWindowPos(Wnd, HWND_TOPMOST, Desktop.Left, Desktop.Top, Desktop.Width, Desktop.Height, SWP_SHOWWINDOW);
    SetForegroundWindow(Wnd);
    ShowCursor(False);
    FCursorHidden := True;
  end
  else if AppMode = amPreview then
  begin
    if (ParentWnd = 0) or not IsWindow(ParentWnd) then
    begin
      CloseSoon;
      Exit;
    end;
    SetWindowLongPtr(Wnd, GWL_STYLE, WS_CHILD or WS_VISIBLE);
    Winapi.Windows.SetParent(Wnd, ParentWnd);
    Winapi.Windows.GetClientRect(ParentWnd, R);
    SetWindowPos(Wnd, 0, 0, 0, R.Width, R.Height, SWP_NOZORDER or SWP_NOACTIVATE or SWP_FRAMECHANGED);
  end;
  {$ENDIF}
end;

procedure TfrmMain.ParentCheck(Sender: TObject);
begin
  {$IFDEF MSWINDOWS}
  if not IsWindow(ParentWnd) then CloseSoon;
  {$ENDIF}
end;

{ The views of the window. A plain window (or the preview) has one. With /s on Windows there is one per screen,
  by the "more than one screen" setting:
    span  one wide reef across the whole desktop (the default)
    same  the same reef on every screen (a screen of a different shape gets a reef of its own)
    each  a different reef on each screen
    main  the main screen only }
procedure TfrmMain.BuildViews(W, H: Integer);
var
  V: TView;
  I: Integer;
{$IFDEF MSWINDOWS}
  Desktop, R: TRect;
  Best, K: Integer;
  Master: TView;
  BestAspect: Double;

  function Area(Index: Integer): Integer;
  begin
    Result := Monitors[Index].R.Width * Monitors[Index].R.Height;
  end;
{$ENDIF}

  procedure Single;
  begin
    V := TView.Create;
    V.R := Rect(0, 0, W, H);
    V.Role := roScene;
    FViews.Add(V);
  end;

begin
  FViews.Clear;
  FBuiltW := W;
  FBuiltH := H;
  {$IFDEF MSWINDOWS}
  // per-screen views only when the window really covers the whole desktop
  if (AppMode = amSaver) and ReadMonitors(Desktop) and (Abs(Desktop.Width - W) <= 2) and (Abs(Desktop.Height - H) <= 2) then
  begin
    if (FSettings.Screens <> 'same') and (FSettings.Screens <> 'each') and (FSettings.Screens <> 'main') then
    begin
      Single;
      // the clock keeps to the main screen
      for K := 0 to High(Monitors) do
        if Monitors[K].Primary then
        begin
          V.ClockArea := Monitors[K].R;
          V.ClockArea.Offset(-Desktop.Left, -Desktop.Top);
        end;
    end
    else
    begin
      // the biggest screen is the one that is drawn first; the main screen wins a tie
      Best := 0;
      for K := 1 to High(Monitors) do
        if (Area(K) > Area(Best)) or ((Area(K) = Area(Best)) and Monitors[K].Primary) then Best := K;
      if FSettings.Screens = 'main' then
        for K := 0 to High(Monitors) do
          if Monitors[K].Primary then Best := K;
      BestAspect := Monitors[Best].R.Width / Max(1, Monitors[Best].R.Height);
      Master := nil;
      for K := -1 to High(Monitors) do
      begin
        if K = Best then Continue;
        if K < 0 then R := Monitors[Best].R else R := Monitors[K].R;
        V := TView.Create;
        V.R := R;
        V.R.Offset(-Desktop.Left, -Desktop.Top);
        if K < 0 then V.HideClock := not Monitors[Best].Primary else V.HideClock := not Monitors[K].Primary;
        if K < 0 then
        begin
          V.Role := roScene;
          Master := V;
        end
        else if FSettings.Screens = 'main' then
          V.Role := roBlank
        else if (FSettings.Screens = 'each') or (Abs(R.Width / Max(1, R.Height) / BestAspect - 1) > 0.02) then
          V.Role := roScene
        else
        begin
          V.Role := roMirror;
          V.Master := Master;
        end;
        FViews.Add(V);
      end;
    end;
  end
  else
  {$ENDIF}
    Single;

  for V in FViews do
    if V.Role = roScene then
    begin
      V.Scene := TOceanScene.Create(FSettings, V.R.Width, V.R.Height);
      if not V.ClockArea.IsEmpty then V.Scene.SetClockArea(V.ClockArea);
      // test option: skip ahead in time
      for I := 1 to FFastForward * 30 do V.Scene.Advance(1 / 30);
    end;
  FFastForward := 0;
  FLast := FWatch.Elapsed.TotalSeconds;
end;

{ everything, in real pixels: the reefs first, then the screens that show one of them again }
procedure TfrmMain.DrawAll(const C: ISkCanvas; W, H: Integer; Dt: Single; Advance: Boolean);
const
  Part: array [Boolean] of TRenderPart = (rpAll, rpNoClock);
var
  V: TView;
begin
  C.Clear(TAlphaColors.Black);
  SkiaRenderer.Canvas := C;
  try
    if FViews.Count = 1 then FViews[0].R := Rect(0, 0, W, H);
    for V in FViews do
      if V.Role = roScene then
      begin
        V.Scene.SetView(V.R.Width, V.R.Height);
        if Advance then V.Scene.Advance(Dt);
        V.Scene.Render(V.R, H, Part[V.HideClock]);
      end;
    for V in FViews do
      if (V.Role = roMirror) and (V.Master <> nil) then
      begin
        V.Master.Scene.SetView(V.R.Width, V.R.Height);
        V.Master.Scene.Render(V.R, H, Part[V.HideClock]);
      end;
  finally
    SkiaRenderer.Canvas := nil;
  end;
end;

procedure TfrmMain.BoxDraw(ASender: TObject; const ACanvas: ISkCanvas; const ADest: TRectF; const AProgress: Double;
  const AOpacity: Single);
var
  Scale: Single;
  W, H: Integer;
  T, T1: Double;
begin
  if FClosing then Exit;
  // the scene works in real pixels, so it stays sharp on high-density screens
  Scale := ACanvas.GetLocalToDeviceAs3x3.m11;
  if Scale <= 0 then Scale := 1;
  W := Max(1, Round(ADest.Width * Scale));
  H := Max(1, Round(ADest.Height * Scale));

  // The window's shape decides how wide the reef is. After the window has been reshaped (and has settled),
  // the reef is built again for the new shape.
  if (FViews.Count > 0) and ((W <> FBuiltW) or (H <> FBuiltH)) then
  begin
    Inc(FSteady);
    if FSteady > 20 then
    begin
      if (FViews.Count > 1) or
        (Abs(Max(1920, 1080 * W / H) - FViews[0].Scene.WorldWidth) > 0.02 * FViews[0].Scene.WorldWidth) then
        FViews.Clear
      else
      begin
        FBuiltW := W;
        FBuiltH := H;
      end;
    end;
  end
  else
    FSteady := 0;
  if FViews.Count = 0 then BuildViews(W, H);

  T := FWatch.Elapsed.TotalSeconds;
  ACanvas.Save;
  try
    ACanvas.Translate(ADest.Left, ADest.Top);
    ACanvas.Scale(1 / Scale, 1 / Scale);
    DrawAll(ACanvas, W, H, EnsureRange(T - FLast, 0, 0.1), True);
  finally
    ACanvas.Restore;
  end;
  FLast := T;

  T1 := FWatch.Elapsed.TotalSeconds;
  FDrawTime := FDrawTime + (T1 - T);
  Inc(FFrames);
  if FOpenSettings then
  begin
    FOpenSettings := False;
    if FShot <> '' then
    begin
      // test: a picture of the settings form instead of the reef
      SaveSettingsPicture(FShot);
      CloseSoon;
      Exit;
    end;
    TThread.ForceQueue(nil,
      procedure
      begin
        OpenSettings;
      end);
  end;
  if (FShot <> '') and (FFrames = 3) then
  begin
    SaveShot(W, H);
    CloseSoon;
  end
  else if (FQuitAfter > 0) and (T >= FQuitAfter) then
  begin
    if FLog <> '' then
      TFile.WriteAllText(FLog, Format('%d frames in %.1f s (%.1f per second), %.1f ms drawing per frame, %d x %d, %d view(s)',
        [FFrames, T, FFrames / T, FDrawTime * 1000 / FFrames, W, H, FViews.Count]));
    CloseSoon;
  end;
end;

{ test option shot=: everything drawn once more into a picture of its own }
procedure TfrmMain.SaveShot(W, H: Integer);
var
  Surf: ISkSurface;
begin
  Surf := TSkSurface.MakeRaster(W, H);
  DrawAll(Surf.Canvas, W, H, 0, False);
  Surf.MakeImageSnapshot.EncodeToFile(FShot);
end;

procedure TfrmMain.CloseSoon;
begin
  if FClosing then Exit;
  FClosing := True;
  // not from inside the paint event
  TThread.ForceQueue(nil,
    procedure
    begin
      Close;
    end);
end;

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if AppMode = amSaver then
  begin
    if not Timed then CloseSoon;
  end
  else if AppMode = amPreview then
    // the preview takes no keys
  else if (Key = vkF11) or (UpCase(KeyChar) = 'F') then
    FullScreen := not FullScreen
  else if UpCase(KeyChar) = 'S' then
    OpenSettings
  else if Key = vkEscape then
  begin
    if FullScreen then FullScreen := False else Close;
  end;
end;

procedure TfrmMain.FormDeactivate(Sender: TObject);
begin
  // another program came to the front
  if (AppMode = amSaver) and (not Timed) and (FWatch.Elapsed.TotalSeconds > 1.5) then CloseSoon;
end;

procedure TfrmMain.BoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if AppMode = amSaver then
  begin
    if not Timed then CloseSoon;
  end
  else if (AppMode = amWindow) and (Button = TMouseButton.mbRight) then
    OpenSettings;
end;

procedure TfrmMain.BoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
var
  P: TPointF;
begin
  if (AppMode <> amSaver) or Timed then Exit;
  // a real move ends the screensaver; the tiny jitter of a resting mouse does not
  P := Screen.MousePos;
  if not FHaveStartPos then
  begin
    FStartPos := P;
    FHaveStartPos := True;
  end
  else if (Abs(P.X - FStartPos.X) > 8) or (Abs(P.Y - FStartPos.Y) > 8) then
    CloseSoon;
end;

procedure TfrmMain.BoxDblClick(Sender: TObject);
begin
  if AppMode = amWindow then FullScreen := not FullScreen;
end;

procedure TfrmMain.BoxGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
begin
  if (AppMode = amWindow) and (EventInfo.GestureID = igiLongTap) and (TInteractiveGestureFlag.gfEnd in EventInfo.Flags) then
  begin
    Handled := True;
    OpenSettings;
  end;
end;

procedure TfrmMain.OpenSettings;
begin
  ShowReefSettings(
    procedure
    var
      Keep: TReefSettings;
    begin
      // saved: read the settings again (keeping any test options) and rebuild the reef with them
      Keep := FSettings;
      FSettings.Load;
      FSettings.StartHour := Keep.StartHour;
      FSettings.Season := Keep.Season;
      FViews.Clear;
    end);
end;

end.

unit SaverMain;

{ The Windows screensaver shell.

  Windows starts a screensaver (.scr) with one of these arguments:
    /s            run full screen
    /p <hwnd>     draw the small preview inside the given window (the Screen Saver Settings dialog)
    /c[:<hwnd>]   show the settings dialog (also when started with no arguments)

  For testing there is also:
    /w            run in an ordinary window (Esc closes it)
  and name=value options: hour=22 show=puffer shark=1 spawn=1 season=xmas diver=1 fish=1 shrimp=1
  light=night clock=both count=lots off=shark,eel screens=span|same|each|main seed=1 size=1280x720
  ff=20 (skip 20 seconds ahead)  quit=5 (close after 5 seconds; keys and the mouse are ignored)
  shot=file.png (save a picture of the first frames and quit)  log=file.txt (renderer and frame times).

  Note: Windows always starts a .scr file with /s when it is opened from Explorer or PowerShell, whatever
  else is on the command line. To use the test options, run a copy named .exe (build.ps1 -Run does that). }

interface

procedure RunSaver;

implementation

uses
  Winapi.Windows, Winapi.Messages, Winapi.OpenGL, Winapi.ActiveX, System.SysUtils, System.Classes, System.Math,
  System.Diagnostics, System.Generics.Collections, Vcl.Forms, Vcl.Controls, Vcl.Graphics, Vcl.Imaging.pngimage,
  ReefEngine, ReefSettings, ReefScene, ConfigForm;

type
  TRunMode = (rmSaver, rmPreview, rmWindow, rmConfig);

  { What one screen shows: its own reef, a copy of another screen's reef, or nothing (black) }
  TRole = (roScene, roMirror, roBlank);

  { One screen's part of the window }
  TView = class
  public
    R: TRect;                 // in window pixels, y down
    Role: TRole;
    Scene: TOceanScene;
    Master: TView;            // mirrors: the view whose picture is copied
    HasMirrors: Boolean;
    CopyTex: GLuint;          // views with mirrors: the finished frame as a texture
    CopyW, CopyH: Integer;
    ClockArea: TRect;         // where the clock may sit, in the view's own pixels (empty = anywhere)
    destructor Destroy; override;
  end;

  { A single window: the whole desktop when running as the screensaver (so every screen is drawn and shown
    together, with one wait for the display per frame), or the preview / test window. }
  TSaverForm = class(TForm)
  private
    FDC: HDC;
    FRC: HGLRC;
    FMode: TRunMode;
    FViews: TObjectList<TView>;
    FStartPos: TPoint;
    FHaveStartPos: Boolean;
    procedure InitGL;
    procedure Draw(Dt: Single; Advance: Boolean);
    procedure CopyFrame(V: TView; OriginY: Integer);
    procedure DrawMirror(V: TView; OriginY: Integer);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WndProc(var Message: TMessage); override;
  public
    constructor CreateSaver(AMode: TRunMode; AParent: HWND; const ABounds: TRect);
    destructor Destroy; override;
    procedure Frame(Dt: Single);
    procedure SaveShot(const FileName: string);
  end;

  TRunner = class
  public
    Form: TSaverForm;
    Watch: TStopwatch;
    Last, DrawTime, DrawDone, ShowTime: Double;
    Started: Cardinal;
    ShotFile, LogFile: string;
    QuitAfter, Frames: Integer;
    procedure Idle(Sender: TObject; var Done: Boolean);
    procedure Log(const S: string);
    { a timed test run (quit= or shot=): keys and the mouse do not end it }
    function Timed: Boolean;
  end;

var
  Mode: TRunMode;
  Settings: TReefSettings;
  Runner: TRunner;
  Closing: Boolean;

procedure CloseAll;
begin
  if Closing then Exit;
  Closing := True;
  Application.Terminate;
end;

function GLString(Name: GLenum): string;
begin
  Result := string(AnsiString(PAnsiChar(glGetString(Name))));
end;

{ ---------- TView ---------- }

destructor TView.Destroy;
begin
  Scene.Free;
  if CopyTex <> 0 then glDeleteTextures(1, @CopyTex);
  inherited;
end;

{ ---------- TSaverForm ---------- }

constructor TSaverForm.CreateSaver(AMode: TRunMode; AParent: HWND; const ABounds: TRect);
begin
  FMode := AMode;
  FViews := TObjectList<TView>.Create(True);
  CreateNew(nil);
  Scaled := False;
  Color := clBlack;
  Caption := 'Reefscape';
  if AMode = rmPreview then
  begin
    BorderStyle := bsNone;
    ParentWindow := AParent;
  end
  else if AMode = rmSaver then
  begin
    BorderStyle := bsNone;
    FormStyle := fsStayOnTop;
  end;
  Position := poDesigned;
  if AMode = rmWindow then
  begin
    SetBounds(ABounds.Left, ABounds.Top, 100, 100);
    ClientWidth := ABounds.Width;
    ClientHeight := ABounds.Height;
  end
  else
    BoundsRect := ABounds;
end;

destructor TSaverForm.Destroy;
begin
  if FRC <> 0 then
  begin
    wglMakeCurrent(FDC, FRC);
    FViews.Free;
    wglMakeCurrent(0, 0);
    wglDeleteContext(FRC);
  end
  else
    FViews.Free;
  inherited;
end;

procedure TSaverForm.CreateParams(var Params: TCreateParams);
begin
  inherited;
  // OpenGL wants a window that keeps its own device context
  Params.WindowClass.style := Params.WindowClass.style or CS_OWNDC;
  Params.Style := Params.Style or WS_CLIPCHILDREN or WS_CLIPSIBLINGS;
end;

procedure TSaverForm.InitGL;
type
  TSwapInterval = function(Interval: Integer): BOOL; stdcall;
var
  Pfd: TPixelFormatDescriptor;
  Fmt: Integer;
  SwapInterval: TSwapInterval;
  V: TView;
  Ver: string;
begin
  FDC := GetDC(Handle);
  Pfd := Default(TPixelFormatDescriptor);
  Pfd.nSize := SizeOf(Pfd);
  Pfd.nVersion := 1;
  Pfd.dwFlags := PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;
  Pfd.iPixelType := PFD_TYPE_RGBA;
  Pfd.cColorBits := 32;
  Pfd.iLayerType := PFD_MAIN_PLANE;
  Fmt := ChoosePixelFormat(FDC, @Pfd);
  if (Fmt = 0) or not SetPixelFormat(FDC, Fmt, @Pfd) then raise Exception.Create('No OpenGL pixel format');
  FRC := wglCreateContext(FDC);
  if FRC = 0 then RaiseLastOSError;
  wglMakeCurrent(FDC, FRC);
  // one frame per refresh of the display
  @SwapInterval := wglGetProcAddress('wglSwapIntervalEXT');
  if Assigned(SwapInterval) then SwapInterval(1);
  Ver := GLString(GL_VERSION);
  Runner.Log('OpenGL: ' + GLString(GL_RENDERER) + ', ' + Ver);
  // copying the picture to other screens needs OpenGL 2; without it every screen draws its own reef
  if StrToIntDef(Copy(Ver, 1, Pos('.', Ver) - 1), 1) < 2 then
    for V in FViews do
    begin
      V.HasMirrors := False;
      if V.Role = roMirror then V.Role := roScene;
    end;
  for V in FViews do
    if V.Role = roScene then
    begin
      V.Scene := TOceanScene.Create(Settings, V.R.Width, V.R.Height);
      if not V.ClockArea.IsEmpty then V.Scene.SetClockArea(V.ClockArea);
    end;
end;

{ Keep the view just drawn as a texture, for the screens that show the same reef }
procedure TSaverForm.CopyFrame(V: TView; OriginY: Integer);
begin
  if (V.CopyTex = 0) or (V.CopyW <> V.R.Width) or (V.CopyH <> V.R.Height) then
  begin
    if V.CopyTex = 0 then glGenTextures(1, @V.CopyTex);
    V.CopyW := V.R.Width;
    V.CopyH := V.R.Height;
    glBindTexture(GL_TEXTURE_2D, V.CopyTex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, $812F { GL_CLAMP_TO_EDGE });
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, $812F);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, V.CopyW, V.CopyH, 0, GL_RGB, GL_UNSIGNED_BYTE, nil);
  end;
  glBindTexture(GL_TEXTURE_2D, V.CopyTex);
  glReadBuffer(GL_BACK);
  glCopyTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, V.R.Left, OriginY, V.CopyW, V.CopyH);
end;

{ Draw the master view's picture to fill this view }
procedure TSaverForm.DrawMirror(V: TView; OriginY: Integer);
var
  W, H: Integer;
  S, DW, DH, X, Y: Single;
begin
  if (V.Master = nil) or (V.Master.CopyTex = 0) then Exit;
  W := V.R.Width;
  H := V.R.Height;
  glViewport(V.R.Left, OriginY, W, H);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, W, H, 0, -1, 1);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glDisable(GL_BLEND);
  glDisable(GL_SCISSOR_TEST);
  S := Max(W / V.Master.CopyW, H / V.Master.CopyH);
  DW := V.Master.CopyW * S;
  DH := V.Master.CopyH * S;
  X := (W - DW) / 2;
  Y := (H - DH) / 2;
  glEnable(GL_TEXTURE_2D);
  glBindTexture(GL_TEXTURE_2D, V.Master.CopyTex);
  glColor4f(1, 1, 1, 1);
  glBegin(GL_QUADS);
  // the copied picture has its first row at the bottom
  glTexCoord2f(0, 1);
  glVertex2f(X, Y);
  glTexCoord2f(1, 1);
  glVertex2f(X + DW, Y);
  glTexCoord2f(1, 0);
  glVertex2f(X + DW, Y + DH);
  glTexCoord2f(0, 0);
  glVertex2f(X, Y + DH);
  glEnd;
  glDisable(GL_TEXTURE_2D);
end;

procedure TSaverForm.Draw(Dt: Single; Advance: Boolean);
var
  V: TView;
  H: Integer;
begin
  H := ClientHeight;
  // the preview and the test window have one view that fills the window
  if FMode <> rmSaver then FViews[0].R := Rect(0, 0, ClientWidth, H);
  glViewport(0, 0, ClientWidth, H);
  glDisable(GL_SCISSOR_TEST);
  glClearColor(0, 0, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT);
  // the reefs first, then the screens that show a copy of one
  for V in FViews do
    if V.Role = roScene then
    begin
      V.Scene.SetView(V.R.Width, V.R.Height);
      if Advance then V.Scene.Advance(Dt);
      V.Scene.Render(V.R.Left, H - V.R.Bottom);
      if V.HasMirrors then CopyFrame(V, H - V.R.Bottom);
    end;
  for V in FViews do
    if V.Role = roMirror then DrawMirror(V, H - V.R.Bottom);
end;

procedure TSaverForm.Frame(Dt: Single);
begin
  if FRC = 0 then Exit;
  Draw(Dt, True);
  // with log=, drawing and showing are timed separately
  if Runner.LogFile <> '' then
  begin
    glFinish;
    Runner.DrawDone := Runner.Watch.Elapsed.TotalSeconds;
  end;
  SwapBuffers(FDC);
end;

procedure TSaverForm.SaveShot(const FileName: string);
var
  W, H, Y: Integer;
  Buf: TBytes;
  Bmp: TBitmap;
  Png: TPngImage;
begin
  Draw(0, False);
  W := ClientWidth;
  H := ClientHeight;
  SetLength(Buf, W * H * 4);
  glPixelStorei(GL_PACK_ALIGNMENT, 4);
  glReadBuffer(GL_BACK);
  glReadPixels(0, 0, W, H, $80E1 { GL_BGRA }, GL_UNSIGNED_BYTE, @Buf[0]);
  Bmp := TBitmap.Create;
  Png := TPngImage.Create;
  try
    Bmp.PixelFormat := pf32bit;
    Bmp.SetSize(W, H);
    for Y := 0 to H - 1 do Move(Buf[(H - 1 - Y) * W * 4], Bmp.ScanLine[Y]^, W * 4);
    Bmp.PixelFormat := pf24bit;
    Png.Assign(Bmp);
    Png.SaveToFile(FileName);
  finally
    Png.Free;
    Bmp.Free;
  end;
end;

procedure TSaverForm.WndProc(var Message: TMessage);
var
  P: TPoint;
  Live: Boolean;
begin
  // the real screensaver ends on any input; a timed test run does not
  Live := (FMode = rmSaver) and (Runner <> nil) and not Runner.Timed;
  case Message.Msg of
    WM_ERASEBKGND:
      begin
        Message.Result := 1;
        Exit;
      end;
    WM_PAINT:
      begin
        // the frame loop does the drawing
        ValidateRect(Handle, nil);
        Message.Result := 0;
        Exit;
      end;
    WM_SETCURSOR:
      if FMode = rmSaver then
      begin
        SetCursor(0);
        Message.Result := 1;
        Exit;
      end;
    WM_SYSCOMMAND:
      // don't let Windows start a second screensaver (or blank the monitor) on top of this one
      if (FMode = rmSaver) and ((Message.WParam and $FFF0 = SC_SCREENSAVE) or (Message.WParam and $FFF0 = SC_MONITORPOWER)) then
      begin
        Message.Result := 0;
        Exit;
      end;
    WM_KEYDOWN, WM_SYSKEYDOWN:
      if Live or ((FMode = rmWindow) and (Message.WParam = VK_ESCAPE)) then CloseAll;
    WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN, WM_MOUSEWHEEL:
      if Live then CloseAll;
    WM_MOUSEMOVE:
      if Live then
      begin
        // a real move ends the screensaver; the tiny jitter of a resting mouse does not
        GetCursorPos(P);
        if not FHaveStartPos then
        begin
          FStartPos := P;
          FHaveStartPos := True;
        end
        else if (Abs(P.X - FStartPos.X) > 8) or (Abs(P.Y - FStartPos.Y) > 8) then
          CloseAll;
      end;
    WM_ACTIVATEAPP:
      // another program came to the front
      if Live and (Message.WParam = 0) and (GetTickCount - Runner.Started > 1500) then CloseAll;
    WM_CLOSE, WM_DESTROY:
      CloseAll;
  end;
  inherited;
end;

{ ---------- frame loop ---------- }

procedure TRunner.Log(const S: string);
var
  F: TextFile;
begin
  if LogFile = '' then Exit;
  AssignFile(F, LogFile);
  if FileExists(LogFile) then Append(F) else Rewrite(F);
  Writeln(F, S);
  CloseFile(F);
end;

function TRunner.Timed: Boolean;
begin
  Result := (QuitAfter > 0) or (ShotFile <> '');
end;

procedure TRunner.Idle(Sender: TObject; var Done: Boolean);
var
  T, T1: Double;
begin
  Done := False;
  if Closing then Exit;
  T := Watch.Elapsed.TotalSeconds;
  Form.Frame(EnsureRange(T - Last, 0, 0.1));
  Last := T;
  T1 := Watch.Elapsed.TotalSeconds;
  DrawTime := DrawTime + (T1 - T);
  if DrawDone > 0 then ShowTime := ShowTime + (T1 - DrawDone);
  Inc(Frames);
  if (ShotFile <> '') and (Frames = 3) then
  begin
    Form.SaveShot(ShotFile);
    CloseAll;
  end;
  if (QuitAfter > 0) and (T >= QuitAfter) then
  begin
    Log(Format('%d frames in %.1f s (%.1f per second): %.1f ms per frame, of which %.1f ms drawing and %.1f ms waiting for the display',
      [Frames, T, Frames / T, DrawTime * 1000 / Frames, (DrawTime - ShowTime) * 1000 / Frames, ShowTime * 1000 / Frames]));
    CloseAll;
  end;
  // without vertical sync (some drivers, remote desktop) frames would come as fast as the CPU allows
  if T1 - T < 0.004 then Sleep(8);
end;

{ The views of the full-screen window, by the "more than one screen" setting:
    span  one wide reef across the whole desktop (the default): fish swim from one screen to the next
    same  the same reef on every screen: drawn once (on the biggest screen) and copied; a screen of a
          different shape gets a reef of its own
    each  a different reef on each screen
    main  the main screen only }
procedure AddScreenViews(Form: TSaverForm; const Desktop: TRect);
var
  I, Best: Integer;
  R: TRect;
  V, Master: TView;
  BestAspect: Double;

  function Area(Index: Integer): Integer;
  begin
    Result := Screen.Monitors[Index].BoundsRect.Width * Screen.Monitors[Index].BoundsRect.Height;
  end;

begin
  if (Settings.Screens <> 'same') and (Settings.Screens <> 'each') and (Settings.Screens <> 'main') then
  begin
    V := TView.Create;
    V.R := Rect(0, 0, Desktop.Width, Desktop.Height);
    V.Role := roScene;
    // the clock keeps to the main screen
    V.ClockArea := Screen.PrimaryMonitor.BoundsRect;
    V.ClockArea.Offset(-Desktop.Left, -Desktop.Top);
    Form.FViews.Add(V);
    Exit;
  end;
  Best := 0;
  for I := 1 to Screen.MonitorCount - 1 do
    if (Area(I) > Area(Best)) or ((Area(I) = Area(Best)) and Screen.Monitors[I].Primary) then Best := I;
  if Settings.Screens = 'main' then
    for I := 0 to Screen.MonitorCount - 1 do
      if Screen.Monitors[I].Primary then Best := I;
  R := Screen.Monitors[Best].BoundsRect;
  BestAspect := R.Width / Max(1, R.Height);
  Master := nil;
  // the drawn screen first, so its picture is ready for the others
  for I := -1 to Screen.MonitorCount - 1 do
  begin
    if I = Best then Continue;
    if I >= 0 then R := Screen.Monitors[I].BoundsRect;
    V := TView.Create;
    V.R := R;
    V.R.Offset(-Desktop.Left, -Desktop.Top);
    if I < 0 then
    begin
      V.Role := roScene;
      Master := V;
    end
    else if Settings.Screens = 'main' then
      V.Role := roBlank
    else if (Settings.Screens = 'each') or (Abs(R.Width / Max(1, R.Height) / BestAspect - 1) > 0.02) then
      V.Role := roScene
    else
    begin
      V.Role := roMirror;
      V.Master := Master;
      Master.HasMirrors := True;
    end;
    Form.FViews.Add(V);
  end;
end;

procedure RunScene(Parent: HWND);
const
  RoleNames: array [TRole] of string = ('its own reef', 'copy of the first', 'blank');
var
  F: TSaverForm;
  V: TView;
  R: TRect;
  I, K, W, H, FastForward: Integer;
  Arg, Size: string;
  Mutex: THandle;
begin
  Mutex := 0;
  if Mode = rmSaver then
  begin
    // one screensaver at a time
    Mutex := CreateMutex(nil, True, 'ReefscapeScreenSaverRunning');
    if GetLastError = ERROR_ALREADY_EXISTS then Exit;
  end;
  Runner := TRunner.Create;
  F := nil;
  try
    FastForward := 0;
    Size := '1280x720';
    for I := 1 to ParamCount do
    begin
      Arg := LowerCase(ParamStr(I));
      if Arg.StartsWith('ff=') then FastForward := StrToIntDef(Arg.Substring(3), 0);
      if Arg.StartsWith('shot=') then Runner.ShotFile := ParamStr(I).Substring(5);
      if Arg.StartsWith('log=') then Runner.LogFile := ParamStr(I).Substring(4);
      if Arg.StartsWith('size=') then Size := Arg.Substring(5);
      if Arg.StartsWith('quit=') then Runner.QuitAfter := StrToIntDef(Arg.Substring(5), 0);
    end;

    case Mode of
      rmPreview:
        begin
          Winapi.Windows.GetClientRect(Parent, R);
          F := TSaverForm.CreateSaver(rmPreview, Parent, R);
        end;
      rmWindow:
        begin
          W := StrToIntDef(Size.Substring(0, Size.IndexOf('x')), 1280);
          H := StrToIntDef(Size.Substring(Size.IndexOf('x') + 1), 720);
          F := TSaverForm.CreateSaver(rmWindow, 0, Rect(60, 60, 60 + W, 60 + H));
        end;
    else
      // one window over the whole desktop
      F := TSaverForm.CreateSaver(rmSaver, 0, Screen.DesktopRect);
      AddScreenViews(F, Screen.DesktopRect);
    end;
    Runner.Form := F;
    if F.FViews.Count = 0 then
    begin
      V := TView.Create;
      V.R := Rect(0, 0, F.ClientWidth, F.ClientHeight);
      F.FViews.Add(V);
    end;

    F.HandleNeeded;
    F.InitGL;
    for I := 0 to F.FViews.Count - 1 do
    begin
      V := F.FViews[I];
      Runner.Log(Format('screen %d: %d x %d, %s', [I, V.R.Width, V.R.Height, RoleNames[V.Role]]));
      // test option: skip ahead in time before the first frame is shown
      if V.Scene <> nil then
        for K := 1 to FastForward * 30 do V.Scene.Advance(1 / 30);
    end;
    F.Visible := True;
    if Mode = rmSaver then
    begin
      // exactly over every screen (showing the window must not have moved or resized it)
      R := Screen.DesktopRect;
      SetWindowPos(F.Handle, HWND_TOPMOST, R.Left, R.Top, R.Width, R.Height, 0);
      ShowCursor(False);
      SetForegroundWindow(F.Handle);
    end;

    Runner.Started := GetTickCount;
    Runner.Watch := TStopwatch.StartNew;
    Application.OnIdle := Runner.Idle;
    repeat
      Application.HandleMessage;
      // the preview's host window went away
      if (Mode = rmPreview) and not IsWindow(Parent) then CloseAll;
    until Application.Terminated;
    Application.OnIdle := nil;
    if Mode = rmSaver then ShowCursor(True);
  finally
    F.Free;
    FreeAndNil(Runner);
    if Mutex <> 0 then CloseHandle(Mutex);
  end;
end;

procedure RunSaver;
var
  I, P: Integer;
  Arg, Name: string;
  Parent: HWND;
begin
  // OpenGL drivers do floating-point maths that must not raise Delphi exceptions
  SetExceptionMask(exAllArithmeticExceptions);
  CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
  Randomize;
  Settings.Load;
  Mode := rmConfig;
  Parent := 0;
  I := 1;
  while I <= ParamCount do
  begin
    Arg := LowerCase(ParamStr(I));
    if (Arg <> '') and CharInSet(Arg[1], ['/', '-']) then
    begin
      Name := Arg.Substring(1, 1);
      if Name = 's' then
        Mode := rmSaver
      else if Name = 'w' then
        Mode := rmWindow
      else if (Name = 'p') or (Name = 'c') then
      begin
        if Name = 'p' then Mode := rmPreview else Mode := rmConfig;
        // the window handle follows as "/p 1234" or "/c:1234"
        P := Arg.IndexOf(':');
        if P > 0 then
          Parent := StrToInt64Def(Arg.Substring(P + 1), 0)
        else if (I < ParamCount) and (StrToInt64Def(ParamStr(I + 1), -1) >= 0) then
        begin
          Inc(I);
          Parent := StrToInt64Def(ParamStr(I), 0);
        end;
      end;
    end
    else
    begin
      P := Arg.IndexOf('=');
      if P > 0 then
      begin
        Name := Arg.Substring(0, P);
        if Name = 'seed' then RandSeed := StrToIntDef(Arg.Substring(P + 1), 0)
        else Settings.ApplyArg(Name, Arg.Substring(P + 1));
      end;
    end;
    Inc(I);
  end;

  Application.Initialize;
  Application.Title := 'Reefscape';
  try
    if (Mode = rmPreview) and ((Parent = 0) or not IsWindow(Parent)) then Exit;
    if Mode = rmConfig then
      ShowConfig(Parent)
    else
      RunScene(Parent);
  except
    on E: Exception do
      if Mode <> rmPreview then
        MessageBox(0, PChar('Reefscape could not start: ' + E.Message), 'Reefscape', MB_OK or MB_ICONERROR);
  end;
end;

end.

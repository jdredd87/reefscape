unit MainForm;

{ The FMX app's window: the reef fills it, drawn with Skia.

  Keys:   F or F11 = full screen on / off,  S = settings,  Esc = leave full screen, or close
  Mouse:  double-click = full screen on / off,  right-click (or a long press on a touch screen) = settings

  Test options on the command line (desktop): hour=22 show=puffer shark=1 spawn=1 season=xmas diver=1
  fish=1 shrimp=1 light=night clock=both count=lots off=shark,eel seed=1 size=1280x720 full=1
  ff=20 (skip 20 seconds ahead)  quit=5 (close after 5 seconds)  shot=file.png (save a picture and close)
  log=file.txt (frame rate, with quit=)  settings=1 (open the settings straight away). }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math, System.Diagnostics, System.IOUtils,
  System.Skia,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Skia,
  ReefEngine, ReefRenderSkia, ReefSettings, ReefScene;

type
  TfrmMain = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
  private
    FBox: TSkAnimatedPaintBox;
    FScene: TOceanScene;
    FSettings: TReefSettings;
    FWatch: TStopwatch;
    FLast, FDrawTime: Double;
    FFastForward, FQuitAfter, FFrames, FSteady: Integer;
    FSceneW, FSceneH: Integer;
    FShot, FLog: string;
    FClosing, FOpenSettings: Boolean;
    procedure ReadOptions;
    procedure NewScene(W, H: Integer);
    procedure BoxDraw(ASender: TObject; const ACanvas: ISkCanvas; const ADest: TRectF; const AProgress: Double;
      const AOpacity: Single);
    procedure BoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure BoxDblClick(Sender: TObject);
    procedure BoxGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
    procedure SaveShot(W, H: Integer);
    procedure OpenSettings;
    procedure CloseSoon;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  SettingsForm;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Randomize;
  FSettings.Load;
  ReadOptions;
  FBox := TSkAnimatedPaintBox.Create(Self);
  FBox.Parent := Self;
  FBox.Align := TAlignLayout.Client;
  FBox.HitTest := True;
  // the animation only serves to ask for a new frame every time the display refreshes
  FBox.Animation.Loop := True;
  FBox.Animation.Duration := 60;
  FBox.OnAnimationDraw := BoxDraw;
  FBox.OnMouseDown := BoxMouseDown;
  FBox.OnDblClick := BoxDblClick;
  FBox.Touch.InteractiveGestures := [TInteractiveGesture.LongTap];
  FBox.OnGesture := BoxGesture;
  FWatch := TStopwatch.StartNew;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FScene);
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
    if P <= 0 then Continue;
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

procedure TfrmMain.NewScene(W, H: Integer);
var
  I: Integer;
begin
  FreeAndNil(FScene);
  FScene := TOceanScene.Create(FSettings, W, H);
  FSceneW := W;
  FSceneH := H;
  // test option: skip ahead in time
  for I := 1 to FFastForward * 30 do FScene.Advance(1 / 30);
  FFastForward := 0;
  FLast := FWatch.Elapsed.TotalSeconds;
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
  if (FScene <> nil) and ((W <> FSceneW) or (H <> FSceneH)) then
  begin
    Inc(FSteady);
    if (FSteady > 20) and (Abs(Max(1920, 1080 * W / H) - FScene.WorldWidth) > 0.02 * FScene.WorldWidth) then
      FreeAndNil(FScene)
    else if FSteady > 20 then
    begin
      FSceneW := W;
      FSceneH := H;
    end;
  end
  else
    FSteady := 0;
  if FScene = nil then NewScene(W, H);

  T := FWatch.Elapsed.TotalSeconds;
  FScene.SetView(W, H);
  FScene.Advance(EnsureRange(T - FLast, 0, 0.1));
  FLast := T;

  ACanvas.Save;
  try
    ACanvas.Translate(ADest.Left, ADest.Top);
    ACanvas.Scale(1 / Scale, 1 / Scale);
    SkiaRenderer.Canvas := ACanvas;
    FScene.Render(Rect(0, 0, W, H), H);
  finally
    SkiaRenderer.Canvas := nil;
    ACanvas.Restore;
  end;

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
      TFile.WriteAllText(FLog,Format('%d frames in %.1f s (%.1f per second), %.1f ms drawing per frame, %d x %d',
        [FFrames, T, FFrames / T, FDrawTime * 1000 / FFrames, W, H]));
    CloseSoon;
  end;
end;

{ test option shot=: the scene drawn once more into a picture of its own }
procedure TfrmMain.SaveShot(W, H: Integer);
var
  Surf: ISkSurface;
begin
  Surf := TSkSurface.MakeRaster(W, H);
  SkiaRenderer.Canvas := Surf.Canvas;
  try
    FScene.Render(Rect(0, 0, W, H), H);
  finally
    SkiaRenderer.Canvas := nil;
  end;
  Surf.MakeImageSnapshot.EncodeToFile(FShot);
end;

procedure TfrmMain.CloseSoon;
begin
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
  if (Key = vkF11) or (UpCase(KeyChar) = 'F') then
    FullScreen := not FullScreen
  else if UpCase(KeyChar) = 'S' then
    OpenSettings
  else if Key = vkEscape then
  begin
    if FullScreen then FullScreen := False else Close;
  end;
end;

procedure TfrmMain.BoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Button = TMouseButton.mbRight then OpenSettings;
end;

procedure TfrmMain.BoxDblClick(Sender: TObject);
begin
  FullScreen := not FullScreen;
end;

procedure TfrmMain.BoxGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
begin
  if (EventInfo.GestureID = igiLongTap) and (TInteractiveGestureFlag.gfEnd in EventInfo.Flags) then
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
      FreeAndNil(FScene);
    end);
end;

end.

program ReefscapeFMX;

{ Reefscape as a FireMonkey app, drawn with Skia. It shares the reef itself (ReefEngine, ReefSpecs,
  ReefCreature, ReefScene, ReefSettings in the parent folder) with the VCL screensaver; only the window and
  the renderer are its own. It takes the same command line as the screensaver (see AppArgs.pas). }

{$R *.res}

// all the artwork (the image list is written by ..\make-rc.ps1)
{$R 'ReefImages.res' 'ReefImages.rc'}

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Types,
  FMX.Skia,
  ReefEngine in '..\ReefEngine.pas',
  ReefSpecs in '..\ReefSpecs.pas',
  ReefCreature in '..\ReefCreature.pas',
  ReefSettings in '..\ReefSettings.pas',
  ReefScene in '..\ReefScene.pas',
  ReefRenderSkia in 'ReefRenderSkia.pas',
  AppArgs in 'AppArgs.pas',
  MainForm in 'MainForm.pas' {frmMain},
  SettingsForm in 'SettingsForm.pas' {frmSettings};

begin
  // every FMX control, and the reef, is drawn by Skia on the graphics card
  GlobalUseSkia := True;
  GlobalUseSkiaRasterWhenAvailable := False;
  ReadAppMode;
  Application.Initialize;
  if AppMode = amConfig then
    // /c: the settings form on its own
    Application.CreateForm(TfrmSettings, frmSettings)
  else
    Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

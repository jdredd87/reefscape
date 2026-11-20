program Reefscape;

{ Reefscape for Windows: the screensaver version of the Roku reef.
  The output is Reefscape.scr (a screensaver is an ordinary program with the .scr extension). }

{$E scr}

// icon, manifest, version and all the artwork (ReefRes.rc; the image list is written by make-rc.ps1)
{$R 'ReefRes.res' 'ReefRes.rc'}

uses
  Vcl.Forms,
  ReefEngine in 'ReefEngine.pas',
  ReefSpecs in 'ReefSpecs.pas',
  ReefCreature in 'ReefCreature.pas',
  ReefSettings in 'ReefSettings.pas',
  ReefScene in 'ReefScene.pas',
  ConfigForm in 'ConfigForm.pas' {frmConfig},
  SaverMain in 'SaverMain.pas';

begin
  RunSaver;
end.

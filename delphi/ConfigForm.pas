unit ConfigForm;

{ The settings dialog (Screen Saver Settings > Settings...). }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.CheckLst;

type
  TfrmConfig = class(TForm)
    lblTitle: TLabel;
    lblSub: TLabel;
    rgLight: TRadioGroup;
    rgClock: TRadioGroup;
    rgCount: TRadioGroup;
    rgScreens: TRadioGroup;
    lblAnimals: TLabel;
    clbAnimals: TCheckListBox;
    btnAll: TButton;
    btnNone: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    lblCredit: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnAllClick(Sender: TObject);
    procedure btnNoneClick(Sender: TObject);
  end;

procedure ShowConfig(Parent: HWND);

implementation

{$R *.dfm}

uses
  Vcl.Imaging.pngimage, ReefSettings;

procedure ShowConfig(Parent: HWND);
var
  F: TfrmConfig;
  I: Integer;
  Shot: string;
  Bmp: TBitmap;
  Png: TPngImage;
begin
  F := TfrmConfig.Create(nil);
  try
    // test option: shot=file.png saves a picture of the dialog instead of showing it
    Shot := '';
    for I := 1 to ParamCount do
      if LowerCase(ParamStr(I)).StartsWith('shot=') then Shot := ParamStr(I).Substring(5);
    if Shot <> '' then
    begin
      F.Show;
      F.Update;
      Application.ProcessMessages;
      Bmp := F.GetFormImage;
      Png := TPngImage.Create;
      try
        Png.Assign(Bmp);
        Png.SaveToFile(Shot);
      finally
        Png.Free;
        Bmp.Free;
      end;
    end
    else
      F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure TfrmConfig.FormCreate(Sender: TObject);
var
  S: TReefSettings;
  I: Integer;

  procedure Fill(Group: TRadioGroup; const Choices: array of TChoice; const Current: string);
  var
    K: Integer;
  begin
    Group.Items.Clear;
    for K := 0 to High(Choices) do
    begin
      Group.Items.Add(Choices[K].Caption);
      if Choices[K].Key = Current then Group.ItemIndex := K;
    end;
    if Group.ItemIndex < 0 then Group.ItemIndex := 0;
  end;

begin
  S.Load;
  Fill(rgLight, LightModes, S.Light);
  Fill(rgClock, ClockModes, S.Clock);
  Fill(rgCount, CountModes, S.Count);
  Fill(rgScreens, ScreenModes, S.Screens);
  clbAnimals.Items.Clear;
  for I := 0 to High(Animals) do
  begin
    clbAnimals.Items.Add(Animals[I].Caption);
    clbAnimals.Checked[I] := not S.IsOff(Animals[I].Key);
  end;
end;

procedure TfrmConfig.btnOKClick(Sender: TObject);
var
  S: TReefSettings;
  I: Integer;
begin
  S.Load;
  S.Light := LightModes[rgLight.ItemIndex].Key;
  S.Clock := ClockModes[rgClock.ItemIndex].Key;
  S.Count := CountModes[rgCount.ItemIndex].Key;
  S.Screens := ScreenModes[rgScreens.ItemIndex].Key;
  S.Off := '';
  for I := 0 to High(Animals) do
    if not clbAnimals.Checked[I] then
    begin
      if S.Off <> '' then S.Off := S.Off + ',';
      S.Off := S.Off + Animals[I].Key;
    end;
  S.Save;
  ModalResult := mrOk;
end;

procedure TfrmConfig.btnAllClick(Sender: TObject);
begin
  clbAnimals.CheckAll(cbChecked);
end;

procedure TfrmConfig.btnNoneClick(Sender: TObject);
begin
  clbAnimals.CheckAll(cbUnchecked);
end;

end.

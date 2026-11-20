unit SettingsForm;

{ The FMX app's settings: time of day, clock, how many animals, what to do with several screens, and which
  animals.
  The controls are created in code from the lists in ReefSettings.pas, so a new animal or option added there
  shows up here by itself. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Layouts, FMX.ListBox, FMX.Controls.Presentation,
  ReefSettings, AppArgs;

type
  TfrmSettings = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    FLight, FClock, FCount, FScreens: TArray<TRadioButton>;
    FAnimals: TListBox;
    function AddChoices(Parent: TFmxObject; const Title, Group: string; const Choices: array of TChoice;
      const Current: string): TArray<TRadioButton>;
    procedure CheckAll(Checked: Boolean);
    procedure AllClick(Sender: TObject);
    procedure NoneClick(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
  public
    { True when the form is the whole program (started with /c): OK and Cancel then close it }
    Standalone: Boolean;
  end;

var
  frmSettings: TfrmSettings;

{ shows the settings; OnSaved runs if they were changed and saved }
procedure ShowReefSettings(const OnSaved: TProc);
{ test helper: draws the settings form into a picture file without showing it }
procedure SaveSettingsPicture(const FileName: string);

implementation

{$R *.fmx}

procedure ShowReefSettings(const OnSaved: TProc);
var
  F: TfrmSettings;
begin
  F := TfrmSettings.Create(Application);
  // the callback form of ShowModal works on phones too, where a window cannot block its caller
  F.ShowModal(
    procedure(Result: TModalResult)
    begin
      if (Result = mrOk) and Assigned(OnSaved) then OnSaved();
      // freed once this event has returned
      TThread.ForceQueue(nil,
        procedure
        begin
          F.Free;
        end);
    end);
end;

procedure SaveSettingsPicture(const FileName: string);
var
  F: TfrmSettings;
  Bmp: TBitmap;
begin
  F := TfrmSettings.Create(Application);
  Bmp := TBitmap.Create(F.ClientWidth, F.ClientHeight);
  try
    if Bmp.Canvas.BeginScene then
    try
      Bmp.Canvas.Clear(TAlphaColors.White);
      F.PaintTo(Bmp.Canvas);
    finally
      Bmp.Canvas.EndScene;
    end;
    Bmp.SaveToFile(FileName);
  finally
    Bmp.Free;
    F.Free;
  end;
end;

function TfrmSettings.AddChoices(Parent: TFmxObject; const Title, Group: string; const Choices: array of TChoice;
  const Current: string): TArray<TRadioButton>;
var
  Head: TLabel;
  I: Integer;
  Any: Boolean;
begin
  Head := TLabel.Create(Self);
  Head.Parent := Parent;
  Head.Align := TAlignLayout.Top;
  Head.Position.Y := 10000;   // after what is already there
  Head.Margins.Top := 10;
  Head.Height := 22;
  Head.StyledSettings := Head.StyledSettings - [TStyledSetting.Style];
  Head.TextSettings.Font.Style := [TFontStyle.fsBold];
  Head.Text := Title;
  SetLength(Result, Length(Choices));
  Any := False;
  for I := 0 to High(Choices) do
  begin
    Result[I] := TRadioButton.Create(Self);
    Result[I].Parent := Parent;
    Result[I].Align := TAlignLayout.Top;
    Result[I].Position.Y := 10000;
    Result[I].Height := 24;
    Result[I].GroupName := Group;
    Result[I].Text := Choices[I].Caption;
    Result[I].IsChecked := Choices[I].Key = Current;
    Any := Any or Result[I].IsChecked;
  end;
  if not Any then Result[0].IsChecked := True;
end;

procedure TfrmSettings.FormCreate(Sender: TObject);
var
  S: TReefSettings;
  Bottom, Left, Right: TLayout;
  Scroll: TVertScrollBox;
  Lbl: TLabel;
  I: Integer;
  Item: TListBoxItem;

  function Button(Parent: TFmxObject; const Text: string; Align: TAlignLayout; Click: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Parent;
    Result.Align := Align;
    Result.Width := 90;
    Result.Margins.Left := 8;
    Result.Text := Text;
    Result.OnClick := Click;
  end;

begin
  S.Load;
  // started with /c: the form is the whole program
  Standalone := AppMode = amConfig;
  if Standalone then Position := TFormPosition.ScreenCenter;
  Padding.Rect := TRectF.Create(14, 10, 14, 12);

  Bottom := TLayout.Create(Self);
  Bottom.Parent := Self;
  Bottom.Align := TAlignLayout.Bottom;
  Bottom.Height := 30;
  Bottom.Margins.Top := 10;
  Button(Bottom, 'Cancel', TAlignLayout.Right, CancelClick).Cancel := True;
  Button(Bottom, 'OK', TAlignLayout.Right, OkClick).Default := True;
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Bottom;
  Lbl.Align := TAlignLayout.Client;
  Lbl.Opacity := 0.6;
  // (otherwise the & would mark a shortcut key and not be shown)
  Lbl.PrefixStyle := TPrefixStyle.NoPrefix;
  Lbl.Text := 'Created by Steven Chesser & Claude';

  // left: the choices (they scroll if the window is short, as on a phone held sideways)
  Left := TLayout.Create(Self);
  Left.Parent := Self;
  Left.Align := TAlignLayout.Left;
  Left.Width := 280;
  Scroll := TVertScrollBox.Create(Self);
  Scroll.Parent := Left;
  Scroll.Align := TAlignLayout.Client;
  FLight := AddChoices(Scroll, 'Time of day', 'light', LightModes, S.Light);
  FClock := AddChoices(Scroll, 'Clock', 'clock', ClockModes, S.Clock);
  FCount := AddChoices(Scroll, 'How many animals', 'count', CountModes, S.Count);
  // used when it runs full screen as a screensaver (/s)
  FScreens := AddChoices(Scroll, 'More than one screen', 'screens', ScreenModes, S.Screens);

  // right: the animals
  Right := TLayout.Create(Self);
  Right.Parent := Self;
  Right.Align := TAlignLayout.Client;
  Right.Margins.Left := 14;
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Right;
  Lbl.Align := TAlignLayout.Top;
  Lbl.Margins.Top := 10;
  Lbl.Height := 22;
  Lbl.StyledSettings := Lbl.StyledSettings - [TStyledSetting.Style];
  Lbl.TextSettings.Font.Style := [TFontStyle.fsBold];
  Lbl.Text := 'Animals and events to show';
  Bottom := TLayout.Create(Self);
  Bottom.Parent := Right;
  Bottom.Align := TAlignLayout.Bottom;
  Bottom.Height := 28;
  Bottom.Margins.Top := 6;
  Button(Bottom, 'All', TAlignLayout.Left, AllClick).Margins.Left := 0;
  Button(Bottom, 'None', TAlignLayout.Left, NoneClick);
  FAnimals := TListBox.Create(Self);
  FAnimals.Parent := Right;
  FAnimals.Align := TAlignLayout.Client;
  FAnimals.ShowCheckboxes := True;
  for I := 0 to High(Animals) do
  begin
    Item := TListBoxItem.Create(FAnimals);
    Item.Parent := FAnimals;
    Item.Text := Animals[I].Caption;
    Item.IsChecked := not S.IsOff(Animals[I].Key);
  end;
end;

procedure TfrmSettings.CheckAll(Checked: Boolean);
var
  I: Integer;
begin
  for I := 0 to FAnimals.Count - 1 do FAnimals.ListItems[I].IsChecked := Checked;
end;

procedure TfrmSettings.AllClick(Sender: TObject);
begin
  CheckAll(True);
end;

procedure TfrmSettings.NoneClick(Sender: TObject);
begin
  CheckAll(False);
end;

procedure TfrmSettings.OkClick(Sender: TObject);
var
  S: TReefSettings;
  I: Integer;

  function Chosen(const Buttons: TArray<TRadioButton>; const Choices: array of TChoice): string;
  var
    K: Integer;
  begin
    Result := Choices[0].Key;
    for K := 0 to High(Buttons) do
      if Buttons[K].IsChecked then Result := Choices[K].Key;
  end;

begin
  S.Load;
  S.Light := Chosen(FLight, LightModes);
  S.Clock := Chosen(FClock, ClockModes);
  S.Count := Chosen(FCount, CountModes);
  S.Screens := Chosen(FScreens, ScreenModes);
  S.Off := '';
  for I := 0 to High(Animals) do
    if not FAnimals.ListItems[I].IsChecked then
    begin
      if S.Off <> '' then S.Off := S.Off + ',';
      S.Off := S.Off + Animals[I].Key;
    end;
  S.Save;
  if Standalone then Close else ModalResult := mrOk;
end;

procedure TfrmSettings.CancelClick(Sender: TObject);
begin
  if Standalone then Close else ModalResult := mrCancel;
end;

end.

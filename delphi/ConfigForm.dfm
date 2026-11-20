object frmConfig: TfrmConfig
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Reefscape settings'
  ClientHeight = 620
  ClientWidth = 560
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblTitle: TLabel
    Left = 16
    Top = 12
    Width = 90
    Height = 25
    Caption = 'Reefscape'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'Segoe UI Semibold'
    Font.Style = []
    ParentFont = False
  end
  object lblSub: TLabel
    Left = 16
    Top = 40
    Width = 250
    Height = 15
    Caption = 'A living coral reef that follows the time of day.'
  end
  object lblAnimals: TLabel
    Left = 296
    Top = 68
    Width = 150
    Height = 15
    Caption = 'Animals and events to show'
  end
  object lblCredit: TLabel
    Left = 16
    Top = 591
    Width = 200
    Height = 15
    Caption = 'Created by Steven Chesser && Claude'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object rgLight: TRadioGroup
    Left = 16
    Top = 68
    Width = 264
    Height = 148
    Caption = 'Time of day'
    TabOrder = 0
  end
  object rgClock: TRadioGroup
    Left = 16
    Top = 224
    Width = 264
    Height = 124
    Caption = 'Clock'
    TabOrder = 1
  end
  object rgCount: TRadioGroup
    Left = 16
    Top = 356
    Width = 264
    Height = 100
    Caption = 'How many animals'
    TabOrder = 2
  end
  object rgScreens: TRadioGroup
    Left = 16
    Top = 464
    Width = 264
    Height = 116
    Caption = 'More than one screen'
    TabOrder = 8
  end
  object clbAnimals: TCheckListBox
    Left = 296
    Top = 88
    Width = 248
    Height = 429
    ItemHeight = 17
    TabOrder = 3
  end
  object btnAll: TButton
    Left = 296
    Top = 525
    Width = 75
    Height = 25
    Caption = 'All'
    TabOrder = 4
    OnClick = btnAllClick
  end
  object btnNone: TButton
    Left = 377
    Top = 525
    Width = 75
    Height = 25
    Caption = 'None'
    TabOrder = 5
    OnClick = btnNoneClick
  end
  object btnOK: TButton
    Left = 384
    Top = 586
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    TabOrder = 6
    OnClick = btnOKClick
  end
  object btnCancel: TButton
    Left = 469
    Top = 586
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 7
  end
end

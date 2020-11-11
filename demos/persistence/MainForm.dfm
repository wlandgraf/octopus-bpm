object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Octopus Persistence Test'
  ClientHeight = 403
  ClientWidth = 834
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  DesignSize = (
    834
    403)
  PixelsPerInch = 96
  TextHeight = 13
  object Memo1: TMemo
    Left = 8
    Top = 63
    Width = 809
    Height = 332
    Anchors = [akLeft, akTop, akRight, akBottom]
    Lines.Strings = (
      'Memo1')
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object Button1: TButton
    Left = 72
    Top = 32
    Width = 113
    Height = 25
    Caption = 'Update Database'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 232
    Top = 32
    Width = 113
    Height = 25
    Caption = 'create process'
    TabOrder = 2
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 504
    Top = 32
    Width = 113
    Height = 25
    Caption = 'list process'
    TabOrder = 3
    OnClick = Button3Click
  end
  object Button4: TButton
    Left = 648
    Top = 32
    Width = 113
    Height = 25
    Caption = 'retrieve process'
    TabOrder = 4
    OnClick = Button4Click
  end
  object Button5: TButton
    Left = 368
    Top = 32
    Width = 113
    Height = 25
    Caption = 'update process'
    TabOrder = 5
    OnClick = Button5Click
  end
end

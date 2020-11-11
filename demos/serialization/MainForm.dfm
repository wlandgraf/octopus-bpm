object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Octopus Serialization Test'
  ClientHeight = 561
  ClientWidth = 784
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnResize = FormResize
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 784
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btSerializeProcess: TButton
      Left = 10
      Top = 10
      Width = 120
      Height = 25
      Caption = 'Serialize Process'
      TabOrder = 0
      OnClick = btSerializeProcessClick
    end
    object btDeserializeProcess: TButton
      Left = 130
      Top = 10
      Width = 120
      Height = 25
      Caption = 'Deserialize Process'
      TabOrder = 1
      OnClick = btDeserializeProcessClick
    end
    object btSerializeInstance: TButton
      Left = 310
      Top = 10
      Width = 120
      Height = 25
      Caption = 'Serialize Instance'
      TabOrder = 2
      OnClick = btSerializeInstanceClick
    end
    object btDeserializeInstance: TButton
      Left = 430
      Top = 10
      Width = 120
      Height = 25
      Caption = 'Deserialize Instance'
      TabOrder = 3
      OnClick = btDeserializeInstanceClick
    end
  end
  object mmProcess: TMemo
    Left = 0
    Top = 41
    Width = 392
    Height = 520
    Align = alClient
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Courier New'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssBoth
    TabOrder = 1
  end
  object mmInstance: TMemo
    Left = 392
    Top = 41
    Width = 392
    Height = 520
    Align = alRight
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Courier New'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssBoth
    TabOrder = 2
  end
end

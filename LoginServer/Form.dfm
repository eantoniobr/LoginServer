object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Login Server'
  ClientHeight = 318
  ClientWidth = 635
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnDestroy = FormDestroy
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ServerLog: TRichEdit
    Left = 0
    Top = 5
    Width = 635
    Height = 281
    Font.Charset = THAI_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    Lines.Strings = (
      'ServerLog')
    ParentFont = False
    TabOrder = 0
    Zoom = 100
  end
  object CheckBox1: TCheckBox
    Left = 8
    Top = 292
    Width = 161
    Height = 21
    Caption = 'Put server into maintenance'
    TabOrder = 1
    OnClick = CheckBox1Click
  end
  object Button1: TButton
    Left = 400
    Top = 292
    Width = 75
    Height = 25
    Caption = 'Button1'
    TabOrder = 2
    OnClick = Button1Click
  end
  object FDConnection1: TFDConnection
    Left = 208
    Top = 152
  end
  object FDPhysMSSQLDriverLink1: TFDPhysMSSQLDriverLink
    Left = 336
    Top = 192
  end
end

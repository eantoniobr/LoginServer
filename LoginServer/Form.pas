unit Form;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Menus, Vcl.StdCtrls, Vcl.ComCtrls,
  System.Generics.Collections, Clients, {GameServer,}MainServer, Crypts, Utils, PangyaBuffer,
  FireDAC.UI.Intf, FireDAC.VCLUI.Wait, FireDAC.Stan.Intf, FireDAC.Comp.UI,
  FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS,
  FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt,
  Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.MySQL, FireDAC.Phys.MySQLDef,
  FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLDef, FireDAC.Phys.ODBCBase;

type
  TForm1 = class(TForm)
    ServerLog: TRichEdit;
    CheckBox1: TCheckBox;
    Button1: TButton;
    FDConnection1: TFDConnection;
    FDPhysMSSQLDriverLink1: TFDPhysMSSQLDriverLink;
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  GameServerHandle : TLoginServer;

implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
begin

    //FDQuery1.Open('EXEC [dbo].[GER_MEMBER] @Memorial = :test', ['toppyz']);
  //ServerLog.Lines.Add(format('%f , %s',[gettickcount - x, FDQuery1.FieldByName('RES').AsString ]));
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
  if not CheckBox1.Checked then
  begin
    GameServerHandle.IsUnderMaintenance := False;
  end;
  if CheckBox1.Checked then
  begin
    GameServerHandle.IsUnderMaintenance := True;
  end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  GameServerHandle.Destroy;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  GameServerHandle := TLoginServer.Create;
  GameServerHandle.Run;
end;

end.


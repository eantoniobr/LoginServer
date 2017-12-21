program Project1;

{$APPTYPE CONSOLE}

{.$DEFINE ENABLEFORM}

uses
  Windows,
  SysUtils,
  Vcl.Forms,
  Form in 'Form.pas' {Form1},
  CryptLib in 'Crypts\CryptLib.pas',
  Crypts in 'Crypts\Crypts.pas',
  Clients in 'Clients.pas',
  Buffer in 'Packets\Buffer.pas',
  ClientPacket in 'Packets\ClientPacket.pas',
  PangyaBuffer in 'Packets\PangyaBuffer.pas',
  Tools in 'Tools\Tools.pas',
  Utils in 'Utils.pas',
  AuthClient in 'AuthClient.pas',
  FiredacPooling in 'Database\FiredacPooling.pas',
  MainServer in 'MainServer.pas',
  Console in 'Tools\Console.pas',
  UWriteConsole in 'Tools\UWriteConsole.pas',
  MyList in 'MyList.pas',
  ExceptionLog in 'ExceptionLog.pas';

{$R *.res}

var
  Msg: TMsg;
  bRet: LongBool;
  GameServerHandle: TLoginServer;

begin
{$IFDEF ENABLEFORM}
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
{$ELSE}
  try
    SetConsoleTitle('Pangya Fresh UP! Login Server');
    GameServerHandle := TLoginServer.Create;
    GameServerHandle.Run;
    repeat
      bRet := GetMessage(Msg, 0, 0, 0);
      if Integer(bRet) = -1 then
      begin
        Break;
      end
      else
      begin
        TranslateMessage(Msg);
        DispatchMessage(Msg);
      end;
    until not bRet;
  except
    on E: Exception do
    begin
      Writeln(E.Classname + ': ' + E.Message);
    end;
  end;
{$ENDIF}

end.

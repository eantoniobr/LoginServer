unit MainServer;

interface

uses
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.MySQL, FireDAC.Phys.MySQLDef, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  Windows, Classes, IdBaseComponent, IdComponent, IdCustomTCPServer, IdTCPServer, IdContext,
  IdTCPConnection, SysUtils, Clients, SerialID,
  FiredacPooling, Tools, Utils, PangyaBuffer, MyList, AuthClient, UWriteConsole, ExceptionLog;

type
  TLoginServer = class
  private
    var FServer: TIdTCPServer;
    var FPlayers: TMyList<TClientPlayer>;
    var FSerialID : TSerialId;
    var FIsUnderMaintenance: Boolean;

    procedure OnConnect(AContext: TIdContext);
    procedure OnExecute(AContext: TIdContext);
    procedure onDisconnect(AContext: TIdContext);

    {$Hints Off}
    function GetPlayerByContext(AContext: TIdContext): TClientPlayer;
    {$Hints On}
  public
    constructor Create;
    destructor Destroy; override;

    procedure Run;
    procedure Shutdown;
    procedure Send(Data: TPangyaBuffer);

    function GetPlayerByNickname(const Nickname: AnsiString): TClientPlayer;
    function GetPlayerByUsername(const Username: AnsiString): TClientPlayer;
    function GetClientByConnectionId(ConnectionId: UInt32): TClientPlayer;

    property IsUnderMaintenance: Boolean read FIsUnderMaintenance write FIsUnderMaintenance;
  end;

implementation

{ TMainServer }

constructor TLoginServer.Create;
begin
  FServer := TIdTCPServer.Create;
  FServer.DefaultPort := 10201;

  FServer.OnConnect := OnConnect;
  FServer.OnExecute := OnExecute;
  FServer.OnDisconnect := onDisconnect;
  FServer.UseNagle := True;

  FPlayers := TMyList<TClientPlayer>.Create;
  FSerialID := TSerialId.Create;
  FIsUnderMaintenance := False;

  AuthControlClient.ClientList := FPlayers;
end;

destructor TLoginServer.Destroy;
begin
  FSerialID.Free;
  FPlayers.Free;
  FServer.Free;
  inherited;
end;

function TLoginServer.GetClientByConnectionId(ConnectionId: UInt32): TClientPlayer;
begin
  for Result in FPlayers do
    if Result.ConnectionId = ConnectionId then
      Exit;

  Result := nil;
end;

function TLoginServer.GetPlayerByContext(AContext: TIdContext): TClientPlayer;
begin
  for Result in FPlayers do
    if Result.Context = AContext then
      Exit;

  Result := nil;
end;

function TLoginServer.GetPlayerByNickname(const Nickname: AnsiString): TClientPlayer;
begin
  for Result in FPlayers do
    if Result.GetPlayerNickname = Nickname then
      Exit;

  Result := nil;
end;

function TLoginServer.GetPlayerByUsername(const Username: AnsiString): TClientPlayer;
begin
  for Result in FPlayers do
    if Result.GetPlayerLogin = Username then
      Exit;

  Result := nil;
end;

procedure TLoginServer.OnConnect(AContext: TIdContext);
var
  Client: TClientPlayer;
begin
  Client := TClientPlayer.Create(AContext);
  Client.ConnectionId := FSerialID.GetId;

  Client.LoginServer := Self;

  AContext.Data := Client;

  FPlayers.Add(Client);

  Client.SendKey;

  WriteConsole(AnsiFormat('Client Connected to %s:%d with Connect Id %d',[ AContext.Binding.PeerIP, AContext.Binding.PeerPort, Client.ConnectionId]))
end;

procedure TLoginServer.onDisconnect(AContext: TIdContext);
begin
  if Assigned(AContext.Data) and (AContext.Data is TClientPlayer) then
  begin
    WriteConsole( AnsiFormat('User (%s) is disconnected',[TClientPlayer(AContext.Data).GetPlayerLogin]) );
    FPlayers.Remove(TClientPlayer(AContext.Data));
    FSerialID.RemoveId(TClientPlayer(AContext.Data).ConnectionId);
    TClientPlayer(AContext.Data).Free;
    AContext.Data := nil;
  end;
end;

procedure TLoginServer.OnExecute(AContext: TIdContext);
var
  Con: TIdTCPConnection;
  Data: TMemoryStream;
  Buffer: AnsiString;
  Player: TClientPlayer;
begin
  Con := AContext.Connection;
  repeat
    if not Con.IOHandler.InputBufferIsEmpty then
    begin

      Data := TMemoryStream.Create;

      Con.IOHandler.InputBufferToStream(Data);

      if (not Assigned(AContext.Data)) or (not (AContext.Data is TClientPlayer)) then
      begin
        Con.Disconnect;
      end
      else
        try
          Player := TClientPlayer(AContext.Data);
          SetString(Buffer, PAnsiChar(Data.Memory), Data.Size);
          try
            Player.PacketProcess(Buffer);
          finally
            Data.Free;
          end;
        except
          on E: Exception do
          begin
            WriteConsole( AnsiFormat('User: %s causes exception with message: %s', [Player.GetPlayerLogin, E.Message]));
            FException.SaveLog(Player.GetPlayerUID, Player.GetPlayerLogin, AnsiString(E.Message));
          end;
        end;
    end;
    SleepEx(1, True);
  until (not Con.Connected);
end;

procedure TLoginServer.Run;
begin
  FServer.Active := True;
  WriteConsole( AnsiFormat(' Server is running at %d ', [FServer.DefaultPort]) , $0A);
end;

procedure TLoginServer.Send(Data: TPangyaBuffer);
var
  Client: TClientPlayer;
begin
  for Client in FPlayers do
  begin
    Client.Send(Data);
  end;
end;

procedure TLoginServer.Shutdown;
begin
  FServer.Active := False;
end;

end.

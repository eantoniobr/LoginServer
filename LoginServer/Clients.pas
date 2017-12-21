unit Clients;

interface

uses
  {FIREDAC}
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.MySQL, FireDAC.Phys.MySQLDef, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  {END OF FIREDAC}
  System.SyncObjs, Classes, IdContext, CryptLib, PangyaBuffer, Buffer,
  ClientPacket, Crypts, Tools, UWriteconsole, System.SysUtils;

Type
  TClientPlayer = class
      private
        var FStatus : Boolean;
        var FKey : Byte;
        var FLogin : AnsiString;
        var FNickname : AnsiString;
        var FUID : UInt32;
        var FAuthKeyLogin : AnsiString;
        var FAuthKeyGame : AnsiString;
        var FVerified: Boolean;
        var FConnectionID : UInt32;

        var FSocket: TIdContext;
        var FBuffer: TBuffer;
        var FLoginServer: TObject;
        var FCrypts: TCrypt;
        var FRecvCrit, FSendCrit: TCriticalSection;
      public
        var DupStyle : Byte;
        var FFirstSet : Byte;
        function GetKey: Byte;

        procedure SendKey;
        procedure PacketProcess(const PacketData: AnsiString);

        //{Login Processor}
        procedure HandlePlayerLogin(Const clientPacket: TClientPacket);
        procedure SendPlayerLoggedOnData;
        procedure SendGameAuthKey;
        procedure HandleDuplicateLogin;
        procedure CreateCharacter(Const clientPacket : TClientPacket);
        procedure NicknameCheck(Const clientPacket: TClientPacket);
        procedure RequestCharacaterCreate(Const clientPacket: TClientPacket);

        procedure Send(Const Data : AnsiString; Encrypt : Boolean = True); overload;
        procedure Send(Data : TPangyaBuffer; Encrypt : Boolean  = True ); overload;
        procedure Disconnect;
        function SetStatus( TStatus : Boolean): Boolean;
        function SetSocket( TSocket : TIdContext): Boolean;
        function SetKey( TKey : Byte): Boolean;
        function SetLogin(Const TLogin : AnsiString): Boolean;
        function SetNickname(Const TNickname : AnsiString): Boolean;
        function SetUID(TUID : Integer): Boolean;
        function SetAUTH_KEY_1(Const TAUTH_KEY_1 : AnsiString): Boolean;
        function SetAUTH_KEY_2(Const TAUTH_KEY_2 : AnsiString): Boolean;
        function GetPlayerAddress: AnsiString;
        function GetPlayerStatus: Boolean;
        function GetPlayerSocket: TIdContext;
        function GetPlayerKey: Byte;
        function GetPlayerLogin: AnsiString;
        function GetPlayerNickname: AnsiString;
        function GetPlayerUID : UInt32;
        function GetPlayerAuth1 : AnsiString;
        function GetPlayerAuth2 : AnsiString;
        constructor Create(TSocket : TIdContext);
        destructor Destroy;  override;

        property Context: TIdContext read FSocket;
        property LoginServer: TObject read FLoginServer write FLoginServer;
        property ConnectionID: UInt32 read FConnectionID write FConnectionID;
  end;

implementation

uses
  MainServer, AuthClient;

{ TClientPlayer }

procedure TClientPlayer.Send(Const Data: AnsiString; Encrypt: Boolean);
var
  Stream: TMemoryStream;
  ToSend: AnsiString;
begin
  if not FSocket.Connection.Connected then
  begin
    Exit;
  end;

  if Length(Data) <= 0 then
  begin
    Exit;
  end;

  Stream := TMemoryStream.Create;
  try
    if Encrypt then
    begin
      ToSend := FCrypts.Encrypt(Data, Self.FKey);
      Stream.Write(ToSend[1], Length(ToSend));
    end
    else
    begin
      Stream.Write(Data[1], Length(Data));
    end;

    FSendCrit.Acquire;
    try
      FSocket.Connection.IOHandler.Write(Stream);
    finally
      FSendCrit.Leave;
    end;
  finally
    Stream.Free;
  end;
end;

procedure TClientPlayer.Send(Data: TPangyaBuffer; Encrypt : Boolean = True);
var
  OldPosition: Integer;
  Size: Integer;
  Buffer: AnsiString;
  Stream: TMemoryStream;
begin

  FSendCrit.Acquire;
  Stream := TMemoryStream.Create;
  try
    OldPosition := Data.Seek(0, 1);
    Data.Seek(0, 0);
    Size := Data.GetSize;
    Data.ReadStr(Buffer, Size);
    Data.Seek(OldPosition, 0);

    if not FSocket.Connection.Connected then Exit;

    if Length(Buffer) <= 0 then Exit;

    if Encrypt then
    begin
      Buffer := FCrypts.Encrypt(Buffer, Self.FKey);
      Stream.Write(Buffer[1], Length(Buffer));
    end
    else
    begin
      Stream.Write(Buffer[1], Length(Buffer));
    end;

    FSocket.Connection.IOHandler.Write(Stream);
  finally
    Stream.Free;
    FSendCrit.Leave;
  end;
end;

{ TClientPlayer }


constructor TClientPlayer.Create(TSocket: TIdContext);
begin
  Self.FSocket := TSocket;
  Randomize;
  Self.FKey := Random($F) + 1;
  FBuffer := TBuffer.Create;
  DupStyle := 1;
  FUID := 0;
  FVerified := False;
  FConnectionID := 0;

  FCrypts := TCrypt.Create;
  FRecvCrit := TCriticalSection.Create;
  FSendCrit := TCriticalSection.Create;
end;

destructor TClientPlayer.Destroy;
begin
  FBuffer.Free;
  FCrypts.Free;
  FRecvCrit.Free;
  FSendCrit.Free;
  inherited;
end;

procedure TClientPlayer.Disconnect;
begin
  FSocket.Connection.Disconnect;;
end;

function TClientPlayer.GetKey: Byte;
begin
  Exit(FKey);
end;

function TClientPlayer.GetPlayerAddress: AnsiString;
begin
  Exit(AnsiString(Self.FSocket.Binding.PeerIP));
end;

function TClientPlayer.GetPlayerAuth1: AnsiString;
begin
  Exit(Self.FAuthKeyLogin);
end;

function TClientPlayer.GetPlayerAuth2: AnsiString;
begin
  Exit(Self.FAuthKeyGame);
end;

function TClientPlayer.GetPlayerKey: Byte;
begin
  Exit(FKey);
end;

function TClientPlayer.GetPlayerLogin: AnsiString;
begin
  Exit(Self.FLogin);
end;

function TClientPlayer.GetPlayerNickname: AnsiString;
begin
  Exit(Self.FNickname);
end;

function TClientPlayer.GetPlayerSocket: TIdContext;
begin
  Exit(FSocket);
end;

function TClientPlayer.GetPlayerStatus: Boolean;
begin
  Exit(Self.FStatus);
end;

function TClientPlayer.GetPlayerUID: UInt32;
begin
  Exit(Self.FUID);
end;

procedure TClientPlayer.PacketProcess(const PacketData: AnsiString);
var
  BuffTemp: TBuffer;
  ProcessPacket: TClientPacket;
  Size, realPacketSize: UInt32;
  X, Y, Rand: Integer;
  Buffer: AnsiString;
  PacketId: UInt16;
begin
  FRecvCrit.Acquire;

  BuffTemp := TBuffer.Create;
  ProcessPacket := TClientPacket.Create;
  Size := 0;
  try
    BuffTemp.Write(PacketData);

    if (BuffTemp.GetLength > 2) then
    begin
      move(BuffTemp.GetData[2], Size, 2);
    end
    else
    begin
      Exit;
    end;

    realPacketSize := Size + 4;

    while BuffTemp.GetLength >= realPacketSize do
    begin
      Buffer := BuffTemp.Read(0, realPacketSize);
      BuffTemp.Delete(0, realPacketSize);

      // SECURITY CHECK
      Rand := Ord(Buffer[1]);
      X := Byte(Keys[((Self.GetPlayerKey) shl 8) + Rand + 1]);
      Y := Byte(Keys[((Self.GetPlayerKey) shl 8) + Rand + 4097]);

      if not (y = (x xor ord(Buffer[5]))) then
      begin
        Exit;
      end;
      // SECURITY CHECK

      Buffer := FCrypts.Decrypt(Buffer, Self.GetKey);
      Delete(Buffer, 1, 5);

      ProcessPacket.Clear;
      ProcessPacket.WriteStr(Buffer);
      ProcessPacket.Seek(0, 0);

      if not ProcessPacket.ReadUInt16(PacketId) then
      begin
        Exit;
      end;

      if not (PacketId = 1) and not (FVerified) then
      begin
        Exit;
      end;

      case PacketId of
        1:
          begin
            Self.HandlePlayerLogin(ProcessPacket);
          end;
        3:
          begin
            Self.SendGameAuthKey;
          end;
        4:
          begin
            Self.HandleDuplicateLogin;
          end;
        6:
          begin
            Self.CreateCharacter(ProcessPacket);
          end;
        7:
          begin
            Self.NicknameCheck(ProcessPacket);
          end;
        8:
          begin
            Self.RequestCharacaterCreate(ProcessPacket);
          end;
      else
        WriteConsole('{Unknown Packet} -> ' + ShowHex(Buffer), 11);
      end;

      if (BuffTemp.GetLength > 2) then
      begin
        Move(BuffTemp.GetData[2], Size, 2);
        realPacketSize := Size + 4;
      end
      else
      begin
        Exit;
      end;
    end; {END WHILE}
  finally
    BuffTemp.Free;
    ProcessPacket.Free;
    FRecvCrit.Leave;
  end;
end;

procedure TClientPlayer.SendKey;
var
  Reply: TPangyaBuffer;
begin
  Reply := TPangyaBuffer.Create;
  try
    Reply.WriteStr(#$00#$0B#$00#$00#$00#$00);
    Reply.WriteInt32(FKey);
    Reply.WriteStr(#$75#$27#$00#$00);
    Send(Reply, False);
  finally
    Reply.Free;
  end;
end;

function TClientPlayer.SetAUTH_KEY_1(Const TAUTH_KEY_1: AnsiString): Boolean;
begin
  Self.FAuthKeyLogin := TAUTH_KEY_1;
  Result := True;
end;

function TClientPlayer.SetAUTH_KEY_2(Const TAUTH_KEY_2: AnsiString): Boolean;
begin
  Self.FAuthKeyGame := TAUTH_KEY_2;
  Result := True;
end;

function TClientPlayer.SetKey(TKey: Byte): Boolean;
begin
  FKey := TKey;
  Result := True;
end;

function TClientPlayer.SetLogin(Const TLogin: AnsiString): Boolean;
begin
  Self.FLogin := TLogin;
  Result := True;
end;

function TClientPlayer.SetNickname(Const TNickname: AnsiString): Boolean;
begin
  Self.FNickname := TNickname;
  Result := True;
end;

function TClientPlayer.SetSocket(TSocket: TIdContext): Boolean;
begin
  FSocket := TSocket;
  Result := True;
end;

function TClientPlayer.SetStatus(TStatus: Boolean): Boolean;
begin
  Self.FStatus := TStatus;
  Result := True;
end;

function TClientPlayer.SetUID(TUID: Integer): Boolean;
begin
  Self.FUID := TUID;
  Result := True;
end;

{HERE BELOW IS LOGIN PROCESSOR}


procedure TClientPlayer.HandleDuplicateLogin;
var
  Reply : TPangyaBuffer;
  Packet : TClientPacket;
begin
  Reply := TPangyaBuffer.Create;
  Packet := TClientPacket.Create;
  try
    Packet.WriteStr(#$03#$00);
    Packet.WriteUInt32(Self.GetPlayerUID);
    AuthControlClient.Send(Packet.ToStr);

    if Self.FFirstSet = 0 then
    begin
      Reply.Clear;
      Reply.WriteStr(#$0F#$00#$00);
      Reply.WritePStr(Self.GetPlayerLogin);
      Self.Send(Reply);

      Reply.Clear;
      Reply.WriteStr(#$01#$00#$D9#$FF#$FF#$FF#$FF);
      Self.Send(Reply);
      Exit;
    end;

    if Self.FFirstSet = 1 then
    begin
      Self.SendPlayerLoggedOnData;
    end;

  finally
    Reply.Free;
    Packet.Free;
  end;
end;

procedure TClientPlayer.HandlePlayerLogin(const clientPacket: TClientPacket);
var
  User, Pwd: AnsiString;
  Code: Byte;
  Banned: Byte;
  UID: Integer;
  Nickname: AnsiString;
  FirstSet: Byte;
  Auth1, Auth2: AnsiString;
  Reply: TPangyaBuffer;
  Packet: TClientPacket;
  Query: TFDQuery;
  Con: TFDConnection;
begin
  if TLoginServer(FLoginServer).IsUnderMaintenance then
  begin
    Send(#$01#$00#$E3#$48#$D2#$4D#$00, True);
    Disconnect;
    Exit;
  end;

  if not ClientPacket.ReadPStr(User) then Exit;
  if not ClientPacket.ReadPStr(Pwd) then Exit;

  if not ( TLoginServer(FLoginServer).GetPlayerByUsername(User) = nil) then
  begin
    Self.Send(#$01#$00#$E3#$4B#$D2#$4D#$00, True);
    Self.Disconnect;
    Exit;
  end;

  Query := TFDQuery.Create(nil);
  Con := TFDConnection.Create(nil);
  Reply := TPangyaBuffer.Create;
  try
    {********** CON & STORE PROC CREATION ************}
    Con.ConnectionDefName := 'MSSQLPool';
    Query.Connection := Con;
    {******************* END *************************}

    Auth1 := RandomAuth(7);
    Auth2 := RandomAuth(7);

    Query.Open('EXEC [dbo].[USP_LOGIN_SERVER] @User = :User, @Pwd = :Pwd, @IPAddress = :IPADR, @Auth1 = :AUTH1, @Auth2 = :AUTH2',
      [User, Pwd, GetPlayerAddress, Auth1, Auth2]);

    Code := Query.FieldByName('CODE').AsInteger;

    {-- USER NOT FOUND --}
    if Code = 5 then
    begin
      Reply.Clear;
      Reply.WriteStr(#$01#$00#$E3#$6F#$D2#$4D#$00);
      Self.Send(Reply);

      Self.Disconnect;
      Exit;
    end;

    {-- PASSWORD ERROR --}
    if Code = 6 then
    begin
      Reply.Clear;
      Reply.WriteStr(#$01#$00#$E3#$5B#$D2#$4D#$00);
      Self.Send(Reply);
      Self.Disconnect;
      Exit;
    end;

    Banned := Query.FieldByName('IDState').AsInteger;

    if Banned > 0 then
    begin
      Reply.Clear;
      Reply.WriteStr(#$01#$00#$E3#$F4#$D1#$4D#$00);
      Self.Send(Reply);
      Self.Disconnect;
      Exit;
    end;

    FirstSet := Query.FieldByName('FirstSet').AsInteger;
    UID := Query.FieldByName('UID').AsLongWord;
    Nickname := Query.FieldByName('Nickname').AsAnsiString;

    Self.SetLogin(User);
    Self.SetUID(UID);
    Self.SetNickname(Nickname);
    Self.SetAUTH_KEY_1(Auth1);
    Self.SetAUTH_KEY_2(Auth2);
    Self.FFirstSet := FirstSet;
    Self.FVerified := True;

    if Query.FieldByName('Logon').AsInteger = 1 then
    begin
      Self.Send(#$01#$00#$E3#$F3#$D1#$4D#$00, True);
      Exit;
    end;

    Packet := TClientPacket.Create;
    try
      Packet.WriteStr(#$03#$00);
      Packet.WriteUInt32(UID);
      AuthControlClient.Send(Packet.ToStr);
    finally
      Packet.Free;
    end;

    if Self.FFirstSet = 0 then
    begin
      Reply.Clear;
      Reply.WriteStr(#$0F#$00#$00);
      Reply.WritePStr(Self.GetPlayerLogin);
      Self.Send(Reply);

      Reply.Clear;
      Reply.WriteStr(#$01#$00#$D9#$FF#$FF#$FF#$FF);
      Self.Send(Reply);
      Exit;
    end;

  finally
    Query.Free;
    Con.Free;
    Reply.Free;
  end;

  if Self.FFirstSet = 1 then
  begin
    Self.SendPlayerLoggedOnData;
  end;
end;

procedure TClientPlayer.SendPlayerLoggedOnData;
var
  Reply: TPangyaBuffer;
  Query: TFDQuery;
  Con: TFDConnection;
begin
  Query := TFDQuery.Create(nil);
  Con := TFDConnection.Create(nil);
  Reply := TPangyaBuffer.Create;
  try
    {********** CON & STORE PROC CREATION ************}
    Con.ConnectionDefName := 'MSSQLPool';
    Query.Connection := Con;
    {******************* END *************************}

    Reply.WriteStr(#$10#$00);
    Reply.WritePStr(Self.GetPlayerAuth1);
    Self.Send(Reply);

    Reply.Clear;
    Reply.WriteStr(#$01#$00#$00);
    Reply.WritePStr(Self.GetPlayerLogin);
    Reply.WriteUInt32(Self.GetPlayerUID);
    Reply.WriteStr(#$00#$00#$00#$00);
    Reply.WriteStr(#$00#$00#$00#$00); // Level
    Reply.WriteStr(#$00#$00#$00#$00#$00#$00);
    Reply.WritePStr(Self.GetPlayerNickname);
    Self.Send(Reply);

    Query.Open('[dbo].[ProcGetGameServer]');

    Reply.Clear;
    Reply.WriteStr(#$02#$00);
    Reply.WriteUInt8(Query.RecordCount);

    while not Query.Eof do
    begin
      Reply.WriteStr(Query.FieldByName('Name').AsAnsiString, 10);
      Reply.WriteStr(
        #$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00 +
        #$68#$29#$22#$13#$00#$00#$00#$00#$00#$00#$00#$00
      );
      Reply.WriteUInt32(Query.FieldByName('ServerID').AsLongWord);
      Reply.WriteStr(
        #$B0#$04#$00#$00 + // Max Player
        #$38#$01#$00#$00   // Total Player Online
      );
      Reply.WriteStr(Query.FieldByName('IP').AsAnsiString, 16);
      Reply.WriteStr(#$60#$29);
      Reply.WriteUInt16(Query.FieldByName('Port').AsInteger);
      Reply.WriteStr(#$00#$00#$00#$08#$00#$00);
      Reply.WriteUInt32(1); // Angelic Number
      Reply.WriteUInt16(Query.FieldByName('ImgEvent').AsInteger);
      Reply.WriteStr(#$00#$00#$00#$00#$00#$00);
      Reply.WriteUInt16(Query.FieldByName('ImgNo').AsInteger);

      Query.Next;
    end;

    Self.Send(Reply);

    // MESSENGER
    Query.Open('[dbo].[ProcGetMessengerServer]');

    Reply.Clear;
    Reply.WriteStr(#$09#$00);
    Reply.WriteUInt8(Query.RecordCount);

    while not Query.Eof do
    begin
      Reply.WriteStr(Query.FieldByName('Name').AsAnsiString, 20);
      Reply.WriteStr(#$00, 8);
      Reply.WriteUInt32(321388144); // Maybe Version
      Reply.WriteStr(#$00, 8);
      Reply.WriteUInt32(Query.FieldByName('ServerID').AsInteger);
      Reply.WriteUInt32(3000); // Max User
      Reply.WriteUInt32(10); // Current User
      Reply.WriteStr(Query.FieldByName('IP').AsAnsiString, 16);
      Reply.WriteStr(#$68#$FE);
      Reply.WriteUInt16(Query.FieldByName('Port').AsInteger);
      Reply.WriteStr(#$00, 3);
      Reply.WriteUInt32(10); //App Rate
      Reply.WriteStr(#$00, 13);
      Query.Next;
    end;
    Self.Send(Reply);

    // F1 F2 F3
    Query.Open('EXEC [dbo].[ProcGetMacro] @UID = :UID',[Self.GetPlayerUID]);

    Reply.Clear;
    Reply.WriteStr(#$06#$00);
    Reply.WriteStr(Query.FieldByName('Macro1').AsAnsiString , $40);
    Reply.WriteStr(Query.FieldByName('Macro2').AsAnsiString , $40);
    Reply.WriteStr(Query.FieldByName('Macro3').AsAnsiString , $40);
    Reply.WriteStr(Query.FieldByName('Macro4').AsAnsiString , $40);
    Reply.WriteStr(Query.FieldByName('Macro5').AsAnsiString , $40);
    Reply.WriteStr(Query.FieldByName('Macro6').AsAnsiString , $40);
    Reply.WriteStr(Query.FieldByName('Macro7').AsAnsiString , $40);
    Reply.WriteStr(Query.FieldByName('Macro8').AsAnsiString , $40);
    Reply.WriteStr(Query.FieldByName('Macro9').AsAnsiString , $40);
    Self.Send(Reply);

  finally
    Query.Free;
    Con.Free;
    Reply.Free;
  end;
end;

procedure TClientPlayer.SendGameAuthKey;
var
  Reply: TPangyaBuffer;
begin
  Reply := TPangyaBuffer.Create;
  try
    Reply.WriteStr(#$03#$00#$00#$00#$00#$00);
    Reply.WritePStr(Self.GetPlayerAuth2);
    Self.Send(Reply);
  finally
    Reply.Free;
  end;
end;

procedure TClientPlayer.CreateCharacter(const clientPacket: TClientPacket);
var
  Nickname: AnsiString;
  Reply: TPangyaBuffer;
begin
  if not clientPacket.ReadPStr(Nickname) then Exit;

  Self.SetNickname(Nickname);

  Reply := TPangyaBuffer.Create;
  try
    Reply.WriteStr(#$01#$00#$DA);
    Self.Send(Reply);
  finally
    Reply.Free;
  end;
end;

procedure TClientPlayer.NicknameCheck(const clientPacket: TClientPacket);
var
  Code: Byte;
  Nickname: AnsiString;
  Query: TFDQuery;
  Con: TFDConnection;
  Reply: TPangyaBuffer;
begin
  if not clientPacket.ReadPStr(Nickname) then Exit;

  Reply := TPangyaBuffer.Create;
  Query := TFDQuery.Create(nil);
  Con := TFDConnection.Create(nil);
  try

    {********** CON & STORE PROC CREATION ************}
    Con.ConnectionDefName := 'MSSQLPool';
    Query.Connection := Con;
    {******************* END *************************}

    Query.Open('EXEC [dbo].[USP_NICKNAME_CHECK] @NICKNAME = :Nick', [Nickname]);

    Code := Query.FieldByName('Code').AsInteger;

    if (Code = 0) or (Code = 2) then
    begin
      Reply.Clear;
      Reply.WriteStr(#$0E#$00#$0C#$00#$00#$00#$21#$D2#$4D#$00);
      Self.Send(Reply);
      Exit;
    end;

    if Code = 1 then
    begin
      Reply.Clear;
      Reply.WriteStr(#$0E#$00#$00#$00#$00#$00);
      Reply.WritePStr(Nickname);
      Self.Send(Reply);
      Exit;
    end;
  finally
    Query.Free;
    Con.Free;
    Reply.Free;
  end;
end;

procedure TClientPlayer.RequestCharacaterCreate(const clientPacket: TClientPacket);
var
  CHAR_TYPEID: UInt32;
  HAIR_COLOR: UInt16;
  Query: TFDQuery;
  Con: TFDConnection;
  Reply: TPangyaBuffer;
begin
  if not ClientPacket.ReadUInt32(CHAR_TYPEID) then Exit;
  if not ClientPacket.ReadUInt16(HAIR_COLOR) then Exit;

  Query := TFDQuery.Create(nil);
  Con := TFDConnection.Create(nil);
  try
    { ********** CON & STORE PROC CREATION ************ }
    Con.ConnectionDefName := 'MSSQLPool';
    Query.Connection := Con;
    { ******************* END ************************* }

    Query.Open('EXEC [dbo].[USP_FIRST_CREATION] @UID = :UID, @CHAR_TYPEID = :CHARTYPE, @HAIRCOLOUR = :HAIR, @NICKNAME = :NICK',
      [Self.GetPlayerUID, CHAR_TYPEID, HAIR_COLOR, Self.GetPlayerNickname]);

    if not(Query.FieldByName('CODE').AsInteger = 1) then
    begin
      Self.Disconnect;
      Exit;
    end;
  finally
    Query.Free;
    Con.Free;
  end;

  Reply := TPangyaBuffer.Create;
  try
    Reply.WriteStr(#$11#$00#$00);
    Self.Send(Reply);
  finally
    Reply.Free;
  end;

  Self.SendPlayerLoggedOnData;
end;

end.

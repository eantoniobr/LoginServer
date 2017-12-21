unit DatabaseConnections;

interface

uses ZConnection, ZAbstractRODataset, ZAbstractDataset, ZDataset, ZStoredProcedure, SysUtils, Tools;

var
  FCon: TZConnection;

type
  TDatabaseConnection = class
  private
    procedure Init();
  public
    constructor Create();
    destructor Destroy; override;

    function GetQuery: TZQuery;
    function GetProc: TZStoredProc;
    function GetCon: TZConnection;
  end;

var
  DatabaseConnection : TDatabaseConnection;

implementation

{ TDatabaseConnection }

constructor TDatabaseConnection.Create();
begin
  Init();
end;

destructor TDatabaseConnection.Destroy;
begin
  FCon.Free;
  inherited;
end;

procedure TDatabaseConnection.Init();
begin
  if not Assigned(FCon) then begin
    FCon := TZConnection.Create(nil);
    FCon.Protocol := 'MariaDB-10';
    FCon.HostName := 'localhost';
    FCon.Port := 3306;
    FCon.Catalog := 'py_new';
    FCon.Database := 'py_new';
    FCon.User := 'pangya';
    FCon.Password := '1';
    FCon.LibraryLocation := 'lib/libmariadb.dll';
    FCon.AutoCommit := True;
    FCon.ClientCodepage := 'utf8';
    FCon.AutoEncodeStrings := True;
    FCon.Properties.Add('CLIENT_MULTI_STATEMENTS=1');
    try
      FCon.Connect;
    except
      on E: Exception do begin
        WriteLn(E.Message);
      end;
    end;
  end;
  
  if FCon.Ping = False then begin
    Writeln( 'Lost connection from MySQL Server , try to reconnect' );
    FCon.Reconnect;
  end else begin
    Tool.Write( ' Database Connected ', 11);
  end;
end;

function TDatabaseConnection.GetQuery: TZQuery;
begin
  Result := TZQuery.Create(nil);
  Result.Connection := FCon;
end;

function TDatabaseConnection.GetProc: TZStoredProc;
begin
  Result := TZStoredProc.Create(nil);
  Result.Connection := FCon;
end;

function TDatabaseConnection.GetCon: TZConnection;
begin
  Result := FCon;
end;

end.
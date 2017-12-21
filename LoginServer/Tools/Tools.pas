unit Tools;

interface

uses
  Messages, SysUtils, DateUtils, Math , Classes, Graphics, System.Threading, PangyaBuffer, ClientPacket, Console, AnsiStrings;

Type
  TServerTime = packed record
    var Year,Month,DayOfWeek,Day,Hour,Min,Sec,MilliSec: UInt16;
  end;

  procedure NullString(var StringVariable: AnsiString); inline;
  function GetTime: AnsiString; overload; inline;
  function GetFixTime(FixDateTime: TDateTime): AnsiString; overload; inline;
  function GetSQLTime(DateTime: TDateTime): string; inline;
  function GetCaddieTypeIDBySkinID(SkinTypeID: UInt32): UInt32; inline;
  function GetItemGroup(TypeID : UInt32): UInt32; inline;
  function GetZero(CharCount: UInt32): AnsiString; inline;
  function MemoryStreamToString(Data: TMemoryStream): AnsiString;
  function ShowHex(const txt : AnsiString) : AnsiString; inline;
  function Space(const Text: AnsiString): AnsiString; inline;
  function RandomChar(Count : Word; UpperInclude : Boolean = False): AnsiString; inline;
  function RandomAuth(Count : Word): AnsiString; inline;
  function AnsiFormat(const Format: AnsiString; const Args: array of const): AnsiString;


implementation

{ TTool }

function GetTime: AnsiString;
var
  CurrentDate : TDateTime;
  ServerTime: TServerTime;
begin
  CurrentDate := Now;

  with ServerTime do
  begin
    Year        := StrToInt(ForMatDateTime('yyyy',CurrentDate));
    Month       := StrToInt(ForMatDateTime('m',CurrentDate));
    DayOfWeek   := DayOfTheWeek(CurrentDate);
    Day         := StrToInt(ForMatDateTime('d',CurrentDate));
    Hour        := StrToInt(ForMatDateTime('h',CurrentDate));
    Min         := StrToInt(ForMatDateTime('n',CurrentDate));
    Sec      := StrToInt(ForMatDateTime('s',CurrentDate));
    MilliSec    := StrToInt(ForMatDateTime('z',CurrentDate));
  end;

  SetLength(Result , SizeOf(TServerTime));
  Move(ServerTime.Year, Result[1], SizeOf(TServerTime));
  Exit(Result);
end;

function GetFixTime(FixDateTime: TDateTime): AnsiString;
var
  ServerTime: TServerTime;
begin
  if IsZero(Date) then
  begin
    Exit(GetZero($10));
  end;

  with ServerTime do
  begin
    Year      := StrToInt(ForMatDateTime('yyyy', FixDateTime));
    Month     := StrToInt(ForMatDateTime('m', FixDateTime));
    DayOfWeek := DayOfTheWeek(FixDateTime);
    Day       := StrToInt(ForMatDateTime('d', FixDateTime));
    Hour      := StrToInt(ForMatDateTime('h', FixDateTime));
    Min       := StrToInt(ForMatDateTime('n', FixDateTime));
    Sec    := StrToInt(ForMatDateTime('s', FixDateTime));
    MilliSec  := StrToInt(ForMatDateTime('z', FixDateTime));
  end;

  SetLength(Result , SizeOf(TServerTime));
  Move(ServerTime.Year, Result[1], SizeOf(TServerTime));
  Exit(Result);
end;

function GetSQLTime(DateTime: TDateTime): string;
var
  Date,Time: string;
  StringBuilder: TStringBuilder;
begin
  DateTimeToString(Date, 'yyyy-mm-dd', DateTime);
  DateTimeToString(Time, 'hh:nn:ss', DateTime);

  StringBuilder := TStringBuilder.Create;
  try
    StringBuilder.Append(Date);
    StringBuilder.Append('T');
    StringBuilder.Append(Time);
    Exit(StringBuilder.ToString);
  finally
    StringBuilder.Free;
  end;
end;

function MemoryStreamToString(Data: TMemoryStream): AnsiString;
begin
  SetString(Result, PAnsiChar(Data.Memory), Data.Size);
end;

procedure NullString(var StringVariable: AnsiString);
begin
  StringVariable := '';
end;

function ShowHex(const txt: AnsiString): AnsiString;
var
  a : integer ;
  st : TStringStream;
  buf : array [0..1] of AnsiChar;
  tmp : ShortString;
begin
  st := TStringStream.Create;
  st.Size := Length(txt)*2;
  st.Position := 0;
  for a:=1 to Length(txt) do
  begin
    tmp := ShortString(IntToHex(Ord(txt[a]),2));
    buf[0] := tmp[1];
    buf[1] := tmp[2];
    st.Write(buf,2);
  end;
  st.Position := 0;
  Result := Space(AnsiString(st.DataString));
  st.Free;
end;

function GetItemGroup(TypeID : UInt32): UInt32;
begin
  Exit(Round((TypeID and 4227858432)/Power(2,26)));
end;

function GetCaddieTypeIDBySkinID(SkinTypeID: UInt32): UInt32;
var
  CaddieTypeID: UInt32;
begin
  CaddieTypeID := Round( ( (SkinTypeId AND $0FFF0000) SHR 16 ) / 32 );
  Result := (CaddieTypeID + $1C000000) + ((SkinTypeID AND $000F0000) SHR 16);
end;

function RandomAuth(Count: Word): AnsiString;
var
  Str: AnsiString;
begin
  Randomize;
  Str    := 'abcdefg1234567890';
  Result := '';
  repeat
    Result := Result + Str[Random(Length(Str)) + 1];
  until (Length(Result) = Count)

end;

function RandomChar(Count: Word; UpperInclude : Boolean = False): AnsiString;
var
  Str: AnsiString;
begin
  Randomize;
  Str    := 'abcdefghijklmnopqrstuvwxyz0123456789';
  if UpperInclude then
    Str := Str + 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  Result := '';
  repeat
    Result := Result + Str[Random(Length(Str)) + 1];
  until (Length(Result) = Count)
end;


function Space(const Text: AnsiString): AnsiString;
var
  Index: Integer;
begin
  Index := 3;
  Result := Copy(Text, 0, 2);
  while Index <= Length(Text) do
  begin
    Result := Result + ' ' + Copy(Text, Index, 2);
    Index := Index + 2;
  end;
end;

function GetZero(CharCount: UInt32): AnsiString;
var
  Count: UInt32;
  StringBuilder: TStringBuilder;
begin
  StringBuilder := TStringBuilder.Create;
  try
    for Count := 1 to UInt32(CharCount) do
    begin
      StringBuilder.Append(#$00);
    end;
    Exit(AnsiString(StringBuilder.ToString));
  finally
    StringBuilder.Free;
  end;
end;

function AnsiFormat(const Format: AnsiString; const Args: array of const): AnsiString;
begin
  Exit(AnsiStrings.Format(Format, Args));
end;

end.

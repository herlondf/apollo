unit Apollo.Sink.OTLP;

interface

uses
  System.SysUtils,
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  IApolloOTLPSink = interface(IApolloSink)
    ['{C4D5E6F7-A8B9-0123-4567-890123DEF012}']
    function ResourceAttribute(const AKey, AValue: string): IApolloOTLPSink;
    function BearerToken(const AToken: string): IApolloOTLPSink;
    function Authorization(const AHeaderValue: string): IApolloOTLPSink;
  end;

  TApolloOTLPSink = class(TInterfacedObject, IApolloSink, IApolloOTLPSink)
  private
    FCollectorURL: string;
    FMinLevel: TApolloLogLevel;
    FResourceAttributes: TArray<TPair<string, string>>;
    FAuthHeader: string;
    function LevelToSeverityNumber(const ALevel: TApolloLogLevel): Integer;
    function DateTimeToUnixNano(const ADateTime: TDateTime): Int64;
    function BuildBody(const AEntries: TArray<TApolloLogEntry>): string;
    function BuildLogRecord(const AEntry: TApolloLogEntry): string;
    function BuildResourceAttributes: string;
    procedure SendBatch(const ABody: string);
  public
    class function New(const ACollectorURL: string;
      const AMinLevel: TApolloLogLevel = llInfo): IApolloOTLPSink;
    constructor Create(const ACollectorURL: string;
      const AMinLevel: TApolloLogLevel);
    function ResourceAttribute(const AKey, AValue: string): IApolloOTLPSink;
    function BearerToken(const AToken: string): IApolloOTLPSink;
    function Authorization(const AHeaderValue: string): IApolloOTLPSink;
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;

implementation

uses
  System.Classes,
  System.DateUtils,
  System.Net.HttpClient;

{ TApolloOTLPSink }

class function TApolloOTLPSink.New(const ACollectorURL: string;
  const AMinLevel: TApolloLogLevel): IApolloOTLPSink;
begin
  Result := TApolloOTLPSink.Create(ACollectorURL, AMinLevel);
end;

constructor TApolloOTLPSink.Create(const ACollectorURL: string;
  const AMinLevel: TApolloLogLevel);
begin
  inherited Create;
  FCollectorURL := ACollectorURL;
  FMinLevel := AMinLevel;
  FResourceAttributes := [];
  FAuthHeader := '';
end;

function TApolloOTLPSink.MinLevel: TApolloLogLevel;
begin
  Result := FMinLevel;
end;

function TApolloOTLPSink.ResourceAttribute(const AKey,
  AValue: string): IApolloOTLPSink;
var
  LIdx: Integer;
begin
  LIdx := Length(FResourceAttributes);
  SetLength(FResourceAttributes, LIdx + 1);
  FResourceAttributes[LIdx] := TPair<string, string>.Create(AKey, AValue);
  Result := Self;
end;

function TApolloOTLPSink.BearerToken(const AToken: string): IApolloOTLPSink;
begin
  FAuthHeader := 'Bearer ' + AToken;
  Result := Self;
end;

function TApolloOTLPSink.Authorization(const AHeaderValue: string): IApolloOTLPSink;
begin
  FAuthHeader := AHeaderValue;
  Result := Self;
end;

function TApolloOTLPSink.LevelToSeverityNumber(const ALevel: TApolloLogLevel): Integer;
begin
  case ALevel of
    llTrace: Result := 1;
    llDebug: Result := 5;
    llInfo:  Result := 9;
    llWarn:  Result := 13;
    llError: Result := 17;
    llFatal: Result := 21;
  else
    Result := 9;
  end;
end;

function TApolloOTLPSink.DateTimeToUnixNano(const ADateTime: TDateTime): Int64;
begin
  Result := DateTimeToUnix(ADateTime, False) * Int64(1000000000);
end;

function TApolloOTLPSink.BuildResourceAttributes: string;
var
  LBuilder: TStringBuilder;
  LPair: TPair<string, string>;
  LFirst: Boolean;
begin
  LBuilder := TStringBuilder.Create;
  try
    LFirst := True;
    for LPair in FResourceAttributes do
    begin
      if not LFirst then
        LBuilder.Append(',');
      LFirst := False;
      LBuilder.Append('{"key":"');
      LBuilder.Append(StringReplace(LPair.Key, '"', '\"', [rfReplaceAll]));
      LBuilder.Append('","value":{"stringValue":"');
      LBuilder.Append(StringReplace(LPair.Value, '"', '\"', [rfReplaceAll]));
      LBuilder.Append('"}}');
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function TApolloOTLPSink.BuildLogRecord(const AEntry: TApolloLogEntry): string;
var
  LBuilder: TStringBuilder;
  LPair: TPair<string, TApolloFieldValue>;
  LFirst: Boolean;
  LFmt: TFormatSettings;
begin
  LFmt := TFormatSettings.Invariant;
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.Append('{');
    LBuilder.Append('"timeUnixNano":"');
    LBuilder.Append(IntToStr(DateTimeToUnixNano(AEntry.Timestamp)));
    LBuilder.Append('"');
    LBuilder.Append(',"severityNumber":');
    LBuilder.Append(IntToStr(LevelToSeverityNumber(AEntry.Level)));
    LBuilder.Append(',"severityText":"');
    LBuilder.Append(LevelToString(AEntry.Level));
    LBuilder.Append('"');
    LBuilder.Append(',"body":{"stringValue":"');
    LBuilder.Append(StringReplace(AEntry.Message, '"', '\"', [rfReplaceAll]));
    LBuilder.Append('"}');

    if Length(AEntry.Fields) > 0 then
    begin
      LBuilder.Append(',"attributes":[');
      LFirst := True;
      for LPair in AEntry.Fields do
      begin
        if not LFirst then
          LBuilder.Append(',');
        LFirst := False;
        LBuilder.Append('{"key":"');
        LBuilder.Append(LPair.Key);
        LBuilder.Append('","value":{');
        case LPair.Value.Kind of
          fkInt64:   begin
            LBuilder.Append('"intValue":');
            LBuilder.Append(IntToStr(LPair.Value.AsInt64));
          end;
          fkDouble:  begin
            LBuilder.Append('"doubleValue":');
            LBuilder.Append(FloatToStr(LPair.Value.AsDouble, LFmt));
          end;
          fkBoolean: begin
            LBuilder.Append('"boolValue":');
            if LPair.Value.AsBoolean then LBuilder.Append('true')
            else LBuilder.Append('false');
          end;
        else
          LBuilder.Append('"stringValue":"');
          LBuilder.Append(StringReplace(LPair.Value.AsString, '"', '\"', [rfReplaceAll]));
          LBuilder.Append('"');
        end;
        LBuilder.Append('}}');
      end;
      LBuilder.Append(']');
    end;

    if AEntry.TraceId <> '' then
    begin
      LBuilder.Append(',"traceId":"');
      LBuilder.Append(AEntry.TraceId);
      LBuilder.Append('"');
    end;
    if AEntry.SpanId <> '' then
    begin
      LBuilder.Append(',"spanId":"');
      LBuilder.Append(AEntry.SpanId);
      LBuilder.Append('"');
    end;

    LBuilder.Append('}');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function TApolloOTLPSink.BuildBody(const AEntries: TArray<TApolloLogEntry>): string;
var
  LBuilder: TStringBuilder;
  LEntry: TApolloLogEntry;
  LFirst: Boolean;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.Append('{"resourceLogs":[{"resource":{"attributes":[');
    LBuilder.Append(BuildResourceAttributes);
    LBuilder.Append(']}');
    LBuilder.Append(',"scopeLogs":[{"scope":{"name":"apollo"}');
    LBuilder.Append(',"logRecords":[');

    LFirst := True;
    for LEntry in AEntries do
    begin
      if not LFirst then
        LBuilder.Append(',');
      LFirst := False;
      LBuilder.Append(BuildLogRecord(LEntry));
    end;

    LBuilder.Append(']}]}]}');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

procedure TApolloOTLPSink.SendBatch(const ABody: string);
var
  LHttp: THTTPClient;
  LBodyStream: TStringStream;
  LURL: string;
begin
  LHttp := THTTPClient.Create;
  try
    LURL := FCollectorURL + '/v1/logs';
    LHttp.CustomHeaders['Content-Type'] := 'application/json';
    if FAuthHeader <> '' then
      LHttp.CustomHeaders['Authorization'] := FAuthHeader;

    LBodyStream := TStringStream.Create(ABody, TEncoding.UTF8);
    try
      LHttp.Post(LURL, LBodyStream);
    finally
      LBodyStream.Free;
    end;
  finally
    LHttp.Free;
  end;
end;

procedure TApolloOTLPSink.Write(const AEntries: TArray<TApolloLogEntry>);
var
  LBody: string;
begin
  if Length(AEntries) = 0 then
    Exit;
  LBody := BuildBody(AEntries);
  try
    SendBatch(LBody);
  except
    on E: Exception do
      WriteLn(ErrOutput, '[Apollo][OTLPSink] ' + E.ClassName + ': ' + E.Message);
  end;
end;

end.

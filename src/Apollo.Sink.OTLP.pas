unit Apollo.Sink.OTLP;

interface

uses
  System.SysUtils,
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  TApolloOTLPSink = class(TInterfacedObject, IApollSink)
  private
    FCollectorURL: string;
    FServiceName: string;
    FMinLevel: TApolloLogLevel;
    function LevelToSeverityNumber(const ALevel: TApolloLogLevel): Integer;
    function DateTimeToUnixNano(const ADateTime: TDateTime): Int64;
    function BuildBody(const AEntries: TArray<TApolloLogEntry>): string;
    function BuildLogRecord(const AEntry: TApolloLogEntry): string;
    procedure SendBatch(const ABody: string);
  public
    class function New(const ACollectorURL: string;
      const AServiceName: string = 'app';
      const AMinLevel: TApolloLogLevel = llInfo): IApollSink;
    constructor Create(const ACollectorURL: string; const AServiceName: string;
      const AMinLevel: TApolloLogLevel);
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
  const AServiceName: string; const AMinLevel: TApolloLogLevel): IApollSink;
begin
  Result := TApolloOTLPSink.Create(ACollectorURL, AServiceName, AMinLevel);
end;

constructor TApolloOTLPSink.Create(const ACollectorURL: string;
  const AServiceName: string; const AMinLevel: TApolloLogLevel);
begin
  inherited Create;
  FCollectorURL := ACollectorURL;
  FServiceName := AServiceName;
  FMinLevel := AMinLevel;
end;

function TApolloOTLPSink.MinLevel: TApolloLogLevel;
begin
  Result := FMinLevel;
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

function TApolloOTLPSink.BuildLogRecord(
  const AEntry: TApolloLogEntry): string;
var
  LBuilder: TStringBuilder;
  LPair: TPair<string, string>;
  LFirst: Boolean;
begin
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
        LBuilder.Append('","value":{"stringValue":"');
        LBuilder.Append(StringReplace(LPair.Value, '"', '\"', [rfReplaceAll]));
        LBuilder.Append('"}}');
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

function TApolloOTLPSink.BuildBody(
  const AEntries: TArray<TApolloLogEntry>): string;
var
  LBuilder: TStringBuilder;
  LEntry: TApolloLogEntry;
  LFirst: Boolean;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.Append('{"resourceLogs":[{"resource":{"attributes":[');
    LBuilder.Append('{"key":"service.name","value":{"stringValue":"');
    LBuilder.Append(FServiceName);
    LBuilder.Append('"}}]}');
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
    // Swallow exceptions to avoid disrupting application flow
  end;
end;

end.

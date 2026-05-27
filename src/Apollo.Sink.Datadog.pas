unit Apollo.Sink.Datadog;

interface

uses
  System.SysUtils,
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  TApolloDatadogSink = class(TInterfacedObject, IApolloSink)
  private
    FApiKey: string;
    FService: string;
    FEndpointURL: string;
    FMinLevel: TApolloLogLevel;
    function LevelToStatus(const ALevel: TApolloLogLevel): string;
    function BuildBody(const AEntries: TArray<TApolloLogEntry>): string;
    procedure SendBatch(const ABody: string);
    function DateTimeToUnixMs(const ADateTime: TDateTime): Int64;
    function GetHostName: string;
  public
    class function New(const AApiKey: string; const AService: string = 'app';
      const ASite: string = 'us';
      const AMinLevel: TApolloLogLevel = llInfo): IApolloSink;
    constructor Create(const AApiKey: string; const AService: string;
      const AEndpointURL: string; const AMinLevel: TApolloLogLevel);
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;

implementation

uses
  System.Classes,
  System.DateUtils,
  System.Net.HttpClient;

{ TApolloDatadogSink }

class function TApolloDatadogSink.New(const AApiKey: string;
  const AService: string; const ASite: string;
  const AMinLevel: TApolloLogLevel): IApolloSink;
var
  LURL: string;
begin
  if ASite = 'eu' then
    LURL := 'https://http-intake.logs.datadoghq.eu/api/v2/logs'
  else
    LURL := 'https://http-intake.logs.datadoghq.com/api/v2/logs';
  Result := TApolloDatadogSink.Create(AApiKey, AService, LURL, AMinLevel);
end;

constructor TApolloDatadogSink.Create(const AApiKey: string;
  const AService: string; const AEndpointURL: string;
  const AMinLevel: TApolloLogLevel);
begin
  inherited Create;
  FApiKey := AApiKey;
  FService := AService;
  FEndpointURL := AEndpointURL;
  FMinLevel := AMinLevel;
end;

function TApolloDatadogSink.MinLevel: TApolloLogLevel;
begin
  Result := FMinLevel;
end;

function TApolloDatadogSink.LevelToStatus(const ALevel: TApolloLogLevel): string;
begin
  case ALevel of
    llTrace: Result := 'trace';
    llDebug: Result := 'debug';
    llInfo:  Result := 'info';
    llWarn:  Result := 'warn';
    llError: Result := 'error';
    llFatal: Result := 'critical';
  else
    Result := 'info';
  end;
end;

function TApolloDatadogSink.DateTimeToUnixMs(const ADateTime: TDateTime): Int64;
begin
  Result := DateTimeToUnix(ADateTime, False) * Int64(1000);
end;

function TApolloDatadogSink.GetHostName: string;
begin
  Result := GetEnvironmentVariable('COMPUTERNAME');
  if Result = '' then
    Result := GetEnvironmentVariable('HOSTNAME');
  if Result = '' then
    Result := 'unknown';
end;

function TApolloDatadogSink.BuildBody(
  const AEntries: TArray<TApolloLogEntry>): string;
var
  LBuilder: TStringBuilder;
  LEntry: TApolloLogEntry;
  LPair: TPair<string, TApolloFieldValue>;
  LFirst: Boolean;
  LFirstField: Boolean;
  LHostName: string;
begin
  LHostName := GetHostName;
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.Append('[');
    LFirst := True;
    for LEntry in AEntries do
    begin
      if not LFirst then
        LBuilder.Append(',');
      LFirst := False;

      LBuilder.Append('{"ddsource":"delphi"');
      LBuilder.Append(',"ddtags":"env:prod"');
      LBuilder.Append(',"hostname":"');
      LBuilder.Append(LHostName);
      LBuilder.Append('"');
      LBuilder.Append(',"service":"');
      LBuilder.Append(FService);
      LBuilder.Append('"');
      LBuilder.Append(',"status":"');
      LBuilder.Append(LevelToStatus(LEntry.Level));
      LBuilder.Append('"');
      LBuilder.Append(',"message":"');
      LBuilder.Append(StringReplace(LEntry.Message, '"', '\"', [rfReplaceAll]));
      LBuilder.Append('"');
      LBuilder.Append(',"timestamp":');
      LBuilder.Append(IntToStr(DateTimeToUnixMs(LEntry.Timestamp)));
      if LEntry.Logger <> '' then
      begin
        LBuilder.Append(',"logger":"');
        LBuilder.Append(LEntry.Logger);
        LBuilder.Append('"');
      end;
      if LEntry.TraceId <> '' then
      begin
        LBuilder.Append(',"traceId":"');
        LBuilder.Append(LEntry.TraceId);
        LBuilder.Append('"');
      end;
      if LEntry.SpanId <> '' then
      begin
        LBuilder.Append(',"spanId":"');
        LBuilder.Append(LEntry.SpanId);
        LBuilder.Append('"');
      end;
      for LPair in LEntry.Fields do
      begin
        LBuilder.Append(',"');
        LBuilder.Append(LPair.Key);
        LBuilder.Append('":');
        case LPair.Value.Kind of
          fkInt64:   LBuilder.Append(IntToStr(LPair.Value.AsInt64));
          fkDouble:  LBuilder.Append(FloatToStr(LPair.Value.AsDouble));
          fkBoolean: if LPair.Value.AsBoolean then LBuilder.Append('true')
                     else LBuilder.Append('false');
        else
          LBuilder.Append('"');
          LBuilder.Append(StringReplace(LPair.Value.AsString, '"', '\"', [rfReplaceAll]));
          LBuilder.Append('"');
        end;
      end;
      LBuilder.Append('}');
    end;
    LBuilder.Append(']');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

procedure TApolloDatadogSink.SendBatch(const ABody: string);
var
  LHttp: THTTPClient;
  LBodyStream: TStringStream;
begin
  LHttp := THTTPClient.Create;
  try
    LHttp.CustomHeaders['DD-API-KEY'] := FApiKey;
    LHttp.CustomHeaders['Content-Type'] := 'application/json';

    LBodyStream := TStringStream.Create(ABody, TEncoding.UTF8);
    try
      LHttp.Post(FEndpointURL, LBodyStream);
    finally
      LBodyStream.Free;
    end;
  finally
    LHttp.Free;
  end;
end;

procedure TApolloDatadogSink.Write(const AEntries: TArray<TApolloLogEntry>);
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

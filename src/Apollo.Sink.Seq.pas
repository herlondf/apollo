unit Apollo.Sink.Seq;

interface

uses
  System.SysUtils,
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  TApolloSeqSink = class(TInterfacedObject, IApollSink)
  private
    FBaseURL: string;
    FApiKey: string;
    FMinLevel: TApolloLogLevel;
    function LevelToCLEF(const ALevel: TApolloLogLevel): string;
    function BuildCLEFBody(const AEntries: TArray<TApolloLogEntry>): string;
    function EntrytoCLEF(const AEntry: TApolloLogEntry): string;
    procedure SendBatch(const ABody: string);
  public
    class function New(const ABaseURL: string; const AApiKey: string = '';
      const AMinLevel: TApolloLogLevel = llInfo): IApollSink;
    constructor Create(const ABaseURL: string; const AApiKey: string;
      const AMinLevel: TApolloLogLevel);
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;

implementation

uses
  System.Classes,
  System.JSON,
  System.Net.HttpClient;

{ TApolloSeqSink }

class function TApolloSeqSink.New(const ABaseURL: string;
  const AApiKey: string; const AMinLevel: TApolloLogLevel): IApollSink;
begin
  Result := TApolloSeqSink.Create(ABaseURL, AApiKey, AMinLevel);
end;

constructor TApolloSeqSink.Create(const ABaseURL: string;
  const AApiKey: string; const AMinLevel: TApolloLogLevel);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  FApiKey := AApiKey;
  FMinLevel := AMinLevel;
end;

function TApolloSeqSink.MinLevel: TApolloLogLevel;
begin
  Result := FMinLevel;
end;

function TApolloSeqSink.LevelToCLEF(const ALevel: TApolloLogLevel): string;
begin
  case ALevel of
    llTrace: Result := 'Verbose';
    llDebug: Result := 'Debug';
    llInfo:  Result := 'Information';
    llWarn:  Result := 'Warning';
    llError: Result := 'Error';
    llFatal: Result := 'Fatal';
  else
    Result := 'Information';
  end;
end;

function TApolloSeqSink.EntrytoCLEF(const AEntry: TApolloLogEntry): string;
var
  LObj: TJSONObject;
  LPair: TPair<string, string>;
  LYear, LMonth, LDay, LHour, LMin, LSec, LMs: Word;
begin
  LObj := TJSONObject.Create;
  try
    DecodeDateTime(AEntry.Timestamp, LYear, LMonth, LDay, LHour, LMin, LSec, LMs);
    LObj.AddPair('@t', Format('%.4d-%.2d-%.2dT%.2d:%.2d:%.2d.%.3dZ',
      [LYear, LMonth, LDay, LHour, LMin, LSec, LMs]));
    LObj.AddPair('@l', LevelToCLEF(AEntry.Level));
    LObj.AddPair('@mt', AEntry.Message);
    if AEntry.Logger <> '' then
      LObj.AddPair('logger', AEntry.Logger);
    if AEntry.TraceId <> '' then
      LObj.AddPair('traceId', AEntry.TraceId);
    if AEntry.SpanId <> '' then
      LObj.AddPair('spanId', AEntry.SpanId);
    for LPair in AEntry.Fields do
      LObj.AddPair(LPair.Key, LPair.Value);
    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

function TApolloSeqSink.BuildCLEFBody(
  const AEntries: TArray<TApolloLogEntry>): string;
var
  LBuilder: TStringBuilder;
  LEntry: TApolloLogEntry;
begin
  LBuilder := TStringBuilder.Create;
  try
    for LEntry in AEntries do
      LBuilder.AppendLine(EntrytoCLEF(LEntry));
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

procedure TApolloSeqSink.SendBatch(const ABody: string);
var
  LHttp: THTTPClient;
  LBodyStream: TStringStream;
  LURL: string;
begin
  LHttp := THTTPClient.Create;
  try
    LURL := FBaseURL + '/api/events/raw';
    LHttp.CustomHeaders['Content-Type'] := 'application/vnd.serilog.clef';
    if FApiKey <> '' then
      LHttp.CustomHeaders['X-Seq-ApiKey'] := FApiKey;

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

procedure TApolloSeqSink.Write(const AEntries: TArray<TApolloLogEntry>);
var
  LBody: string;
begin
  if Length(AEntries) = 0 then
    Exit;
  LBody := BuildCLEFBody(AEntries);
  try
    SendBatch(LBody);
  except
    // Swallow exceptions to avoid disrupting application flow
  end;
end;

end.

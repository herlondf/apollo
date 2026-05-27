unit Apollo.Sink.Elasticsearch;

interface

uses
  System.SysUtils,
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  TApolloElasticsearchSink = class(TInterfacedObject, IApolloSink)
  private
    FBaseURL: string;
    FMinLevel: TApolloLogLevel;
    FAuthHeader: string;
    procedure SendBulk(const ABody: string);
    function BuildBulkBody(const AEntries: TArray<TApolloLogEntry>): string;
    function IndexName(const ATimestamp: TDateTime): string;
  public
    class function New(const ABaseURL: string; const AUser: string = '';
      const APassword: string = '';
      const AMinLevel: TApolloLogLevel = llInfo): IApolloSink;
    class function NewWithApiKey(const ABaseURL, AApiKey: string;
      const AMinLevel: TApolloLogLevel = llInfo): IApolloSink;
    constructor Create(const ABaseURL: string; const AAuthHeader: string;
      const AMinLevel: TApolloLogLevel);
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;

implementation

uses
  System.Classes,
  System.NetEncoding,
  System.Net.HttpClient;

{ TApolloElasticsearchSink }

class function TApolloElasticsearchSink.New(const ABaseURL: string;
  const AUser: string; const APassword: string;
  const AMinLevel: TApolloLogLevel): IApolloSink;
var
  LAuth: string;
  LEncoded: string;
begin
  LAuth := '';
  if AUser <> '' then
  begin
    LEncoded := TNetEncoding.Base64.Encode(AUser + ':' + APassword);
    LAuth := 'Basic ' + LEncoded;
  end;
  Result := TApolloElasticsearchSink.Create(ABaseURL, LAuth, AMinLevel);
end;

class function TApolloElasticsearchSink.NewWithApiKey(const ABaseURL,
  AApiKey: string; const AMinLevel: TApolloLogLevel): IApolloSink;
begin
  Result := TApolloElasticsearchSink.Create(ABaseURL,
    'ApiKey ' + AApiKey, AMinLevel);
end;

constructor TApolloElasticsearchSink.Create(const ABaseURL: string;
  const AAuthHeader: string; const AMinLevel: TApolloLogLevel);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  FAuthHeader := AAuthHeader;
  FMinLevel := AMinLevel;
end;

function TApolloElasticsearchSink.MinLevel: TApolloLogLevel;
begin
  Result := FMinLevel;
end;

function TApolloElasticsearchSink.IndexName(const ATimestamp: TDateTime): string;
var
  LYear, LMonth, LDay, LHour, LMin, LSec, LMs: Word;
begin
  DecodeDateTime(ATimestamp, LYear, LMonth, LDay, LHour, LMin, LSec, LMs);
  Result := Format('logs-%.4d.%.2d.%.2d', [LYear, LMonth, LDay]);
end;

function TApolloElasticsearchSink.BuildBulkBody(
  const AEntries: TArray<TApolloLogEntry>): string;
var
  LBuilder: TStringBuilder;
  LEntry: TApolloLogEntry;
  LAction: string;
begin
  LBuilder := TStringBuilder.Create;
  try
    for LEntry in AEntries do
    begin
      LAction := '{"index":{"_index":"' + IndexName(LEntry.Timestamp) + '"}}';
      LBuilder.AppendLine(LAction);
      LBuilder.AppendLine(EntryToJSON(LEntry));
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

procedure TApolloElasticsearchSink.SendBulk(const ABody: string);
var
  LHttp: THTTPClient;
  LBodyStream: TStringStream;
  LURL: string;
begin
  LHttp := THTTPClient.Create;
  try
    LURL := FBaseURL + '/_bulk';
    LHttp.CustomHeaders['Content-Type'] := 'application/x-ndjson';
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

procedure TApolloElasticsearchSink.Write(const AEntries: TArray<TApolloLogEntry>);
var
  LBody: string;
begin
  if Length(AEntries) = 0 then
    Exit;
  LBody := BuildBulkBody(AEntries);
  try
    SendBulk(LBody);
  except
    // Swallow exceptions to avoid disrupting application flow
  end;
end;

end.

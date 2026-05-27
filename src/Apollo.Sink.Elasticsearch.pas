unit Apollo.Sink.Elasticsearch;

interface

uses
  System.SysUtils,
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  IApolloElasticsearchSink = interface(IApolloSink)
    ['{A2B3C4D5-E6F7-8901-2345-678901BCDEF0}']
    function BasicAuth(const AUser, APassword: string): IApolloElasticsearchSink;
    function ApiKey(const AKey: string): IApolloElasticsearchSink;
  end;

  TApolloElasticsearchSink = class(TInterfacedObject, IApolloSink,
    IApolloElasticsearchSink)
  private
    FBaseURL: string;
    FIndexPrefix: string;
    FMinLevel: TApolloLogLevel;
    FAuthHeader: string;
    procedure SendBulk(const ABody: string);
    function BuildBulkBody(const AEntries: TArray<TApolloLogEntry>): string;
    function IndexName(const ATimestamp: TDateTime): string;
  public
    class function New(const ABaseURL: string;
      const AIndexPrefix: string = 'logs';
      const AMinLevel: TApolloLogLevel = llInfo): IApolloElasticsearchSink;
    constructor Create(const ABaseURL: string; const AIndexPrefix: string;
      const AMinLevel: TApolloLogLevel);
    function BasicAuth(const AUser, APassword: string): IApolloElasticsearchSink;
    function ApiKey(const AKey: string): IApolloElasticsearchSink;
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
  const AIndexPrefix: string; const AMinLevel: TApolloLogLevel): IApolloElasticsearchSink;
begin
  Result := TApolloElasticsearchSink.Create(ABaseURL, AIndexPrefix, AMinLevel);
end;

constructor TApolloElasticsearchSink.Create(const ABaseURL: string;
  const AIndexPrefix: string; const AMinLevel: TApolloLogLevel);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  FIndexPrefix := AIndexPrefix;
  FMinLevel := AMinLevel;
  FAuthHeader := '';
end;

function TApolloElasticsearchSink.MinLevel: TApolloLogLevel;
begin
  Result := FMinLevel;
end;

function TApolloElasticsearchSink.BasicAuth(const AUser,
  APassword: string): IApolloElasticsearchSink;
var
  LEncoded: string;
begin
  LEncoded := TNetEncoding.Base64.Encode(AUser + ':' + APassword);
  FAuthHeader := 'Basic ' + LEncoded;
  Result := Self;
end;

function TApolloElasticsearchSink.ApiKey(
  const AKey: string): IApolloElasticsearchSink;
begin
  FAuthHeader := 'ApiKey ' + AKey;
  Result := Self;
end;

function TApolloElasticsearchSink.IndexName(const ATimestamp: TDateTime): string;
var
  LYear, LMonth, LDay, LHour, LMin, LSec, LMs: Word;
begin
  DecodeDateTime(ATimestamp, LYear, LMonth, LDay, LHour, LMin, LSec, LMs);
  Result := Format('%s-%.4d.%.2d.%.2d', [FIndexPrefix, LYear, LMonth, LDay]);
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

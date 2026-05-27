unit Apollo.Sink.Loki;

interface

uses
  System.SysUtils,
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  TApolloLokiSink = class(TInterfacedObject, IApolloSink)
  private
    FBaseURL: string;
    FUser: string;
    FPassword: string;
    FMinLevel: TApolloLogLevel;
    function BuildPushBody(const AEntries: TArray<TApolloLogEntry>): string;
    function DateTimeToUnixNano(const ADateTime: TDateTime): Int64;
    function FormatFields(const AEntry: TApolloLogEntry): string;
    procedure SendBatch(const ABody: string);
  public
    class function New(const ABaseURL: string; const AUser: string = '';
      const APassword: string = '';
      const AMinLevel: TApolloLogLevel = llInfo): IApolloSink;
    constructor Create(const ABaseURL: string; const AUser: string;
      const APassword: string; const AMinLevel: TApolloLogLevel);
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;

implementation

uses
  System.Classes,
  System.DateUtils,
  System.NetEncoding,
  System.Generics.Collections,
  System.Net.HttpClient;

{ TApolloLokiSink }

class function TApolloLokiSink.New(const ABaseURL: string;
  const AUser: string; const APassword: string;
  const AMinLevel: TApolloLogLevel): IApolloSink;
begin
  Result := TApolloLokiSink.Create(ABaseURL, AUser, APassword, AMinLevel);
end;

constructor TApolloLokiSink.Create(const ABaseURL: string;
  const AUser: string; const APassword: string;
  const AMinLevel: TApolloLogLevel);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  FUser := AUser;
  FPassword := APassword;
  FMinLevel := AMinLevel;
end;

function TApolloLokiSink.MinLevel: TApolloLogLevel;
begin
  Result := FMinLevel;
end;

function TApolloLokiSink.DateTimeToUnixNano(const ADateTime: TDateTime): Int64;
begin
  Result := DateTimeToUnix(ADateTime, False) * Int64(1000000000);
end;

function TApolloLokiSink.FormatFields(const AEntry: TApolloLogEntry): string;
var
  LPair: TPair<string, TApolloFieldValue>;
  LResult: string;
begin
  LResult := AEntry.Message;
  for LPair in AEntry.Fields do
  begin
    case LPair.Value.Kind of
      fkInt64:   LResult := LResult + ' ' + LPair.Key + '=' + IntToStr(LPair.Value.AsInt64);
      fkDouble:  LResult := LResult + ' ' + LPair.Key + '=' + FloatToStr(LPair.Value.AsDouble);
      fkBoolean: LResult := LResult + ' ' + LPair.Key + '=' + BoolToStr(LPair.Value.AsBoolean, True);
    else
      LResult := LResult + ' ' + LPair.Key + '=' + LPair.Value.AsString;
    end;
  end;
  Result := LResult;
end;

function TApolloLokiSink.BuildPushBody(
  const AEntries: TArray<TApolloLogEntry>): string;
var
  LStreams: TDictionary<string, TStringBuilder>;
  LLabels: TDictionary<string, string>;
  LEntry: TApolloLogEntry;
  LKey: string;
  LLabel: string;
  LBuilder: TStringBuilder;
  LResult: TStringBuilder;
  LFirst: Boolean;
  LPair: TPair<string, TStringBuilder>;
  LNs: Int64;
begin
  LStreams := TDictionary<string, TStringBuilder>.Create;
  LLabels := TDictionary<string, string>.Create;
  try
    for LEntry in AEntries do
    begin
      LKey := LevelToString(LEntry.Level) + '|' + LEntry.Logger;
      if not LStreams.ContainsKey(LKey) then
      begin
        LStreams.Add(LKey, TStringBuilder.Create);
        LLabel := '{"level":"' + LevelToString(LEntry.Level) + '","logger":"' +
          LEntry.Logger + '"}';
        LLabels.Add(LKey, LLabel);
      end;

      LBuilder := LStreams[LKey];
      LNs := DateTimeToUnixNano(LEntry.Timestamp);
      if LBuilder.Length > 0 then
        LBuilder.Append(',');
      LBuilder.Append('["');
      LBuilder.Append(IntToStr(LNs));
      LBuilder.Append('","');
      LBuilder.Append(StringReplace(FormatFields(LEntry), '"', '\"', [rfReplaceAll]));
      LBuilder.Append('"]');
    end;

    LResult := TStringBuilder.Create;
    try
      LResult.Append('{"streams":[');
      LFirst := True;
      for LPair in LStreams do
      begin
        if not LFirst then
          LResult.Append(',');
        LFirst := False;
        LResult.Append('{"stream":');
        LResult.Append(LLabels[LPair.Key]);
        LResult.Append(',"values":[');
        LResult.Append(LPair.Value.ToString);
        LResult.Append(']}');
      end;
      LResult.Append(']}');
      Result := LResult.ToString;
    finally
      LResult.Free;
    end;
  finally
    for LPair in LStreams do
      LPair.Value.Free;
    LStreams.Free;
    LLabels.Free;
  end;
end;

procedure TApolloLokiSink.SendBatch(const ABody: string);
var
  LHttp: THTTPClient;
  LBodyStream: TStringStream;
  LURL: string;
  LEncoded: string;
begin
  LHttp := THTTPClient.Create;
  try
    LURL := FBaseURL + '/loki/api/v1/push';
    LHttp.CustomHeaders['Content-Type'] := 'application/json';
    if FUser <> '' then
    begin
      LEncoded := TNetEncoding.Base64.Encode(FUser + ':' + FPassword);
      LHttp.CustomHeaders['Authorization'] := 'Basic ' + LEncoded;
    end;

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

procedure TApolloLokiSink.Write(const AEntries: TArray<TApolloLogEntry>);
var
  LBody: string;
begin
  if Length(AEntries) = 0 then
    Exit;
  LBody := BuildPushBody(AEntries);
  try
    SendBatch(LBody);
  except
    // Swallow exceptions to avoid disrupting application flow
  end;
end;

end.

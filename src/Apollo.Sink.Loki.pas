unit Apollo.Sink.Loki;

interface

uses
  System.SysUtils,
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  IApolloLokiSink = interface(IApolloSink)
    ['{F1E2D3C4-B5A6-7890-1234-567890ABCDEF}']
    function WithLabel(const AKey, AValue: string): IApolloLokiSink;
    function BasicAuth(const AUser, APassword: string): IApolloLokiSink;
  end;

  TApolloLokiSink = class(TInterfacedObject, IApolloSink, IApolloLokiSink)
  private
    FBaseURL: string;
    FUser: string;
    FPassword: string;
    FMinLevel: TApolloLogLevel;
    FCustomLabels: TArray<TPair<string, string>>;
    function BuildStreamLabel(const ALevel: TApolloLogLevel;
      const ALogger: string): string;
    function BuildPushBody(const AEntries: TArray<TApolloLogEntry>): string;
    function DateTimeToUnixNano(const ADateTime: TDateTime): Int64;
    function FormatFields(const AEntry: TApolloLogEntry): string;
    procedure SendBatch(const ABody: string);
  public
    class function New(const ABaseURL: string;
      const AMinLevel: TApolloLogLevel = llInfo): IApolloLokiSink;
    constructor Create(const ABaseURL: string; const AMinLevel: TApolloLogLevel);
    function WithLabel(const AKey, AValue: string): IApolloLokiSink;
    function BasicAuth(const AUser, APassword: string): IApolloLokiSink;
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
  const AMinLevel: TApolloLogLevel): IApolloLokiSink;
begin
  Result := TApolloLokiSink.Create(ABaseURL, AMinLevel);
end;

constructor TApolloLokiSink.Create(const ABaseURL: string;
  const AMinLevel: TApolloLogLevel);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  FUser := '';
  FPassword := '';
  FMinLevel := AMinLevel;
  FCustomLabels := [];
end;

function TApolloLokiSink.MinLevel: TApolloLogLevel;
begin
  Result := FMinLevel;
end;

function TApolloLokiSink.WithLabel(const AKey, AValue: string): IApolloLokiSink;
var
  LIdx: Integer;
begin
  LIdx := Length(FCustomLabels);
  SetLength(FCustomLabels, LIdx + 1);
  FCustomLabels[LIdx] := TPair<string, string>.Create(AKey, AValue);
  Result := Self;
end;

function TApolloLokiSink.BasicAuth(const AUser, APassword: string): IApolloLokiSink;
begin
  FUser := AUser;
  FPassword := APassword;
  Result := Self;
end;

function TApolloLokiSink.DateTimeToUnixNano(const ADateTime: TDateTime): Int64;
begin
  Result := DateTimeToUnix(ADateTime, False) * Int64(1000000000);
end;

function TApolloLokiSink.FormatFields(const AEntry: TApolloLogEntry): string;
var
  LPair: TPair<string, TApolloFieldValue>;
  LResult: string;
  LFmt: TFormatSettings;
begin
  LFmt := TFormatSettings.Invariant;
  LResult := AEntry.Message;
  for LPair in AEntry.Fields do
  begin
    case LPair.Value.Kind of
      fkInt64:   LResult := LResult + ' ' + LPair.Key + '=' + IntToStr(LPair.Value.AsInt64);
      fkDouble:  LResult := LResult + ' ' + LPair.Key + '=' + FloatToStr(LPair.Value.AsDouble, LFmt);
      fkBoolean: LResult := LResult + ' ' + LPair.Key + '=' + BoolToStr(LPair.Value.AsBoolean, True);
    else
      LResult := LResult + ' ' + LPair.Key + '=' + LPair.Value.AsString;
    end;
  end;
  Result := LResult;
end;

function TApolloLokiSink.BuildStreamLabel(const ALevel: TApolloLogLevel;
  const ALogger: string): string;
var
  LBuilder: TStringBuilder;
  LPair: TPair<string, string>;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.Append('{"level":"');
    LBuilder.Append(LevelToString(ALevel));
    LBuilder.Append('"');
    if ALogger <> '' then
    begin
      LBuilder.Append(',"logger":"');
      LBuilder.Append(ALogger);
      LBuilder.Append('"');
    end;
    for LPair in FCustomLabels do
    begin
      LBuilder.Append(',"');
      LBuilder.Append(StringReplace(LPair.Key, '"', '\"', [rfReplaceAll]));
      LBuilder.Append('":"');
      LBuilder.Append(StringReplace(LPair.Value, '"', '\"', [rfReplaceAll]));
      LBuilder.Append('"');
    end;
    LBuilder.Append('}');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function TApolloLokiSink.BuildPushBody(
  const AEntries: TArray<TApolloLogEntry>): string;
var
  LStreams: TDictionary<string, TStringBuilder>;
  LLabels: TDictionary<string, string>;
  LEntry: TApolloLogEntry;
  LKey: string;
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
        LLabels.Add(LKey, BuildStreamLabel(LEntry.Level, LEntry.Logger));
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
    on E: Exception do
      WriteLn(ErrOutput, '[Apollo][LokiSink] ' + E.ClassName + ': ' + E.Message);
  end;
end;

end.

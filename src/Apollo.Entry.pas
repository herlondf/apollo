unit Apollo.Entry;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.JSON,
  System.Generics.Collections;

type
  TApolloLogLevel = (llTrace, llDebug, llInfo, llWarn, llError, llFatal);

  TApolloLogEntry = record
    Timestamp: TDateTime;
    Level: TApolloLogLevel;
    Message: string;
    Fields: TArray<TPair<string, string>>;
    TraceId: string;
    SpanId: string;
    Logger: string;
  end;

function LevelToString(ALevel: TApolloLogLevel): string;
function EntryToJSON(const AEntry: TApolloLogEntry): string;

implementation

function LevelToString(ALevel: TApolloLogLevel): string;
begin
  case ALevel of
    llTrace: Result := 'TRACE';
    llDebug: Result := 'DEBUG';
    llInfo:  Result := 'INFO';
    llWarn:  Result := 'WARN';
    llError: Result := 'ERROR';
    llFatal: Result := 'FATAL';
  else
    Result := 'UNKNOWN';
  end;
end;

function EntryToJSON(const AEntry: TApolloLogEntry): string;
var
  LRoot: TJSONObject;
  LFields: TJSONObject;
  LPair: TPair<string, string>;
  LYear, LMonth, LDay, LHour, LMin, LSec, LMs: Word;
begin
  LRoot := TJSONObject.Create;
  try
    DecodeDateTime(AEntry.Timestamp, LYear, LMonth, LDay, LHour, LMin, LSec, LMs);
    LRoot.AddPair('@timestamp', Format('%.4d-%.2d-%.2dT%.2d:%.2d:%.2d.%.3dZ',
      [LYear, LMonth, LDay, LHour, LMin, LSec, LMs]));
    LRoot.AddPair('level', LevelToString(AEntry.Level));
    LRoot.AddPair('message', AEntry.Message);
    LRoot.AddPair('logger', AEntry.Logger);
    LRoot.AddPair('traceId', AEntry.TraceId);
    LRoot.AddPair('spanId', AEntry.SpanId);

    LFields := TJSONObject.Create;
    for LPair in AEntry.Fields do
      LFields.AddPair(LPair.Key, LPair.Value);
    LRoot.AddPair('fields', LFields);

    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

end.

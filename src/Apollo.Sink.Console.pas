unit Apollo.Sink.Console;

interface

uses
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  TApolloConsoleSink = class(TInterfacedObject, IApolloSink)
  private
    FMinLevel: TApolloLogLevel;
    function LevelColor(const ALevel: TApolloLogLevel): string;
    function FormatEntry(const AEntry: TApolloLogEntry): string;
  public
    class function New(const AMinLevel: TApolloLogLevel = llDebug): IApolloSink;
    constructor Create(const AMinLevel: TApolloLogLevel = llDebug);
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;

implementation

uses
  System.SysUtils;

const
  ANSI_RESET   = #27'[0m';
  ANSI_GRAY    = #27'[90m';
  ANSI_CYAN    = #27'[36m';
  ANSI_GREEN   = #27'[32m';
  ANSI_YELLOW  = #27'[33m';
  ANSI_RED     = #27'[31m';
  ANSI_MAGENTA = #27'[35m';

{ TApolloConsoleSink }

class function TApolloConsoleSink.New(const AMinLevel: TApolloLogLevel): IApolloSink;
begin
  Result := TApolloConsoleSink.Create(AMinLevel);
end;

constructor TApolloConsoleSink.Create(const AMinLevel: TApolloLogLevel);
begin
  inherited Create;
  FMinLevel := AMinLevel;
end;

function TApolloConsoleSink.MinLevel: TApolloLogLevel;
begin
  Result := FMinLevel;
end;

function TApolloConsoleSink.LevelColor(const ALevel: TApolloLogLevel): string;
begin
  case ALevel of
    llTrace: Result := ANSI_GRAY;
    llDebug: Result := ANSI_CYAN;
    llInfo:  Result := ANSI_GREEN;
    llWarn:  Result := ANSI_YELLOW;
    llError: Result := ANSI_RED;
    llFatal: Result := ANSI_MAGENTA;
  else
    Result := ANSI_RESET;
  end;
end;

function TApolloConsoleSink.FormatEntry(const AEntry: TApolloLogEntry): string;
var
  LColor: string;
  LFields: string;
  LPair: TPair<string, TApolloFieldValue>;
  LYear, LMonth, LDay, LHour, LMin, LSec, LMs: Word;
  LTimestamp: string;
  LLevelStr: string;
  LFmt: TFormatSettings;
begin
  LFmt := TFormatSettings.Invariant;
  DecodeDateTime(AEntry.Timestamp, LYear, LMonth, LDay, LHour, LMin, LSec, LMs);
  LTimestamp := Format('%.4d-%.2d-%.2d %.2d:%.2d:%.2d',
    [LYear, LMonth, LDay, LHour, LMin, LSec]);

  LLevelStr := Format('%-5s', [LevelToString(AEntry.Level)]);
  LColor := LevelColor(AEntry.Level);

  LFields := '';
  for LPair in AEntry.Fields do
  begin
    case LPair.Value.Kind of
      fkInt64:   LFields := LFields + '  ' + LPair.Key + '=' + IntToStr(LPair.Value.AsInt64);
      fkDouble:  LFields := LFields + '  ' + LPair.Key + '=' + FloatToStr(LPair.Value.AsDouble, LFmt);
      fkBoolean: LFields := LFields + '  ' + LPair.Key + '=' + BoolToStr(LPair.Value.AsBoolean, True);
    else
      LFields := LFields + '  ' + LPair.Key + '=' + LPair.Value.AsString;
    end;
  end;

  Result := LColor + '[' + LTimestamp + '] ' + LLevelStr + '  ' +
            AEntry.Message + LFields + ANSI_RESET;
end;

procedure TApolloConsoleSink.Write(const AEntries: TArray<TApolloLogEntry>);
var
  LEntry: TApolloLogEntry;
begin
  TMonitor.Enter(Self);
  try
    for LEntry in AEntries do
      WriteLn(FormatEntry(LEntry));
  finally
    TMonitor.Exit(Self);
  end;
end;

end.

unit Apollo.Sink.File;

interface

uses
  System.SysUtils,
  System.Classes,
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  TApolloFileSink = class(TInterfacedObject, IApolloSink)
  private
    FFilePath: string;
    FMinLevel: TApolloLogLevel;
    FMaxSizeBytes: Int64;
    FMaxBackups: Integer;
    FWriter: TStreamWriter;
    FLock: TObject;
    procedure OpenWriter;
    procedure CloseWriter;
    procedure RotateIfNeeded;
  public
    class function New(const AFilePath: string;
      const AMinLevel: TApolloLogLevel = llInfo;
      const AMaxSizeMB: Integer = 100;
      const AMaxBackups: Integer = 5): IApolloSink;
    constructor Create(const AFilePath: string;
      const AMinLevel: TApolloLogLevel = llInfo;
      const AMaxSizeMB: Integer = 100;
      const AMaxBackups: Integer = 5);
    destructor Destroy; override;
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;

implementation

{ TApolloFileSink }

class function TApolloFileSink.New(const AFilePath: string;
  const AMinLevel: TApolloLogLevel; const AMaxSizeMB: Integer;
  const AMaxBackups: Integer): IApolloSink;
begin
  Result := TApolloFileSink.Create(AFilePath, AMinLevel, AMaxSizeMB, AMaxBackups);
end;

constructor TApolloFileSink.Create(const AFilePath: string;
  const AMinLevel: TApolloLogLevel; const AMaxSizeMB: Integer;
  const AMaxBackups: Integer);
begin
  inherited Create;
  FFilePath := AFilePath;
  FMinLevel := AMinLevel;
  FMaxSizeBytes := Int64(AMaxSizeMB) * 1024 * 1024;
  FMaxBackups := AMaxBackups;
  FWriter := nil;
  FLock := TObject.Create;
  OpenWriter;
end;

destructor TApolloFileSink.Destroy;
begin
  CloseWriter;
  FLock.Free;
  inherited;
end;

function TApolloFileSink.MinLevel: TApolloLogLevel;
begin
  Result := FMinLevel;
end;

procedure TApolloFileSink.OpenWriter;
var
  LStream: TFileStream;
  LMode: Word;
begin
  if FileExists(FFilePath) then
    LMode := fmOpenWrite or fmShareDenyWrite
  else
    LMode := fmCreate or fmShareDenyWrite;

  LStream := TFileStream.Create(FFilePath, LMode);
  LStream.Seek(0, soEnd);
  FWriter := TStreamWriter.Create(LStream, TEncoding.UTF8, 4096);
  FWriter.AutoFlush := True;
  FWriter.OwnStream := True;
end;

procedure TApolloFileSink.CloseWriter;
begin
  if Assigned(FWriter) then
  begin
    FWriter.Flush;
    FWriter.Free;
    FWriter := nil;
  end;
end;

procedure TApolloFileSink.RotateIfNeeded;
var
  LStream: TStream;
  LSize: Int64;
  LIdx: Integer;
  LFrom, LTo: string;
begin
  if not Assigned(FWriter) then
    Exit;

  LStream := FWriter.BaseStream;
  if not Assigned(LStream) then
    Exit;

  LSize := LStream.Size;
  if LSize < FMaxSizeBytes then
    Exit;

  CloseWriter;

  // Shift existing backups up: .N deleted, .N-1 → .N, ..., .1 → .2
  for LIdx := FMaxBackups downto 2 do
  begin
    LTo   := FFilePath + '.' + IntToStr(LIdx);
    LFrom := FFilePath + '.' + IntToStr(LIdx - 1);
    if FileExists(LTo) then
      DeleteFile(LTo);
    if FileExists(LFrom) then
      RenameFile(LFrom, LTo);
  end;

  // Current file → .1
  LTo := FFilePath + '.1';
  if FileExists(LTo) then
    DeleteFile(LTo);
  RenameFile(FFilePath, LTo);

  OpenWriter;
end;

procedure TApolloFileSink.Write(const AEntries: TArray<TApolloLogEntry>);
var
  LEntry: TApolloLogEntry;
begin
  TMonitor.Enter(FLock);
  try
    RotateIfNeeded;
    for LEntry in AEntries do
      FWriter.WriteLine(EntryToJSON(LEntry));
    FWriter.Flush;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.

unit Apollo.Sink.File;

interface

uses
  System.SysUtils,
  System.Classes,
  Apollo.Entry,
  Apollo.Sink.Interfaces;

type
  TApolloFileSink = class(TInterfacedObject, IApollSink)
  private
    FFilePath: string;
    FMinLevel: TApolloLogLevel;
    FMaxSizeBytes: Int64;
    FWriter: TStreamWriter;
    FLock: TObject;
    procedure OpenWriter;
    procedure CloseWriter;
    procedure RotateIfNeeded;
  public
    class function New(const AFilePath: string;
      const AMinLevel: TApolloLogLevel = llInfo;
      const AMaxSizeMB: Integer = 100): IApollSink;
    constructor Create(const AFilePath: string;
      const AMinLevel: TApolloLogLevel = llInfo;
      const AMaxSizeMB: Integer = 100);
    destructor Destroy; override;
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;

implementation

{ TApolloFileSink }

class function TApolloFileSink.New(const AFilePath: string;
  const AMinLevel: TApolloLogLevel; const AMaxSizeMB: Integer): IApollSink;
begin
  Result := TApolloFileSink.Create(AFilePath, AMinLevel, AMaxSizeMB);
end;

constructor TApolloFileSink.Create(const AFilePath: string;
  const AMinLevel: TApolloLogLevel; const AMaxSizeMB: Integer);
begin
  inherited Create;
  FFilePath := AFilePath;
  FMinLevel := AMinLevel;
  FMaxSizeBytes := Int64(AMaxSizeMB) * 1024 * 1024;
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
  LRotated: string;
  LStream: TStream;
  LSize: Int64;
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
  LRotated := FFilePath + '.1';
  if FileExists(LRotated) then
    DeleteFile(LRotated);
  RenameFile(FFilePath, LRotated);
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

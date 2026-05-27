unit Apollo.Sink.Interfaces;

interface

uses
  Apollo.Entry;

type
  IApolloSink = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    procedure Write(const AEntries: TArray<TApolloLogEntry>);
    function MinLevel: TApolloLogLevel;
  end;

implementation

end.

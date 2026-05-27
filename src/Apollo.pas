unit Apollo;

interface

uses
  Apollo.Entry,
  Apollo.Sink.Interfaces,
  Apollo.Dispatcher,
  Apollo.Logger,
  Apollo.Sink.Console,
  Apollo.Sink.File;

var
  GApollo: IApolloLogger;

procedure ApolloSetup(const ADispatcher: TApolloDispatcher);

implementation

procedure ApolloSetup(const ADispatcher: TApolloDispatcher);
begin
  GApollo := TApolloLogger.New(ADispatcher);
end;

end.

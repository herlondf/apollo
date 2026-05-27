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

// Procedures de conveniencia — delegam para GApollo.
// Requerem ApolloSetup antes de usar; ignoradas silenciosamente se GApollo nao estiver configurado.
function ApolloTrace(const AMessage: string): IApolloLogBuilder;
function ApolloDebug(const AMessage: string): IApolloLogBuilder;
function ApolloInfo (const AMessage: string): IApolloLogBuilder;
function ApolloWarn (const AMessage: string): IApolloLogBuilder;
function ApolloError(const AMessage: string): IApolloLogBuilder; overload;
function ApolloError(const AMessage: string; const AException: Exception): IApolloLogBuilder; overload;
function ApolloFatal(const AMessage: string): IApolloLogBuilder;

implementation

procedure ApolloSetup(const ADispatcher: TApolloDispatcher);
begin
  GApollo := TApolloLogger.New(ADispatcher);
end;

function ApolloTrace(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Trace(AMessage)
  else Result := nil;
end;

function ApolloDebug(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Debug(AMessage)
  else Result := nil;
end;

function ApolloInfo(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Info(AMessage)
  else Result := nil;
end;

function ApolloWarn(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Warn(AMessage)
  else Result := nil;
end;

function ApolloError(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Error(AMessage)
  else Result := nil;
end;

function ApolloError(const AMessage: string; const AException: Exception): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Error(AMessage, AException)
  else Result := nil;
end;

function ApolloFatal(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Fatal(AMessage)
  else Result := nil;
end;

end.

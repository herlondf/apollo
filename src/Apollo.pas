unit Apollo;

interface

uses
  Apollo.Entry,
  Apollo.Dispatcher,
  Apollo.Logger;

var
  GApollo: IApolloLogger;

procedure ApolloSetup(const ADispatcher: TApolloDispatcher);

// Procedures de conveniencia — delegam para GApollo.
// Requerem ApolloSetup antes de usar.
// Se GApollo nao estiver configurado, retornam um builder no-op (Emit e ignorado, sem crash).
function ApolloTrace(const AMessage: string): IApolloLogBuilder;
function ApolloDebug(const AMessage: string): IApolloLogBuilder;
function ApolloInfo (const AMessage: string): IApolloLogBuilder;
function ApolloWarn (const AMessage: string): IApolloLogBuilder;
function ApolloError(const AMessage: string): IApolloLogBuilder; overload;
function ApolloError(const AMessage: string; const AException: Exception): IApolloLogBuilder; overload;
function ApolloFatal(const AMessage: string): IApolloLogBuilder;

implementation

uses
  System.SysUtils;

procedure ApolloSetup(const ADispatcher: TApolloDispatcher);
begin
  GApollo := TApolloLogger.New(ADispatcher);
end;

function ApolloTrace(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Trace(AMessage)
  else Result := TApolloLogBuilder.Noop;
end;

function ApolloDebug(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Debug(AMessage)
  else Result := TApolloLogBuilder.Noop;
end;

function ApolloInfo(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Info(AMessage)
  else Result := TApolloLogBuilder.Noop;
end;

function ApolloWarn(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Warn(AMessage)
  else Result := TApolloLogBuilder.Noop;
end;

function ApolloError(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Error(AMessage)
  else Result := TApolloLogBuilder.Noop;
end;

function ApolloError(const AMessage: string; const AException: Exception): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Error(AMessage, AException)
  else Result := TApolloLogBuilder.Noop;
end;

function ApolloFatal(const AMessage: string): IApolloLogBuilder;
begin
  if Assigned(GApollo) then Result := GApollo.Fatal(AMessage)
  else Result := TApolloLogBuilder.Noop;
end;

end.

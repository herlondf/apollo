program ApolloConsoleBasic;

// Demonstra o uso basico do Apollo: dispatcher, dois sinks, todos os niveis,
// campos tipados (string, int, double, bool), TraceId/SpanId e exception estruturada.
//
// Requisito: adicione <apollo>/src ao search path do projeto (ver .dproj).
//
// Saida esperada no console (com cores ANSI):
//   [2024-01-01 12:00:00] TRACE  app iniciando  env=production
//   [2024-01-01 12:00:00] DEBUG  detalhes internos  conexoes=10  ...
//   [2024-01-01 12:00:00] INFO   requisicao processada  method=GET  ...
//   [2024-01-01 12:00:00] WARN   memoria alta  mb=512  threshold=90  critical=False
//   [2024-01-01 12:00:00] ERROR  job falhou  error.type=Exception  error.message=...
//   [2024-01-01 12:00:00] FATAL  falha irrecuperavel  componente=database

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Apollo        in '..\..\src\Apollo.pas',
  Apollo.Entry  in '..\..\src\Apollo.Entry.pas',
  Apollo.Logger in '..\..\src\Apollo.Logger.pas',
  Apollo.Dispatcher     in '..\..\src\Apollo.Dispatcher.pas',
  Apollo.Sink.Interfaces in '..\..\src\Apollo.Sink.Interfaces.pas',
  Apollo.Sink.Console   in '..\..\src\Apollo.Sink.Console.pas',
  Apollo.Sink.File      in '..\..\src\Apollo.Sink.File.pas';

var
  LDispatcher: TApolloDispatcher;

begin
  LDispatcher := TApolloDispatcher.New;
  try
    // Console exibe tudo a partir de Trace
    LDispatcher.AddSink(TApolloConsoleSink.New(llTrace));

    // Arquivo grava somente Info e acima em NDJSON com rotacao a cada 10 MB
    LDispatcher.AddSink(TApolloFileSink.New('apollo-sample.log', llInfo, 10));

    ApolloSetup(LDispatcher);
    LDispatcher.Start;

    // --- Todos os niveis ---
    ApolloTrace('app iniciando').Field('env', 'production').Emit;

    ApolloDebug('detalhes internos')
      .Field('conexoes', 10)
      .Field('buffer_kb', 64.5)
      .Emit;

    ApolloInfo('requisicao processada')
      .Field('method', 'GET')
      .Field('path', '/users')
      .Field('status', 200)
      .Field('ms', 14)
      .TraceId('abc123def456')
      .SpanId('7890abcd')
      .Emit;

    ApolloWarn('memoria alta')
      .Field('mb', 512)
      .Field('threshold', 90)
      .Field('critical', False)
      .Emit;

    // Exception como campos estruturados (error.type + error.message)
    try
      raise Exception.Create('timeout ao conectar ao banco');
    except
      on E: Exception do
        ApolloError('job falhou', E)
          .Field('job_id', 'order-processor-42')
          .Emit;
    end;

    ApolloFatal('falha irrecuperavel')
      .Field('componente', 'database')
      .Emit;

    WriteLn;
    WriteLn('Pressione Enter para encerrar.');
    ReadLn;

    LDispatcher.Stop;
  finally
    LDispatcher.Free;
  end;
end.

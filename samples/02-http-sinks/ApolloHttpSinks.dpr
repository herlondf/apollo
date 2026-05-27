program ApolloHttpSinks;

// Demonstra o uso dos 5 sinks HTTP do Apollo:
//   Seq    — CLEF format, autenticacao via X-Seq-ApiKey
//   Loki   — push API, labels customizados, Basic Auth
//   Elasticsearch — Bulk API, rotacao de indice por dia, API key
//   Datadog — Logs API v2, ddtags, site configuravel
//   OTLP   — OpenTelemetry /v1/logs, Bearer token, resource attributes
//
// Requisito: adicione <apollo>/src ao search path do projeto (ver .dproj).
//
// Nenhuma conexao real e feita ao executar sem infraestrutura disponivel.
// Os erros de rede sao silenciados no stderr e a aplicacao continua.

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Apollo              in '..\..\src\Apollo.pas',
  Apollo.Entry        in '..\..\src\Apollo.Entry.pas',
  Apollo.Logger       in '..\..\src\Apollo.Logger.pas',
  Apollo.Dispatcher   in '..\..\src\Apollo.Dispatcher.pas',
  Apollo.Sink.Interfaces    in '..\..\src\Apollo.Sink.Interfaces.pas',
  Apollo.Sink.Seq           in '..\..\src\Apollo.Sink.Seq.pas',
  Apollo.Sink.Loki          in '..\..\src\Apollo.Sink.Loki.pas',
  Apollo.Sink.Elasticsearch in '..\..\src\Apollo.Sink.Elasticsearch.pas',
  Apollo.Sink.Datadog       in '..\..\src\Apollo.Sink.Datadog.pas',
  Apollo.Sink.OTLP          in '..\..\src\Apollo.Sink.OTLP.pas';

var
  LDispatcher: TApolloDispatcher;
begin
  LDispatcher := TApolloDispatcher.New;
  try
    // --- Seq (CLEF) ---
    LDispatcher.AddSink(
      TApolloSeqSink.New('http://seq:5341', 'my-seq-api-key', llInfo)
    );

    // --- Loki (push API) ---
    LDispatcher.AddSink(
      TApolloLokiSink.New('http://loki:3100', llInfo)
        .WithLabel('app', 'apollo-sample')
        .WithLabel('env', 'development')
        .BasicAuth('admin', 'secret')
    );

    // --- Elasticsearch (Bulk API) ---
    LDispatcher.AddSink(
      TApolloElasticsearchSink.New('http://es:9200', 'logs-apollo', llInfo)
        .BasicAuth('elastic', 'changeme')
    );

    // Com API key ao inves de usuario/senha:
    //   .ApiKey('bXktZW5jb2RlZC1hcGkta2V5')

    // --- Datadog ---
    LDispatcher.AddSink(
      TApolloDatadogSink.New('my-dd-api-key', llWarn)
        .Service('apollo-sample')
        .Site('datadoghq.com')
        .Tag('env:development,team:core')
    );

    // --- OTLP (OpenTelemetry) ---
    LDispatcher.AddSink(
      TApolloOTLPSink.New('http://otel-collector:4318', llInfo)
        .ResourceAttribute('service.name', 'apollo-sample')
        .ResourceAttribute('deployment.environment', 'development')
        .BearerToken('my-otel-token')
    );

    ApolloSetup(LDispatcher);
    LDispatcher.Start;

    // Emite entradas em varios niveis com campos tipados
    ApolloInfo('servidor iniciado')
      .Field('port', 9000)
      .Field('env', 'development')
      .Emit;

    ApolloInfo('requisicao processada')
      .Field('method', 'GET')
      .Field('path', '/api/users')
      .Field('status', 200)
      .Field('latency_ms', 14.7)
      .TraceId('4bf92f3577b34da6a3ce929d0e0e4736')
      .SpanId('00f067aa0ba902b7')
      .Emit;

    ApolloWarn('uso de memoria elevado')
      .Field('mb', 768)
      .Field('threshold_mb', 512)
      .Field('pct', 87.5)
      .Emit;

    try
      raise Exception.Create('falha ao conectar ao banco de dados');
    except
      on E: Exception do
        ApolloError('operacao falhou', E)
          .Field('operacao', 'user-query')
          .Field('tentativa', 3)
          .Emit;
    end;

    ApolloFatal('processo encerrando por falha critica')
      .Field('componente', 'database')
      .Emit;

    WriteLn('Entradas enviadas. Erros de conexao aparecem no stderr.');
    WriteLn('Pressione Enter para encerrar.');
    ReadLn;

    LDispatcher.Stop;
  finally
    LDispatcher.Free;
  end;
end.

program ApolloTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Runners.Console,
  Apollo.Tests        in 'Apollo.Tests.pas',
  Apollo              in '..\src\Apollo.pas',
  Apollo.Entry        in '..\src\Apollo.Entry.pas',
  Apollo.Logger       in '..\src\Apollo.Logger.pas',
  Apollo.Dispatcher   in '..\src\Apollo.Dispatcher.pas',
  Apollo.Sink.Interfaces in '..\src\Apollo.Sink.Interfaces.pas';

var
  LRunner: ITestRunner;
  LResults: IRunResults;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    LRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LResults := LRunner.Execute;
    if not LResults.AllPassed then
      ExitCode := EXIT_ERRORS;
    {$IFNDEF CI}
    WriteLn('Pressione Enter para sair.');
    ReadLn;
    {$ENDIF}
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := EXIT_ERRORS;
    end;
  end;
end.

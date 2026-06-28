program SimpleVideoPlayer;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, FormSyncedVideoPlayer;

{$R *.res}

begin
  Application.Title:='Simple Synced Video Player';
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TfrmSyncedVideoPlayer, frmSyncedVideoPlayer);
  Application.Run;
end.


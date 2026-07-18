program IM_Video;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, FormIMVideo;

{$R *.res}

begin
  Application.Title:='Inspector Mike Video Player';
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TfrmIMVideo, frmIMVideo);
  Application.Run;
end.


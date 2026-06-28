Unit FormSyncedVideoPlayer;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}

Interface

Uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  Buttons, Menus, FrameVideoPlayer, FrameSyncedVideo, FormMain, IniFiles, MRUs;

Type

  { TfrmSyncedVideoPlayer }

  TfrmSyncedVideoPlayer = Class(TFormMain)
    MenuItem1: TMenuItem;
    mnuOpenRecent: TMenuItem;
    mnuExit: TMenuItem;
    mnuFile: TMenuItem;
    mnuOpen: TMenuItem;
    dlgOpen: TOpenDialog;
    pnlVideoPlayer: TPanel;
    Procedure FormActivate(Sender: TObject);
    Procedure FormClose(Sender: TObject; Var CloseAction: TCloseAction);
    Procedure FormCreate(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
    Procedure FormDropFiles(Sender: TObject; Const FileNames: Array Of String);
    Procedure mnuExitClick(Sender: TObject);
    Procedure mnuFileClick(Sender: TObject);
    Procedure mnuOpenClick(Sender: TObject);
    Procedure mnuOpenRecentClick(Sender: TObject);
  Private
    fmeVideoPlayer: TFrameVideoPlayer;
    fmeSyncedVideo: TFrameSyncedVideo;
    FMRU: TMRU;
    FLoaded: Boolean;

    Procedure OpenVideo(Const AFiles: TStrings); Overload;
    Procedure OpenVideo(Const AFiles: TStringArray); Overload;
  Public
    // Stored in ini file with exe - what folders to load etc
    Procedure LoadGlobalSettings(oInifile: TIniFile); Override;
    Procedure SaveGlobalSettings(oInifile: TIniFile); Override;
  End;

Var
  frmSyncedVideoPlayer: TfrmSyncedVideoPlayer;

Implementation

Uses
  FileSupport, VideoEngineFactory, ControlGridLayout, StringSupport,
  InspectionSupport, DateUtils,

  // Include all required video playback engines below this point
  FrameVideoLibmpv;

  {$R *.lfm}

  { TfrmSyncedVideoPlayer }

Procedure TfrmSyncedVideoPlayer.FormCreate(Sender: TObject);
Begin
  Inherited;

  fmeVideoPlayer := TFrameVideoPlayer.Create(Self);
  fmeVideoPlayer.Parent := pnlVideoPlayer;
  fmeVideoPlayer.Name := 'fmeVideoPlayer';
  fmeVideoPlayer.Align := alClient;
  fmeVideoPlayer.Autoplay := True;
  fmeVideoPlayer.ShowLabel := True;

  // Change this line to swap playback engines.
  fmeVideoPlayer.VideoEngineClass := TFrameSyncedVideo;

  fmeSyncedVideo := nil;

  If assigned(fmeVideoPlayer.PlaybackFrame) Then
  Begin
    If fmeVideoPlayer.PlaybackFrame Is TFrameSyncedVideo Then
    Begin
      fmeSyncedVideo := TFrameSyncedVideo(fmeVideoPlayer.PlaybackFrame);
      fmeSyncedVideo.VideoEngineClass := TVideoEngineFactory.DefaultClass;
    End;
  End;

  // Disable require --configure
  FAlwaysSaveSettings := True;

  FMRU := TMRU.Create;
  FMRU.Max := 10;
  FMRU.Files := True;

  FLoaded := False;
End;

Procedure TfrmSyncedVideoPlayer.FormActivate(Sender: TObject);
Var
  slFiles: TStringList;
  i: Integer;
  sFile, sExt: String;
Begin
  Inherited;

  If Not FLoaded Then
  Begin
    If Application.ParamCount > 0 Then
    Begin
      slFiles := TStringList.Create;
      Try
        For i := 1 To Application.ParamCount - 1 Do
        Begin
          sFile := Application.Params[i];
          sExt := ExtractFileExt(LowerCase(sFile));
          If IsVideo(sExt) Then
            slFiles.Add(sFile);
        End;

        OpenVideo(slFiles);
      Finally
        slFiles.Free;
      End;
    End;

    FLoaded := True;
  End;
End;

Procedure TfrmSyncedVideoPlayer.FormClose(Sender: TObject; Var CloseAction: TCloseAction);
Begin
  If Assigned(fmeVideoPlayer) Then
    fmeVideoPlayer.Clear;

  Inherited;
End;

Procedure TfrmSyncedVideoPlayer.FormDestroy(Sender: TObject);
Begin
  FreeAndNil(FMRU);

  Inherited;
End;

Procedure TfrmSyncedVideoPlayer.FormDropFiles(Sender: TObject; Const FileNames: Array Of String);
Var
  sExt, sFile: String;
  slFiles: TStringList;
Begin
  If Length(FileNames) = 0 Then
    Exit;

  slFiles := TStringList.Create;
  Try
    For sFile In FileNames Do
    Begin
      sExt := ExtractFileExt(LowerCase(sFile));
      If IsVideo(sExt) Then
        slFiles.Add(sFile);
    End;

    OpenVideo(slFiles);
  Finally
    slFiles.Free;
  End;
End;

Procedure TfrmSyncedVideoPlayer.OpenVideo(Const AFiles: TStrings);
Var
  arrFiles: TStringArray;
Begin
  arrFiles := AFiles.ToStringArray;
  OpenVideo(arrFiles);
End;

Procedure TfrmSyncedVideoPlayer.OpenVideo(Const AFiles: TStringArray);
Var
  arrFiles: TStringArray;
  sFile, sChannel: String;
  oInspectionFilenameInfo: TInspectionFilenameInfo;
  dtStart, dtEnd: TDateTime;
Begin
  If Not Assigned(AFiles) Then
    Exit;

  If Length(AFiles) = 0 Then
  Begin
    fmeSyncedVideo.Rate := 1.0;
    fmeVideoPlayer.Clear;
  End;

  If Length(AFiles) = 1 Then
  Begin
    sFile := AFiles[0];

    If TryParseInspectionFilename(sFile, oInspectionFilenameInfo) And
      oInspectionFilenameInfo.FoundDateTime Then
    Begin
      If MessageDlg('Open related files?',
        'This filename appears to contain a start time:' + LineEnding +
        LineEnding + DateTimeToStr(oInspectionFilenameInfo.DateTime) +
        LineEnding + LineEnding +
        'Do you want to search the same folder for files in the same time window?',
        mtConfirmation, [mbYes, mbNo], 0) = mrYes Then
      Begin
        // Adjust this window to taste.  Currently +/- 5 seconds
        dtStart := IncSecond(oInspectionFilenameInfo.DateTime, -5);
        dtEnd := IncSecond(dtStart, 10);

        arrFiles := FindFilesStartingInWindow(sFile, dtStart, dtEnd);

        If Length(arrFiles) = 0 Then
        Begin
          SetLength(arrFiles, 1);
          arrFiles[0] := sFile;
        End;
      End;
    End;
  End;

  Busy := True;
  BeginFormUpdate;
  Try
    If Not Assigned(fmeSyncedVideo) Then
      If assigned(fmeVideoPlayer.PlaybackFrame) Then
      Begin
        If fmeVideoPlayer.PlaybackFrame Is TFrameSyncedVideo Then
        Begin
          fmeSyncedVideo := TFrameSyncedVideo(fmeVideoPlayer.PlaybackFrame);
          fmeSyncedVideo.VideoEngineClass := TVideoEngineFactory.DefaultClass;
        End;
      End;

    fmeSyncedVideo.BeginLoadVideos;
    Try
      For sFile In arrFiles Do
      Begin
        If FileExists(sFile) And (fmeSyncedVideo.VideoFileCount < 4) Then
        Begin
          TryParseInspectionFilename(sFile, oInspectionFilenameInfo);

          If oInspectionFilenameInfo.FoundChannel Then
            sChannel := oInspectionFilenameInfo.Channel
          Else
            sChannel := '';

          If oInspectionFilenameInfo.FoundDateTime Then
            dtStart := oInspectionFilenameInfo.DateTime
          Else
            dtStart := 0;

          fmeSyncedVideo.Load(sFile, sChannel, dtStart);
        End;
      End;

    Finally
      fmeSyncedVideo.EndLoadVideos;
    End;

    If fmeSyncedVideo.VideoFileCount > 0 Then
    Begin
      If fmeSyncedVideo.VideoFileCount > 2 Then
        fmeSyncedVideo.Layout(2, 2, clsLeftToRightThenDown)
      Else
        fmeSyncedVideo.Layout(1, fmeSyncedVideo.VideoFileCount, clsLeftToRightThenDown);

      // Play the video
      fmeSyncedVideo.Play;
      fmeVideoPlayer.RefreshUI;
    End;
  Finally
    EndFormUpdate;
    Busy := False;
  End;
End;

Procedure TfrmSyncedVideoPlayer.mnuExitClick(Sender: TObject);
Begin
  Close;
End;

Procedure TfrmSyncedVideoPlayer.mnuFileClick(Sender: TObject);
Begin
  FMRU.Populate(mnuOpenRecent, @mnuOpenRecentClick);
  mnuOpenRecent.Enabled := FMRU.Count > 0;
End;

Procedure TfrmSyncedVideoPlayer.mnuOpenClick(Sender: TObject);
Begin
  If dlgOpen.Execute Then
    OpenVideo(dlgOpen.Files);
End;

Procedure TfrmSyncedVideoPlayer.mnuOpenRecentClick(Sender: TObject);
Var
  slFiles: TStringList;
Begin
  If (Sender Is TMenuItem) And (TMenuItem(Sender).Tag < FMRU.Count) Then
  Begin
    slFiles := TStringList.Create;
    Try
      slFiles.Add(FMRU.Value(TMenuItem(Sender).Tag));
      OpenVideo(slFiles);
    Finally
      slFiles.Free;
    End;
  End;
End;

Procedure TfrmSyncedVideoPlayer.LoadGlobalSettings(oInifile: TIniFile);
Begin
  Inherited;

  FMRU.Load(oInifile, 'Files', 'MRU');
End;

Procedure TfrmSyncedVideoPlayer.SaveGlobalSettings(oInifile: TIniFile);
Begin
  Inherited;

  FMRU.Save(oInifile, 'Files', 'MRU');
End;

End.

Unit FormIMVideo;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}

Interface

Uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  Buttons, Menus, ActnList, ComCtrls, ShellCtrls, StdCtrls, EditBtn,
  FrameVideoPlayer, FrameSyncedVideo, FormMain, IniFiles, MRUs;

Type

  { TfrmIMVideo }

  TfrmIMVideo = Class(TFormMain)
    btnRefresh: TBitBtn;
    edtRoot: TDirectoryEdit;
    lvFiles: TListView;
    mnuToggleVideo: TMenuItem;
    mnuView: TMenuItem;
    pnlDrive: TPanel;
    pnlLeft: TPanel;
    Separator1: TMenuItem;
    mnuOpenRecent: TMenuItem;
    mnuExit: TMenuItem;
    mnuFile: TMenuItem;
    mnuOpen: TMenuItem;
    dlgOpen: TOpenDialog;
    pnlVideoPlayer: TPanel;
    tvFolders: TShellTreeView;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    tmrUpdate: TTimer;
    Procedure btnRefreshClick(Sender: TObject);
    Procedure edtRootChange(Sender: TObject);
    Procedure FormActivate(Sender: TObject);
    Procedure FormClose(Sender: TObject; Var CloseAction: TCloseAction);
    Procedure FormCreate(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
    Procedure FormDropFiles(Sender: TObject; Const FileNames: Array Of String);
    Procedure lvFilesSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    Procedure mnuExitClick(Sender: TObject);
    Procedure mnuFileClick(Sender: TObject);
    Procedure mnuOpenClick(Sender: TObject);
    Procedure mnuOpenRecentClick(Sender: TObject);
    Procedure mnuToggleVideoClick(Sender: TObject);
    Procedure tmrUpdateTimer(Sender: TObject);
    Procedure tvFoldersSelectionChanged(Sender: TObject);
  Private
    fmeVideoPlayer: TFrameVideoPlayer;
    fmeSyncedVideo: TFrameSyncedVideo;
    FMRU: TMRU;
    FLoaded: Boolean;
    FInternalLoad: Boolean;
    FIgnoreListViewSelectItem: Integer;
    FIgnoreTreeViewChange: Integer;
    FFolder: String;

    Procedure OpenVideo(Const AFiles: TStrings); Overload;
    Procedure OpenVideo(Const AFiles: TStringArray); Overload;
    Procedure ParseFolder(AFile: String);
  Public
    Procedure LoadLocalSettings(oInifile: TIniFile); Override;
    Procedure SaveLocalSettings(oInifile: TIniFile); Override;
  End;

Var
  frmIMVideo: TfrmIMVideo;

Implementation

Uses
  FileSupport, VideoEngineFactory, ControlGridLayout, StringSupport,
  InspectionSupport, DateUtils, ControlsSupport,

  // Include all required video playback engines below this point
  FrameVideoLibmpv;

  {$R *.lfm}

  { TfrmIMVideo }

Procedure TfrmIMVideo.FormCreate(Sender: TObject);
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
  FInternalLoad := False;
  FIgnoreListViewSelectItem := 0;
  FIgnoreTreeViewChange := 0;
  FFolder := '';

  Caption := Application.Title;

  sbMain.Panels[0].Text := '';
  sbMain.Panels[1].Text := 'Start:';
  sbMain.Panels[2].Text := 'Duration:';
  sbMain.Panels[3].Text := 'End:';

End;


Procedure TfrmIMVideo.FormActivate(Sender: TObject);
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
        For i := 1 To Application.ParamCount Do
        Begin
          sFile := Application.Params[i];
          sExt := ExtractFileExt(LowerCase(sFile));
          If IsVideo(sExt) Then
            slFiles.Add(sFile);
        End;

        If slFiles.Count > 0 Then
          OpenVideo(slFiles);
      Finally
        slFiles.Free;
      End;
    End;

    FLoaded := True;
  End;
End;

Procedure TfrmIMVideo.btnRefreshClick(Sender: TObject);
Begin
  If DirectoryExists(FFolder) Then
  Begin
    tvFolders.Refresh(tvFolders.Selected);
    //tvFolders.Path := FFolder;
  End;
End;

Procedure TfrmIMVideo.edtRootChange(Sender: TObject);
Begin
  // We may manually set contents during ParseFolder, in code where
  // FIgnoreTreeViewChange is incremented
  If FIgnoreTreeViewChange > 0 Then
    Exit;

  If DirectoryExists(edtRoot.Directory) Then
    tvFolders.Root := edtRoot.Directory;
End;

Procedure TfrmIMVideo.FormClose(Sender: TObject; Var CloseAction: TCloseAction);
Begin
  If Assigned(fmeVideoPlayer) Then
    fmeVideoPlayer.Clear;

  Inherited;
End;

Procedure TfrmIMVideo.FormDestroy(Sender: TObject);
Begin
  FreeAndNil(FMRU);

  Inherited;
End;

Const
  RELATED_VIDEO_WINDOW_SEC = 10;

Type
  TVideoFileInfo = Record
    FullName: String;
    FileName: String;
    HasDateTime: Boolean;
    DateTime: TDateTime;
  End;

Function SecondsApart(Const A, B: TDateTime): Double;
Begin
  Result := Abs(A - B) * 24 * 60 * 60;
End;

Function CompareVideoFileInfo(Const A, B: TVideoFileInfo): Integer;
Begin
  If A.HasDateTime And B.HasDateTime Then
  Begin
    If A.DateTime < B.DateTime Then Exit(-1);
    If A.DateTime > B.DateTime Then Exit(1);
    Result := CompareText(A.FileName, B.FileName);
  End
  Else If A.HasDateTime Then
    Result := -1
  Else If B.HasDateTime Then
    Result := 1
  Else
    Result := CompareText(A.FileName, B.FileName);
End;

Procedure SortVideoFiles(Var AFiles: Array Of TVideoFileInfo);

  Procedure QuickSort(L, R: Integer);
  Var
    I, J: Integer;
    Pivot, Temp: TVideoFileInfo;
  Begin
    I := L;
    J := R;
    Pivot := AFiles[(L + R) Div 2];

    Repeat
      While CompareVideoFileInfo(AFiles[I], Pivot) < 0 Do Inc(I);
      While CompareVideoFileInfo(AFiles[J], Pivot) > 0 Do Dec(J);

      If I <= J Then
      Begin
        Temp := AFiles[I];
        AFiles[I] := AFiles[J];
        AFiles[J] := Temp;
        Inc(I);
        Dec(J);
      End;
    Until I > J;

    If L < J Then QuickSort(L, J);
    If I < R Then QuickSort(I, R);
  End;

Begin
  If Length(AFiles) > 1 Then
    QuickSort(0, High(AFiles));
End;

Procedure TfrmIMVideo.ParseFolder(AFile: String);
Var
  sFolder, sExt, sSearchMask, sFullName, sDrive, sTemp: String;
  oSearchRec: TSearchRec;
  oParsedInfo: TInspectionFilenameInfo;
  Files: Array Of TVideoFileInfo;
  i, iGroupStart, iCount: Integer;
  oItem, oSelect: TListItem;
  bSelectedInGroup: Boolean;
  bFolder: Boolean;

  Procedure AddFile(Const AFullName, AFileName: String);
  Var
    n: Integer;
  Begin
    n := Length(Files);
    SetLength(Files, n + 1);

    Files[n].FullName := AFullName;
    Files[n].FileName := AFileName;
    Files[n].HasDateTime :=
      TryParseInspectionFilename(AFullName, oParsedInfo);

    If Files[n].HasDateTime Then
      Files[n].DateTime := oParsedInfo.DateTime
    Else
      Files[n].DateTime := 0;
  End;

Begin
  oSelect := nil;

  bFolder := DirectoryExists(AFile);

  If bFolder Then
    sFolder := ExcludeTrailingPathDelimiter(AFile)
  Else
    sFolder := ExtractFileDir(AFile);

  If Not DirectoryExists(sFolder) Then
    Exit;

  sDrive := IncludeSlash(ExtractFileDrive(sFolder));
  sSearchMask := IncludeTrailingPathDelimiter(sFolder) + '*.*';

  If FindFirst(sSearchMask, faAnyFile And Not faDirectory, oSearchRec) = 0 Then
  Begin
    Try
      Repeat
        sFullName :=
          IncludeTrailingPathDelimiter(sFolder) + oSearchRec.Name;
        sExt := ExtractFileExt(sFullName);

        If IsVideo(sExt) Then
          AddFile(sFullName, oSearchRec.Name);

      Until FindNext(oSearchRec) <> 0;
    Finally
      FindClose(oSearchRec);
    End;
  End;

  SortVideoFiles(Files);

  lvFiles.BeginUpdate;
  Try
    lvFiles.Items.Clear;

    i := 0;

    While i <= High(Files) Do
    Begin
      iGroupStart := i;
      iCount := 1;

      bSelectedInGroup := Not bFolder And SameFileName(Files[i].FullName, AFile);

      If Files[i].HasDateTime Then
      Begin
        Inc(i);

        While (i <= High(Files)) And Files[i].HasDateTime And
          (SecondsApart(Files[i].DateTime, Files[iGroupStart].DateTime) <=
            RELATED_VIDEO_WINDOW_SEC) Do
        Begin
          Inc(iCount);

          If Not bFolder And SameFileName(Files[i].FullName, AFile) Then
            bSelectedInGroup := True;

          Inc(i);
        End;
      End
      Else
        Inc(i);

      oItem := lvFiles.Items.Add;

      If Files[iGroupStart].HasDateTime Then
      Begin
        oItem.Caption :=
          FormatDateTime('HH:nn:ss', Files[iGroupStart].DateTime);
        oItem.SubItems.Add(
          FormatDateTime('yyyy-mm-dd', Files[iGroupStart].DateTime)
          );
      End
      Else
      Begin
        oItem.Caption := '';
        oItem.SubItems.Add('');
      End;

      oItem.SubItems.Add(IntToStr(iCount));
      oItem.SubItems.Add(Files[iGroupStart].FileName);

      If bSelectedInGroup Then
        oSelect := oItem;
    End;

  Finally
    lvFiles.EndUpdate;
  End;

  FFolder := sFolder;

  Inc(FIgnoreListViewSelectItem);
  Try
    If Assigned(oSelect) Then
    Begin
      oSelect.Selected := True;
      oSelect.Focused := True;
      oSelect.MakeVisible(False);
    End
    Else
    Begin
      // TODO Implement clear
      //fmeVideoPlayer.Clear;
      //fmeSyncedVideo.BeginLoadVideos;
      //fmeSyncedVideo.EndLoadVideos;
    End;
  Finally
    Dec(FIgnoreListViewSelectItem);
  End;

  Inc(FIgnoreTreeViewChange);
  Try
    If ExtractFileDrive(tvFolders.Root) <> ExtractFileDrive(sDrive) Then
    Begin
      tvFolders.Root := sDrive;
      edtRoot.Text := sDrive;
    End;

    If Not SameFileName(ExcludeSlash(tvFolders.Path), ExcludeSlash(sFolder)) Then
      tvFolders.Path := sFolder;
  Finally
    Dec(FIgnoreTreeViewChange);
  End;
End;

Procedure TfrmIMVideo.FormDropFiles(Sender: TObject; Const FileNames: Array Of String);
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

Procedure TfrmIMVideo.lvFilesSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
Var
  arrFiles: TStringArray;
  sFile: String;
Begin
  If (FIgnoreListViewSelectItem > 0) Or FInternalLoad Then
    Exit;

  If (Item.Selected) And (lvFiles.Selected = Item) Then
  Begin
    arrFiles := [];
    sFile := IncludeSlash(FFolder) + Item.Subitems[2];
    AddStringToArray(arrFiles, sFile);

    FInternalLoad := True;
    Try
      OpenVideo(arrFiles);
    Finally
      FInternalLoad := False;
    End;
  End;
End;

Procedure TfrmIMVideo.tvFoldersSelectionChanged(Sender: TObject);
Begin
  If FIgnoreTreeViewChange > 0 Then
    Exit;

  ParseFolder(tvFolders.Path);
End;

Procedure TfrmIMVideo.OpenVideo(Const AFiles: TStrings);
Var
  arrFiles: TStringArray;
Begin
  arrFiles := AFiles.ToStringArray;
  OpenVideo(arrFiles);
End;

Procedure TfrmIMVideo.OpenVideo(Const AFiles: TStringArray);
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

  arrFiles := AFiles;

  If Length(arrFiles) = 1 Then
  Begin
    sFile := arrFiles[0];

    If TryParseInspectionFilename(sFile, oInspectionFilenameInfo) And
      oInspectionFilenameInfo.FoundDateTime Then
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
          FMRU.Add(sFile);
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

      FFolder := ExtractFileDir(sFile);

      Caption := Format('%s: %s', [Application.Title, fmeSyncedVideo.Filename]);

      tmrUpdate.Enabled := True;

      If Not FInternalLoad Then
      Begin
        Inc(FIgnoreListViewSelectItem);
        Try
          ParseFolder(fmeSyncedVideo.Filename);
        Finally
          Dec(FIgnoreListViewSelectItem);
        End;
      End;
    End;
  Finally
    EndFormUpdate;
    Busy := False;
  End;
End;

Procedure TfrmIMVideo.mnuExitClick(Sender: TObject);
Begin
  Close;
End;

Procedure TfrmIMVideo.mnuFileClick(Sender: TObject);
Begin
  FMRU.Populate(mnuOpenRecent, @mnuOpenRecentClick);
  mnuOpenRecent.Enabled := FMRU.Count > 0;
End;

Procedure TfrmIMVideo.mnuOpenClick(Sender: TObject);
Begin
  If dlgOpen.Execute Then
  Begin
    OpenVideo(dlgOpen.Files);
  End;
End;

Procedure TfrmIMVideo.mnuOpenRecentClick(Sender: TObject);
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

Procedure TfrmIMVideo.mnuToggleVideoClick(Sender: TObject);
Begin
  If (fmeSyncedVideo.VideoFileCount Mod 2) = 0 Then
  Begin
    If (Width > Height) Then
      fmeSyncedVideo.Layout(1, fmeSyncedVideo.VideoFileCount)
    Else
      fmeSyncedVideo.Layout(fmeSyncedVideo.VideoFileCount, 1);
  End
  Else If fmeSyncedVideo.VideoFileCount <> 1 Then
  Begin
    If (Width > Height) Then
      fmeSyncedVideo.Layout(2, 2, clsLeftToRightThenDown)
    Else
      fmeSyncedVideo.Layout(2, 2, clsTopToBottomThenRight);
  End;
End;

Procedure TfrmIMVideo.tmrUpdateTimer(Sender: TObject);
Begin
  tmrUpdate.Enabled := False;

  sbMain.Panels[1].Text := 'Start: ' + FormatDateTime('yyyy-mm-dd HH:nn',
    fmeSyncedVideo.StartDateTime);
  sbMain.Panels[2].Text := 'Duration: ' + FormatDateTime('HH:nn:ss',
    fmeSyncedVideo.DurationAsTime);
  sbMain.Panels[3].Text := 'End: ' + FormatDateTime('yyyy-mm-dd HH:nn',
    fmeSyncedVideo.EndDateTime);
End;

Procedure TfrmIMVideo.LoadLocalSettings(oInifile: TIniFile);
Var
  sFolder, sRoot: String;
Begin
  Inherited;

  FMRU.Load(oInifile, 'Files', 'MRU');
  fmeVideoPlayer.LoadSettings(oIniFile);

  Inc(FIgnoreTreeViewChange);
  Try
    sRoot := oIniFile.ReadString('Last', 'Root', '-');
    If (sRoot <> '-') And DirectoryExists(sRoot) Then
    Begin
      edtRoot.Directory := sRoot;
      tvFolders.Root := sRoot;
    End;
  Finally
    Dec(FIgnoreTreeViewChange);
  End;

  sFolder := oIniFile.ReadString('Last', 'Folder', '-');
  If (sFolder <> '-') And DirectoryExists(sFolder) Then
    ParseFolder(sFolder);
End;

Procedure TfrmIMVideo.SaveLocalSettings(oInifile: TIniFile);
Begin
  Inherited;

  FMRU.Save(oInifile, 'Files', 'MRU');
  fmeVideoPlayer.SaveSettings(oIniFile);

  If DirectoryExists(FFolder) Then
    oIniFile.WriteString('Last', 'Folder', FFolder);

  If DirectoryExists(edtRoot.Directory) Then
    oIniFile.WriteString('Last', 'Root', edtRoot.Directory);
End;

End.

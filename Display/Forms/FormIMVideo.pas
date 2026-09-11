Unit FormIMVideo;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}

Interface

Uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  Buttons, Menus, ActnList, ComCtrls, ShellCtrls, EditBtn,
  FrameVideoPlayer, FrameSyncedVideo, FormMain, IniFiles, MRUs;

Type

  { TfrmIMVideo }

  TfrmIMVideo = Class(TFormMain)
    actFoldersOpenFolder: TAction;
    alVideo: TActionList;
    btnRefresh: TBitBtn;
    edtRoot: TDirectoryEdit;
    lvFiles: TListView;
    mnuOpenRecentFolder: TMenuItem;
    mnuFolderOpenFolders: TMenuItem;
    mnuToggleVideo: TMenuItem;
    mnuView: TMenuItem;
    pnlDrive: TPanel;
    pnlLeft: TPanel;
    pmFolders: TPopupMenu;
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
    Procedure actFoldersOpenFolderExecute(Sender: TObject);
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
    Procedure mnuOpenRecentFolderClick(Sender: TObject);
    Procedure mnuToggleVideoClick(Sender: TObject);
    Procedure tmrUpdateTimer(Sender: TObject);
    Procedure tvFoldersSelectionChanged(Sender: TObject);
  Private
    fmeVideoPlayer: TFrameVideoPlayer;
    fmeSyncedVideo: TFrameSyncedVideo;
    FMRUFiles, FMRUFolders: TMRU;
    FLoaded: Boolean;
    FInternalLoad: Boolean;
    FIgnoreListViewSelectItem: Integer;
    FIgnoreTreeViewChange: Integer;
    FFolder: String;

    Procedure OpenVideo(Const AFiles: TStrings); Overload;
    Procedure OpenVideo(Const AFiles: TStringArray); Overload;
    Procedure OpenFolder(AFolder: String);

    Procedure ParseFolderOrFileFolder(AFile: String);
  Public
    Procedure LoadLocalSettings(oInifile: TIniFile); Override;
    Procedure SaveLocalSettings(oInifile: TIniFile); Override;
  End;

Var
  frmIMVideo: TfrmIMVideo;

Implementation

Uses
  FileSupport, VideoEngineFactory, ControlGridLayout, StringSupport,
  InspectionSupport, DateUtils, Math, OSSupport,

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

  FMRUFiles := TMRU.Create;
  FMRUFiles.Max := 10;
  FMRUFiles.Kind := mruFiles;

  FMRUFolders := TMRU.Create;
  FMRUFolders.Max := 10;
  FMRUFolders.Kind := mruFolders;

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

Procedure TfrmIMVideo.FormDestroy(Sender: TObject);
Begin
  FreeAndNil(FMRUFiles);
  FreeAndNil(FMRUFolders);

  FreeAndNil(fmeVideoPlayer);

  Inherited;
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
    ParseFolderOrFileFolder(tvFolders.Path);
  End;
End;

Procedure TfrmIMVideo.actFoldersOpenFolderExecute(Sender: TObject);
Var
  sFolder: String;
Begin
  If tvFolders.Items.Count = 0 Then
    Exit;

  If Not assigned(tvFolders.Selected) Then
    Exit;

  sFolder := tvFolders.Path;

  If DirectoryExists(sFolder) Then
    LaunchFile('explorer.exe', Format('/e,"%s"', [sFolder]));
End;

Procedure TfrmIMVideo.edtRootChange(Sender: TObject);
Begin
  // We may manually set contents during ParseFolder, in code where
  // FIgnoreTreeViewChange is incremented
  If FIgnoreTreeViewChange > 0 Then
    Exit;

  OpenFolder(edtRoot.Directory);
End;

Procedure TfrmIMVideo.FormClose(Sender: TObject; Var CloseAction: TCloseAction);
Begin
  If assigned(fmeVideoPlayer) Then
    fmeVideoPlayer.Clear;

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
    FormatName: String;
  End;

Function SecondsApart(Const A, B: TDateTime): Double;
Begin
  Result := Abs(A - B) * 24 * 60 * 60;
End;

Procedure SortVideoFiles(Var AFiles: Array Of TVideoFileInfo);

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

  Procedure QuickSort(L, R: Integer);
  Var
    i, J: Integer;
    Pivot, Temp: TVideoFileInfo;
  Begin
    i := L;
    J := R;
    Pivot := AFiles[(L + R) Div 2];

    Repeat
      While CompareVideoFileInfo(AFiles[i], Pivot) < 0 Do Inc(i);
      While CompareVideoFileInfo(AFiles[J], Pivot) > 0 Do Dec(J);

      If i <= J Then
      Begin
        Temp := AFiles[i];
        AFiles[i] := AFiles[J];
        AFiles[J] := Temp;
        Inc(i);
        Dec(J);
      End;
    Until i > J;

    If L < J Then QuickSort(L, J);
    If i < R Then QuickSort(i, R);
  End;

Begin
  If Length(AFiles) > 1 Then
    QuickSort(0, High(AFiles));
End;

Procedure TfrmIMVideo.ParseFolderOrFileFolder(AFile: String);
Var
  sFolder, sExt, sSearchMask, sFullName, sDrive: String;
  oSearchRec: TSearchRec;
  oParsedInfo: TInspectionFilenameInfo;
  arrFiles: Array Of TVideoFileInfo;
  i, iGroupStart, iCount: Integer;
  oItem, oSelect: TListItem;
  bSelectedInGroup: Boolean;
  bFolder, bHasTimeInFilename: Boolean;

  Procedure AddFile(Const AFullName, AFileName: String);
  Var
    n: Integer;
    bHasDateTime: Boolean;
  Begin
    n := Length(arrFiles);
    SetLength(arrFiles, n + 1);

    bHasDateTime := TryParseInspectionFilename(AFullName, oParsedInfo);

    arrFiles[n].FullName := AFullName;
    arrFiles[n].FileName := AFileName;
    arrFiles[n].HasDateTime := bHasDateTime;

    If bHasDateTime Then
    Begin
      arrFiles[n].DateTime := oParsedInfo.DateTime;
      arrFiles[n].FormatName := oParsedInfo.FormatName;
    End
    Else
    Begin
      arrFiles[n].DateTime := 0;
      arrFiles[n].FormatName := '';
    End;

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
  sSearchMask := IncludeSlash(sFolder) + '*.*';

  If FindFirst(sSearchMask, faAnyFile And Not faDirectory, oSearchRec) = 0 Then
  Begin
    Try
      Repeat
        sFullName := IncludeSlash(sFolder) + oSearchRec.Name;
        sExt := ExtractFileExt(sFullName);

        If IsVideo(sExt) Then
          AddFile(sFullName, oSearchRec.Name);

      Until FindNext(oSearchRec) <> 0;
    Finally
      FindClose(oSearchRec);
    End;
  End;

  SortVideoFiles(arrFiles);

  lvFiles.BeginUpdate;
  Try
    lvFiles.Items.Clear;

    i := Low(arrFiles);

    bHasTimeInFilename := False;

    // First, let's work out if any of these Files are multichannel
    // baed on us having decoded times from the filenames and these
    // times being within RELATED_VIDEO_WINDOW_SEC seconds of each other
    While i <= High(arrFiles) Do
    Begin
      iGroupStart := i;
      iCount := 1;

      bSelectedInGroup := Not bFolder And SameFileName(arrFiles[i].FullName, AFile);

      If arrFiles[i].HasDateTime Then
      Begin
        Inc(i);

        While (i <= High(arrFiles)) And arrFiles[i].HasDateTime And
          (SecondsApart(arrFiles[i].DateTime, arrFiles[iGroupStart].DateTime) <=
            RELATED_VIDEO_WINDOW_SEC) Do
        Begin
          Inc(iCount);

          If Not bFolder And SameFileName(arrFiles[i].FullName, AFile) Then
            bSelectedInGroup := True;

          Inc(i);
        End;
      End
      Else
        Inc(i);

      oItem := lvFiles.Items.Add;

      If arrFiles[iGroupStart].HasDateTime Then
      Begin
        bHasTimeInFilename := True;

        oItem.Caption := FormatDateTime('yyyy-mm-dd', arrFiles[iGroupStart].DateTime);
        oItem.SubItems.Add(FormatDateTime('HH:nn:ss', arrFiles[iGroupStart].DateTime));
      End
      Else
      Begin
        oItem.Caption := '';
        oItem.SubItems.Add('');
      End;

      oItem.SubItems.Add(IntToStr(iCount));
      oItem.SubItems.Add(arrFiles[iGroupStart].FileName);

      // Display the file modification time - this will help videos
      // that aren't multichannel
      oItem.SubItems.Add(FormatDateTime('yyyy-mm-dd HH:nn:ss',
        FileModificationDate(IncludeSlash(sFolder) + arrFiles[iGroupStart].FileName)));

      // What software do we think created the video?
      oItem.SubItems.Add(arrFiles[iGroupStart].FormatName);

      If bSelectedInGroup Then
        oSelect := oItem;
    End;
  Finally
    lvFiles.EndUpdate;
  End;

  // Hide the first three columns if these aren't multi-channel videos
  lvFiles.Columns[0].Visible := bHasTimeInFilename;
  lvFiles.Columns[1].Visible := bHasTimeInFilename;
  lvFiles.Columns[2].Visible := bHasTimeInFilename;

  // Set the project wide active folder
  FFolder := sFolder;

  // Try to select a sensible default - either the file that was passed to
  // ParseFolderOrFileFolder, or the first file in the listview
  Busy := True;
  Try
    If Not assigned(oSelect) And Not assigned(lvFiles.Selected) And
      (lvFiles.Items.Count > 0) Then
      oSelect := lvFiles.Items[0];

    If assigned(oSelect) Then
    Begin
      oSelect.Selected := True;
      oSelect.Focused := True;
      oSelect.MakeVisible(False);
    End
    Else
    Begin
      fmeVideoPlayer.Clear;

      // TODO: Implement fmeSyncedVideo.clear
      //       Not done now as this will require testing all Video modules
      fmeSyncedVideo.ClearVideoCount;
      fmeSyncedVideo.ClearUnloadedVideoFrames;
    End;
  Finally
    Busy := False;
  End;

  Inc(FIgnoreTreeViewChange);
  Try
    If ExtractFileDrive(tvFolders.Root) <> ExtractFileDrive(sDrive) Then
      OpenFolder(sDrive);

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
    sFile := IncludeSlash(FFolder) + Item.SubItems[2];
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

  ParseFolderOrFileFolder(tvFolders.Path);
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
  If Not assigned(AFiles) Then
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
    If Not assigned(fmeSyncedVideo) Then
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
          FMRUFiles.Add(sFile);
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

      Caption := Format('%s: %s', [Application.Title, fmeSyncedVideo.FileName]);

      tmrUpdate.Enabled := True;

      If Not FInternalLoad Then
      Begin
        Inc(FIgnoreListViewSelectItem);
        Try
          ParseFolderOrFileFolder(fmeSyncedVideo.FileName);
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

Procedure TfrmIMVideo.OpenFolder(AFolder: String);
Begin
  If Not DirectoryExists(AFolder) Then
    Exit;

  //If ExtractFileDrive(tvFolders.Root) <> ExtractFileDrive(AFolder) Then
  //Begin
    Inc(FIgnoreTreeViewChange);
    Try
      edtRoot.Text := AFolder;
      tvFolders.Root := AFolder;

      FMRUFolders.Add(AFolder);

      If tvFolders.Items.Count > 0 Then
      Begin
        tvFolders.Selected := tvFolders.Items[0];

        ParseFolderOrFileFolder(AFolder);
      End;
    Finally
      Dec(FIgnoreTreeViewChange);
    End;
  //End;
End;

Procedure TfrmIMVideo.mnuExitClick(Sender: TObject);
Begin
  Close;
End;

Procedure TfrmIMVideo.mnuFileClick(Sender: TObject);
Begin
  FMRUFiles.Populate(mnuOpenRecent, @mnuOpenRecentClick);
  mnuOpenRecent.Enabled := FMRUFiles.Count > 0;

  FMRUFolders.Populate(mnuOpenRecentFolder, @mnuOpenRecentFolderClick);
  mnuOpenRecentFolder.Enabled := FMRUFolders.Count > 0;
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
  If (Sender Is TMenuItem) And (TMenuItem(Sender).Tag < FMRUFiles.Count) Then
  Begin
    slFiles := TStringList.Create;
    Try
      slFiles.Add(FMRUFiles.Value(TMenuItem(Sender).Tag));
      OpenVideo(slFiles);
    Finally
      slFiles.Free;
    End;
  End;
End;

Procedure TfrmIMVideo.mnuOpenRecentFolderClick(Sender: TObject);
Var
  sDrive: String;
Begin
  If (Sender Is TMenuItem) And (TMenuItem(Sender).Tag < FMRUFolders.Count) Then
  Begin
    sDrive := FMRUFolders.Value(TMenuItem(Sender).Tag);

    OpenFolder(sDrive);
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
  iTemp: Longint;
Begin
  Inherited;

  FMRUFiles.Load(oInifile, 'Files', 'MRU');
  FMRUFolders.Load(oInifile, 'Folders', 'MRU');

  fmeVideoPlayer.LoadSettings(oInifile);

  Inc(FIgnoreTreeViewChange);
  Try
    sRoot := oInifile.ReadString('Last', 'Root', '-');
    If (sRoot <> '-') And DirectoryExists(sRoot) Then
      OpenFolder(sRoot);
  Finally
    Dec(FIgnoreTreeViewChange);
  End;

  sFolder := oInifile.ReadString('Last', 'Folder', '-');
  If (sFolder <> '-') And DirectoryExists(sFolder) Then
    ParseFolderOrFileFolder(sFolder);

  iTemp := oInifile.ReadInteger('Last', 'Files Height', -1);
  tvFolders.Height := EnsureRange(iTemp, 160, pnlLeft.Height - 160);
  tvFolders.Top := pnlDrive.Height;

  iTemp := oInifile.ReadInteger('Last', 'Files Width', -1);
  pnlLeft.Width := EnsureRange(iTemp, 250, frmIMVideo.Width Div 2);
End;

Procedure TfrmIMVideo.SaveLocalSettings(oInifile: TIniFile);
Begin
  Inherited;

  FMRUFiles.Save(oInifile, 'Files', 'MRU');
  FMRUFolders.Save(oInifile, 'Folders', 'MRU');

  fmeVideoPlayer.SaveSettings(oInifile);

  If DirectoryExists(FFolder) Then
    oInifile.WriteString('Last', 'Folder', FFolder);

  If DirectoryExists(edtRoot.Directory) Then
    oInifile.WriteString('Last', 'Root', edtRoot.Directory);

  oInifile.WriteInteger('Last', 'Files Height', lvFiles.Height);
  oInifile.WriteInteger('Last', 'Files Width', pnlLeft.Width);
End;

End.

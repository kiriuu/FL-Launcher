#Requires AutoHotkey v2.0
#SingleInstance Force

; Salvataggio automatico delle statistiche alla chiusura dello script
OnExit(SaveStatsOnExit)

; ==============================================================================
; AUTOSTART IN BACKGROUND CONFIGURATION
; ==============================================================================
global IsBackgroundMode := false

for arg in A_Args {
    if (StrLower(arg) == "/background" || StrLower(arg) == "-background") {
        global IsBackgroundMode := true
        break
    }
}

StartupLnk := A_Startup "\FL-Launcher.lnk"
if !FileExist(StartupLnk) {
    try {
        if A_IsCompiled {
            FileCreateShortcut(A_ScriptFullPath, StartupLnk, A_ScriptDir, "/background", "FL Launcher Background Startup")
        } else {
            FileCreateShortcut(A_AhkPath, StartupLnk, A_ScriptDir, '"' A_ScriptFullPath '" /background', "FL Launcher Background Startup")
        }
    }
}

; ==============================================================================
; CONFIGURATION & GLOBALS
; ==============================================================================
global IniPath := A_ScriptDir "\launcher_config.ini"
global LogoPath := A_ScriptDir "\fl-studio.png"
global DefaultProjectsDir := A_MyDocuments "\Image-Line\FL Studio\Projects"
global ProjectsFolder := RTrim(IniRead(IniPath, "Settings", "ProjectsFolder", DefaultProjectsDir), "\")
global FLStudioPath := IniRead(IniPath, "Settings", "FLStudioPath", "C:\Program Files\Image-Line\FL Studio 2026\FL64.exe")

global CurrentDate := A_YYYY "_" A_MM "_" A_DD
global DailySeconds := Number(IniRead(IniPath, "Stats", CurrentDate, 0))
global TotalSeconds := Number(IniRead(IniPath, "Stats", "TotalSeconds", 0))
global ProjectSeconds := 0
global LastDetectedProject := ""
global CurrentProjectList := []
global CurrentSelectedFolderPath := ProjectsFolder

global hLogoLoading := 0
global hLogoMain := 0

; ==============================================================================
; SYSTEM TRAY SETUP
; ==============================================================================
A_IconTip := "FL Launcher"
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("🎛️ Open Launcher", (*) => MainGui.Show())
Tray.Add("🚀 Launch FL Studio", (*) => RunFLStudio())
Tray.Add()
Tray.Add("❌ Exit Launcher", (*) => ExitApp())
Tray.Default := "🎛️ Open Launcher"

; ==============================================================================
; STARTUP LOADING SCREEN
; ==============================================================================
if !IsBackgroundMode {
    LoadingGui := Gui("+ToolWindow -Caption +AlwaysOnTop", "Loading")
    LoadingGui.BackColor := "0D0E12"

    if FileExist(LogoPath) {
        hLogoLoading := CreateScaledBitmap(LogoPath, 30, 30)
        if hLogoLoading
            LoadingGui.AddPicture("x45 y20 w30 h30", "HBITMAP:" hLogoLoading)
        
        LoadingGui.SetFont("s16 q5 Bold c00F0FF", "Segoe UI Variable Display")
        LoadingGui.AddText("x83 y20 w180 h35", "FL LAUNCHER")
    } else {
        LoadingGui.SetFont("s16 q5 Bold c00F0FF", "Segoe UI Variable Display")
        LoadingGui.AddText("x30 y20 w240 h35 Center", "FL LAUNCHER")
    }

    LoadingGui.SetFont("s10 q5 c8B95A5", "Segoe UI Variable Text")
    LoadingGui.AddText("x30 y60 w240 h25 Center", "Loading DAW environment...")
    LoadingProg := LoadingGui.AddProgress("x30 y95 w240 h4 Background151720 c00F0FF Range0-100", 30)
    LoadingGui.Show("w300 h130")

    Sleep(200)
    LoadingProg.Value := 75
    Sleep(200)
}

if !IsBackgroundMode && IsSet(LoadingGui) {
    LoadingProg.Value := 100
    Sleep(150)
    LoadingGui.Destroy()
}

; ==============================================================================
; MAIN GUI
; ==============================================================================
MainGui := Gui("-Resize", "FL Launcher")
MainGui.BackColor := "0D0E12"

MainGui.OnEvent("Close", (*) => MainGui.Hide())

; ------------------------------------------------------------------------------
; LEFT SIDEBAR
; ------------------------------------------------------------------------------
if FileExist(LogoPath) {
    hLogoMain := CreateScaledBitmap(LogoPath, 28, 28)
    if hLogoMain
        MainGui.AddPicture("x20 y16 w28 h28", "HBITMAP:" hLogoMain)
    
    MainGui.SetFont("s15 q5 Bold c00F0FF", "Segoe UI Variable Display")
    MainGui.AddText("x54 y16 w200 h30", "FL LAUNCHER")
} else {
    MainGui.SetFont("s15 q5 Bold c00F0FF", "Segoe UI Variable Display")
    MainGui.AddText("x20 y16 w240 h30", "FL LAUNCHER")
}

MainGui.SetFont("s8 q5 Bold c5A6578", "Segoe UI Variable Text")
MainGui.AddText("x20 y52 w240 h18", "WORKSPACE LIBRARY")

FolderTree := MainGui.AddTreeView("x20 y72 w240 h450 Background111217 cE2E8F0 -Border")
FolderTree.OnEvent("ItemSelect", OnFolderSelect)
FolderTree.OnEvent("ContextMenu", ShowFolderContextMenu)

MainGui.AddProgress("x20 y530 w240 h1 Background232635 c232635", 100)

MainGui.SetFont("s10 q5 Bold cWhite", "Segoe UI Variable Text")
StatusDot := MainGui.AddText("x20 y539 w22 h22 Center", "⚪")
StatusText := MainGui.AddText("x45 y540 w100 h22", "Offline")

BtnLaunch := MainGui.AddButton("x20 y570 w240 h45", "🚀 LAUNCH FL STUDIO")
BtnLaunch.OnEvent("Click", (*) => RunFLStudio())

; ------------------------------------------------------------------------------
; RIGHT MAIN WORKSPACE AREA
; ------------------------------------------------------------------------------
MainGui.SetFont("s8 q5 Bold c5A6578", "Segoe UI Variable Text")
MainGui.AddText("x280 y15 w180 h16", "TODAY'S SESSION")
MainGui.SetFont("s13 q5 Bold cFF9900", "Segoe UI Variable Display")
DailyTimeLabel := MainGui.AddText("x280 y32 w180 h26", "00:00:00")

MainGui.SetFont("s8 q5 Bold c5A6578", "Segoe UI Variable Text")
MainGui.AddText("x480 y15 w180 h16", "ACTIVE PROJECT")
MainGui.SetFont("s13 q5 Bold c00F0FF", "Segoe UI Variable Display")
ProjectTimeLabel := MainGui.AddText("x480 y32 w180 h26", "00:00:00")

MainGui.SetFont("s8 q5 Bold c5A6578", "Segoe UI Variable Text")
MainGui.AddText("x680 y15 w180 h16", "TOTAL STUDIO TIME")
MainGui.SetFont("s13 q5 Bold cA855F7", "Segoe UI Variable Display")
TotalTimeLabel := MainGui.AddText("x680 y32 w180 h26", "00:00:00")

BtnRefresh := MainGui.AddButton("x1095 y15 w90 h42", "🔄 Sync")
BtnRefresh.OnEvent("Click", (*) => RefreshAll())

MainGui.AddProgress("x280 y68 w905 h1 Background232635 c232635", 100)

MainGui.SetFont("s10 q5 cE2E8F0", "Segoe UI Variable Text")
SearchEdit := MainGui.AddEdit("x280 y82 w460 h36 Background151720 cE2E8F0 -Border", "")
SearchEdit.OnEvent("Change", (*) => DisplayProjects())
DllCall("SendMessage", "Ptr", SearchEdit.Hwnd, "UInt", 0x1501, "Ptr", 1, "WStr", "🔍 Search project by name...")

MainGui.SetFont("s9 q5 Bold cBlack", "Segoe UI Variable Text")
BtnAdd    := MainGui.AddButton("x750 y82 w95 h36", "➕ Import")
BtnAdd.OnEvent("Click", (*) => AddExternalProject())

BtnMove   := MainGui.AddButton("x855 y82 w90 h36", "📦 Move")
BtnMove.OnEvent("Click", (*) => MoveSelectedItem())

BtnDelete := MainGui.AddButton("x955 y82 w95 h36", "🗑️ Delete")
BtnDelete.OnEvent("Click", (*) => DeleteSelectedItem())

BtnFolder := MainGui.AddButton("x1060 y82 w125 h36", "📂 Root Dir")
BtnFolder.OnEvent("Click", SelectProjectsFolder)

ProjectLV := MainGui.AddListView("x280 y128 w905 h500 -Multi Background111217 cE2E8F0 -Border", ["Project Name", "Last Modified", "Path"])
ProjectLV.OnEvent("DoubleClick", OpenSelectedProject)
ProjectLV.OnEvent("ContextMenu", ShowLVContextMenu)

PopulateFolderTree()
LoadProjectsFromFolder(ProjectsFolder)

SetTimer(TrackStatusAndTime, 1000)

if !IsBackgroundMode {
    MainGui.Show("w1205 h645")
}

; ==============================================================================
; HIGH QUALITY GDI+ IMAGE RESIZING FUNCTION
; ==============================================================================
CreateScaledBitmap(imgPath, targetW, targetH) {
    static pToken := 0
    if !pToken {
        gdiplusInput := Buffer(24, 0)
        NumPut("UInt", 1, gdiplusInput)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &pToken, "Ptr", gdiplusInput, "Ptr", 0)
    }

    pBitmap := 0
    pBitmapResized := 0
    pGraphics := 0
    hBitmap := 0

    if DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", imgPath, "Ptr*", &pBitmap) != 0
        return 0

    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", targetW, "Int", targetH, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmapResized)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmapResized, "Ptr*", &pGraphics)

    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", pGraphics, "Int", 7)
    DllCall("gdiplus\GdipDrawImageRectI", "Ptr", pGraphics, "Ptr", pBitmap, "Int", 0, "Int", 0, "Int", targetW, "Int", targetH)

    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmapResized, "Ptr*", &hBitmap, "UInt", 0xFF000000)

    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmapResized)

    return hBitmap
}

; ==============================================================================
; CONTEXT MENUS & ZIPPING LOGIC
; ==============================================================================

ShowFolderContextMenu(TreeObj, ItemID, IsRightClick, X, Y) {
    if (ItemID == 0)
        return

    FolderTree.Modify(ItemID, "Select")
    FolderPath := GetFullPath(ItemID)

    FolderMenu := Menu()
    FolderMenu.Add("📦 Save to ZIP...", (*) => ZipFolderToDestination(FolderPath))
    FolderMenu.Show(X, Y)
}

ZipFolderToDestination(FolderPath) {
    SplitPath(FolderPath, &FolderName)
    TargetFolder := DirSelect("*" ProjectsFolder, 3, "Select destination for ZIP: " FolderName)
    if !TargetFolder
        return

    DestZip := TargetFolder "\" FolderName ".zip"
    if FileExist(DestZip) {
        if (MsgBox("A ZIP file already exists in destination. Overwrite?", "File Exists", 4) != "Yes")
            return
        FileDelete(DestZip)
    }

    ZipGui := Gui("+ToolWindow -Caption +AlwaysOnTop", "Compressing")
    ZipGui.BackColor := "0D0E12"
    ZipGui.SetFont("s11 q5 Bold c00F0FF", "Segoe UI Variable Display")
    ZipGui.AddText("x20 y20 w260 h25 Center", "📦 Zipping folder...")
    ZipGui.SetFont("s9 q5 c8B95A5", "Segoe UI Variable Text")
    ZipGui.AddText("x20 y50 w260 h20 Center", "Please wait...")
    ZipGui.AddProgress("x20 y80 w260 h4 Background151720 c00F0FF Range0-0", 0)
    ZipGui.Show("w300 h110")

    try {
        SafeFolder := StrReplace(FolderPath, "'", "''")
        SafeZip := StrReplace(DestZip, "'", "''")
        psCmd := Format("powershell -NoProfile -Command `"Compress-Archive -LiteralPath '{1}' -DestinationPath '{2}' -Force`"", SafeFolder, SafeZip)
        RunWait(psCmd, , "Hide")
        ZipGui.Destroy()
        MsgBox("Folder successfully zipped to:`n" DestZip, "Completed", "Iconi")
    } catch {
        ZipGui.Destroy()
        MsgBox("Error creating ZIP file.", "Error", "Icon!")
    }
}

ShowLVContextMenu(LV, Item, IsRightClick, X, Y) {
    if (Item == 0)
        return

    LVMenu := Menu()
    LVMenu.Add("🚀 Open", (*) => OpenSelectedProject(LV, Item))
    LVMenu.Add("📦 Save to ZIP...", (*) => ZipProjectToDestination(LV, Item))
    LVMenu.Add("📋 Details", (*) => ShowProjectDetails(LV, Item))
    LVMenu.Show(X, Y)
}

ZipProjectToDestination(LV, RowNumber) {
    ProjectPath := LV.GetText(RowNumber, 3)
    ProjName := LV.GetText(RowNumber, 1)

    if !FileExist(ProjectPath)
        return

    TargetFolder := DirSelect("*" ProjectsFolder, 3, "Select destination for ZIP: " ProjName)
    if !TargetFolder
        return

    SplitPath(ProjName, &NoExtName)
    DestZip := TargetFolder "\" NoExtName ".zip"

    if FileExist(DestZip) {
        if (MsgBox("A ZIP file already exists in destination. Overwrite?", "File Exists", 4) != "Yes")
            return
        FileDelete(DestZip)
    }

    ZipGui := Gui("+ToolWindow -Caption +AlwaysOnTop", "Compressing")
    ZipGui.BackColor := "0D0E12"
    ZipGui.SetFont("s11 q5 Bold c00F0FF", "Segoe UI Variable Display")
    ZipGui.AddText("x20 y20 w260 h25 Center", "📦 Zipping project...")
    ZipGui.SetFont("s9 q5 c8B95A5", "Segoe UI Variable Text")
    ZipGui.AddText("x20 y50 w260 h20 Center", "Please wait...")
    ZipGui.AddProgress("x20 y80 w260 h4 Background151720 c00F0FF Range0-0", 0)
    ZipGui.Show("w300 h110")

    try {
        SafeProject := StrReplace(ProjectPath, "'", "''")
        SafeZip := StrReplace(DestZip, "'", "''")
        psCmd := Format("powershell -NoProfile -Command `"Compress-Archive -LiteralPath '{1}' -DestinationPath '{2}' -Force`"", SafeProject, SafeZip)
        RunWait(psCmd, , "Hide")
        ZipGui.Destroy()
        MsgBox("Project successfully zipped to:`n" DestZip, "Completed", "Iconi")
    } catch {
        ZipGui.Destroy()
        MsgBox("Error creating ZIP file.", "Error", "Icon!")
    }
}

ShowProjectDetails(LV, RowNumber) {
    ProjectPath := LV.GetText(RowNumber, 3)
    ProjName := LV.GetText(RowNumber, 1)

    if !FileExist(ProjectPath)
        return

    CleanName := RegExReplace(ProjName, "i)\.flp$", "")

    FileModTime := FileGetTime(ProjectPath, "M")
    FormattedModTime := FormatTime(FileModTime, "yyyy/MM/dd, HH:mm")

    SavedProjectSeconds := Number(IniRead(IniPath, "ProjectStats", CleanName, 0))
    FormattedProjectTime := FormatSecondsLong(SavedProjectSeconds)

    DetailsGui := Gui("+Owner" MainGui.Hwnd " +ToolWindow", "Project Details — " ProjName)
    DetailsGui.BackColor := "0D0E12"

    SaveAndCloseGui(LaunchProject := false) {
        IniWrite(EncodeMultiline(DetailsEdit.Value), IniPath, "CustomDetails", CleanName)
        DetailsGui.Destroy()
        if LaunchProject {
            RunFLStudio(ProjectPath)
        }
    }

    BtnBack := DetailsGui.AddButton("x20 y20 w90 h32", "⬅️ Back")
    BtnBack.OnEvent("Click", (*) => SaveAndCloseGui(false))

    DetailsGui.SetFont("s13 q5 Bold c00F0FF", "Segoe UI Variable Display")
    DetailsGui.AddText("x125 y22 w320 h35", ProjName)

    BtnOpen := DetailsGui.AddButton("x465 y20 w80 h32", "Open")
    BtnOpen.OnEvent("Click", (*) => SaveAndCloseGui(true))

    DetailsGui.SetFont("s10 q5 Bold cA855F7", "Segoe UI Variable Text")
    DetailsGui.AddText("x20 y65 w525 h22", "Project Notes")

    SavedDetailsRaw := IniRead(IniPath, "CustomDetails", CleanName, "")
    SavedDetails := DecodeMultiline(SavedDetailsRaw)
    
    if (SavedDetails == "") {
        SavedDetails := "BPM: N/A`nPlugins: N/A`nSamples: N/A`nKey: N/A"
    }

    DetailsGui.SetFont("s9 q5 cE2E8F0", "Segoe UI Variable Text")
    DetailsEdit := DetailsGui.AddEdit("x20 y90 w525 h180 Background151720 -Border", SavedDetails)
    
    DetailsGui.SetFont("s9 q5 c8B95A5", "Segoe UI Variable Text")
    MetaText := "⏱️ Project Time: " FormattedProjectTime "  |  📅 Last Modified: " FormattedModTime
    DetailsGui.AddText("x20 y280 w525 h25", MetaText)

    DetailsGui.OnEvent("Close", (*) => SaveAndCloseGui(false))
    DetailsGui.OnEvent("Escape", (*) => SaveAndCloseGui(false))
    DetailsGui.Show("w565 h315")
}

EncodeMultiline(str) {
    str := StrReplace(str, "`r`n", "<br>")
    return StrReplace(str, "`n", "<br>")
}

DecodeMultiline(str) {
    return StrReplace(str, "<br>", "`r`n")
}

FormatSecondsLong(Sec) {
    Hours := Floor(Sec / 3600)
    Minutes := Floor(Mod(Sec, 3600) / 60)
    Seconds := Mod(Sec, 60)
    return Hours "h " Minutes "m " Seconds "s"
}

; ==============================================================================
; GENERAL LOGIC & TIME TRACKING
; ==============================================================================

SaveStatsOnExit(ExitReason, ExitCode) {
    SaveStatsToDisk()
    if hLogoLoading
        DllCall("DeleteObject", "Ptr", hLogoLoading)
    if hLogoMain
        DllCall("DeleteObject", "Ptr", hLogoMain)
}

SaveStatsToDisk() {
    global DailySeconds, TotalSeconds, ProjectSeconds, LastDetectedProject, CurrentDate, IniPath
    IniWrite(DailySeconds, IniPath, "Stats", CurrentDate)
    IniWrite(TotalSeconds, IniPath, "Stats", "TotalSeconds")
    if (LastDetectedProject != "" && LastDetectedProject != "FL Studio") {
        IniWrite(ProjectSeconds, IniPath, "ProjectStats", LastDetectedProject)
    }
}

RefreshAll() {
    PopulateFolderTree()
    if (CurrentSelectedFolderPath != "" && DirExist(CurrentSelectedFolderPath)) {
        LoadProjectsFromFolder(CurrentSelectedFolderPath)
    }
}

RunFLStudio(ProjectPath := "") {
    global FLStudioPath
    if !FileExist(FLStudioPath) {
        SelectedFile := FileSelect(1, "C:\Program Files\Image-Line\FL Studio 2026", "Locate FL64.exe", "Executables (*.exe)")
        if SelectedFile {
            FLStudioPath := SelectedFile
            IniWrite(FLStudioPath, IniPath, "Settings", "FLStudioPath")
        } else {
            return
        }
    }

    if (ProjectPath != "") {
        Run('"' FLStudioPath '" "' ProjectPath '"')
    } else {
        Run('"' FLStudioPath '"')
    }
}

SelectProjectsFolder(*) {
    SelectedFolder := DirSelect("*" ProjectsFolder, 3, "Select root folder for FL Studio projects")
    if SelectedFolder {
        global ProjectsFolder := RTrim(SelectedFolder, "\")
        global CurrentSelectedFolderPath := ProjectsFolder
        IniWrite(ProjectsFolder, IniPath, "Settings", "ProjectsFolder")
        PopulateFolderTree()
        LoadProjectsFromFolder(ProjectsFolder)
    }
}

AddExternalProject() {
    SelectedFile := FileSelect(1, , "Select .flp file to import", "FL Studio Projects (*.flp)")
    if !SelectedFile
        return
    
    SplitPath(SelectedFile, &FileName)
    TargetFolder := CurrentSelectedFolderPath != "" ? CurrentSelectedFolderPath : ProjectsFolder
    
    if !DirExist(TargetFolder)
        TargetFolder := ProjectsFolder

    DestPath := TargetFolder "\" FileName
    
    if FileExist(DestPath) {
        if (MsgBox("A file with this name already exists in destination. Overwrite?", "File Exists", 4) != "Yes")
            return
    }

    FileCopy(SelectedFile, DestPath, 1)
    LoadProjectsFromFolder(TargetFolder)
}

MoveSelectedItem() {
    global ProjectLV, FolderTree, ProjectsFolder, CurrentSelectedFolderPath, MainGui
    
    Row := ProjectLV.GetNext()
    if (Row > 0) {
        ProjectPath := ProjectLV.GetText(Row, 3)
        ProjName := ProjectLV.GetText(Row, 1)
        
        if (ProjectPath != "" && FileExist(ProjectPath)) {
            TargetFolder := DirSelect("*" ProjectsFolder, 3, "Moving: " ProjName)
            if !TargetFolder
                return
            
            DestPath := TargetFolder "\" ProjName
            if FileExist(DestPath) {
                if (MsgBox("File already exists in destination. Overwrite?", "Warning", 4) != "Yes")
                    return
            }
            
            FileMove(ProjectPath, DestPath, 1)
            LoadProjectsFromFolder(CurrentSelectedFolderPath)
        }
    } else {
        try {
            if (ControlGetFocus(MainGui.Hwnd) == FolderTree.Hwnd) {
                SelectedID := FolderTree.GetSelection()
                if SelectedID {
                    FolderPath := GetFullPath(SelectedID)
                    if (StrLower(FolderPath) == StrLower(ProjectsFolder)) {
                        return
                    }
                    
                    SplitPath(FolderPath, &FolderName)
                    TargetFolder := DirSelect("*" ProjectsFolder, 3, "Move folder " FolderName " to:")
                    if !TargetFolder
                        return
                    
                    DestPath := TargetFolder "\" FolderName
                    DirMove(FolderPath, DestPath, "R")
                    PopulateFolderTree()
                    LoadProjectsFromFolder(ProjectsFolder)
                }
            }
        } catch {
            return
        }
    }
}

DeleteSelectedItem() {
    global ProjectLV, FolderTree, ProjectsFolder, CurrentSelectedFolderPath, MainGui
    
    Row := ProjectLV.GetNext()
    if (Row > 0) {
        ProjectPath := ProjectLV.GetText(Row, 3)
        ProjName := ProjectLV.GetText(Row, 1)
        
        if (ProjectPath != "" && FileExist(ProjectPath)) {
            if (MsgBox("Move this project to Recycle Bin?`n`n" ProjName, "Confirm Deletion", 4) == "Yes") {
                FileRecycle(ProjectPath)
                LoadProjectsFromFolder(CurrentSelectedFolderPath)
            }
        }
    } else {
        try {
            if (ControlGetFocus(MainGui.Hwnd) == FolderTree.Hwnd) {
                SelectedID := FolderTree.GetSelection()
                if SelectedID {
                    FolderPath := GetFullPath(SelectedID)
                    if (StrLower(FolderPath) == StrLower(ProjectsFolder)) {
                        return
                    }
                    
                    SplitPath(FolderPath, &FolderName)
                    if (MsgBox("Permanently delete this folder and all its contents?`n`n" FolderName, "Confirm Deletion", 4) == "Yes") {
                        DirDelete(FolderPath, 1)
                        PopulateFolderTree()
                        LoadProjectsFromFolder(ProjectsFolder)
                    }
                }
            }
        } catch {
            return
        }
    }
}

PopulateFolderTree() {
    FolderTree.Delete()
    if !DirExist(ProjectsFolder)
        return

    RootItem := FolderTree.Add(ProjectsFolder, 0, "Expand")
    AddSubFolders(ProjectsFolder, RootItem)
    FolderTree.Modify(RootItem, "Select")
}

AddSubFolders(ParentPath, ParentNode) {
    SubFolderList := []
    Loop Files, ParentPath "\*", "D" {
        ModTime := FileGetTime(A_LoopFilePath, "M")
        SubFolderList.Push({Name: A_LoopFileName, Path: A_LoopFilePath, Time: ModTime})
    }

    SortItemList(SubFolderList)

    for folder in SubFolderList {
        ChildNode := FolderTree.Add(folder.Name, ParentNode)
        AddSubFolders(folder.Path, ChildNode)
    }
}

OnFolderSelect(TreeObj, ItemID) {
    global CurrentSelectedFolderPath := GetFullPath(ItemID)
    LoadProjectsFromFolder(CurrentSelectedFolderPath)
}

GetFullPath(ItemID) {
    PathParts := []
    CurrentID := ItemID

    while CurrentID {
        PathParts.InsertAt(1, FolderTree.GetText(CurrentID))
        CurrentID := FolderTree.GetParent(CurrentID)
    }

    FullPath := ""
    for index, part in PathParts {
        if index == 1
            FullPath := part
        else
            FullPath .= "\" part
    }
    return FullPath
}

LoadProjectsFromFolder(FolderPath) {
    global CurrentProjectList := []

    Loop Files, FolderPath "\*.flp", "F" {
        ModTime := FileGetTime(A_LoopFilePath, "M")
        CurrentProjectList.Push({Name: A_LoopFileName, Time: ModTime, Path: A_LoopFilePath})
    }

    SortItemList(CurrentProjectList)
    DisplayProjects()
}

DisplayProjects() {
    ProjectLV.Delete()
    SearchTerm := StrLower(SearchEdit.Value)

    for proj in CurrentProjectList {
        if (SearchTerm != "" && !InStr(StrLower(proj.Name), SearchTerm))
            continue
        FormattedDate := FormatTime(proj.Time, "yyyy/MM/dd HH:mm:ss")
        ProjectLV.Add(, proj.Name, FormattedDate, proj.Path)
    }
    
    ProjectLV.ModifyCol(1, 320)
    ProjectLV.ModifyCol(2, 180)
    ProjectLV.ModifyCol(3, 380)
}

SortItemList(List) {
    Loop List.Length {
        i := A_Index
        Loop List.Length - i {
            j := A_Index
            if (List[j].Time < List[j+1].Time) {
                Temp := List[j]
                List[j] := List[j+1]
                List[j+1] := Temp
            }
        }
    }
}

OpenSelectedProject(LV, RowNumber) {
    if (RowNumber = 0)
        return
    ProjectPath := LV.GetText(RowNumber, 3)
    if FileExist(ProjectPath) {
        RunFLStudio(ProjectPath)
    }
}

TrackStatusAndTime() {
    global DailySeconds, TotalSeconds, ProjectSeconds, LastDetectedProject, CurrentDate
    static FlushCounter := 0

    TodayKey := A_YYYY "_" A_MM "_" A_DD
    if (TodayKey != CurrentDate) {
        CurrentDate := TodayKey
        DailySeconds := Number(IniRead(IniPath, "Stats", CurrentDate, 0))
    }

    IsRunning := ProcessExist("FL64.exe") || ProcessExist("FL.exe")

    if IsRunning {
        StatusDot.Value := "🟢"
        StatusText.Value := "Online"

        DailySeconds++
        TotalSeconds++

        WinTitle := ""
        if WinExist("ahk_exe FL64.exe")
            WinTitle := WinGetTitle("ahk_exe FL64.exe")
        else if WinExist("ahk_exe FL.exe")
            WinTitle := WinGetTitle("ahk_exe FL.exe")

        if (WinTitle != "") {
            if RegExMatch(WinTitle, "i)^(.+?)\s*-\s*FL Studio", &match) {
                CleanTitle := RegExReplace(match[1], "i)\.flp$", "")
            } else {
                CleanTitle := "FL Studio"
            }

            if (CleanTitle != "" && CleanTitle != "FL Studio" && CleanTitle != LastDetectedProject) {
                if (LastDetectedProject != "" && LastDetectedProject != "FL Studio") {
                    IniWrite(ProjectSeconds, IniPath, "ProjectStats", LastDetectedProject)
                }
                LastDetectedProject := CleanTitle
                ProjectSeconds := Number(IniRead(IniPath, "ProjectStats", CleanTitle, 0))
            }
        }

        if (LastDetectedProject != "" && LastDetectedProject != "FL Studio") {
            ProjectSeconds++
        }

        FlushCounter++
        if (FlushCounter >= 30) {
            SaveStatsToDisk()
            FlushCounter := 0
        }

    } else {
        if (LastDetectedProject != "") {
            SaveStatsToDisk()
            LastDetectedProject := ""
        }
        StatusDot.Value := "⚪"
        StatusText.Value := "Offline"
        ProjectSeconds := 0
    }

    DailyTimeLabel.Value := FormatSeconds(DailySeconds)
    ProjectTimeLabel.Value := FormatSeconds(ProjectSeconds)
    TotalTimeLabel.Value := FormatSeconds(TotalSeconds)
}

FormatSeconds(Sec) {
    Hours := Floor(Sec / 3600)
    Minutes := Floor(Mod(Sec, 3600) / 60)
    Seconds := Mod(Sec, 60)
    return Format("{:02d}:{:02d}:{:02d}", Hours, Minutes, Seconds)
}
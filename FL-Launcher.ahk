#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; STARTUP LOADING SCREEN
; ==============================================================================
LoadingGui := Gui("+ToolWindow -Caption +AlwaysOnTop", "Loading")
LoadingGui.BackColor := "0A0512"
LoadingGui.SetFont("s16 q5 Bold c80D8FF", "Segoe UI Variable Display")
LoadingGui.AddText("x30 y25 w240 h35 Center", "FL LAUNCHER")
LoadingGui.SetFont("s10 q5 c8A82A0", "Segoe UI Variable Text")
LoadingGui.AddText("x30 y60 w240 h25 Center", "Initializing environment...")
LoadingProg := LoadingGui.AddProgress("x30 y95 w240 h6 Background23153D c80D8FF Range0-100", 30)
LoadingGui.Show("w300 h130")

Sleep(300)
LoadingProg.Value := 70
Sleep(300)

global IniPath := A_ScriptDir "\launcher_config.ini"
global DefaultProjectsDir := A_MyDocuments "\Image-Line\FL Studio\Projects"
global ProjectsFolder := IniRead(IniPath, "Settings", "ProjectsFolder", DefaultProjectsDir)
global FLStudioPath := IniRead(IniPath, "Settings", "FLStudioPath", "C:\Program Files\Image-Line\FL Studio 2026\FL64.exe")

global CurrentDate := A_YYYY "_" A_MM "_" A_DD
global DailySeconds := Number(IniRead(IniPath, "Stats", CurrentDate, 0))
global TotalSeconds := Number(IniRead(IniPath, "Stats", "TotalSeconds", 0))
global ProjectSeconds := 0
global LastDetectedProject := ""
global CurrentProjectList := []
global CurrentSelectedFolderPath := ProjectsFolder

LoadingProg.Value := 100
Sleep(200)
LoadingGui.Destroy()

; --- COLOR PALETTE (WAERA DEEP OBSIDIAN PURPLE) ---
MainGui := Gui("+Resize", "FL Launcher")
MainGui.BackColor := "0A0512"

; ==============================================================================
; TOP HEADER & BANNER (BRANDING & STATS)
; ==============================================================================

MainGui.SetFont("s16 q5 Bold c80D8FF", "Segoe UI Variable Display")
MainGui.AddText("x25 y18 w220 h35", "FL LAUNCHER")

MainGui.SetFont("s11 q5 Bold cWhite", "Segoe UI Variable Text")
StatusDot := MainGui.AddText("x220 y20 w25 h30 Center", "🔴")
StatusText := MainGui.AddText("x248 y20 w130 h30", "Offline")

MainGui.SetFont("s9 q5 Bold c8A82A0", "Segoe UI Variable Text")
MainGui.AddText("x520 y12 w130 h18 Center", "DAILY TIME")
MainGui.SetFont("s12 q5 Bold cFF9800", "Segoe UI Variable Display")
DailyTimeLabel := MainGui.AddText("x520 y30 w130 h25 Center", "00:00:00")

MainGui.SetFont("s9 q5 Bold c8A82A0", "Segoe UI Variable Text")
MainGui.AddText("x660 y12 w130 h18 Center", "PROJECT TIME")
MainGui.SetFont("s12 q5 Bold c80D8FF", "Segoe UI Variable Display")
ProjectTimeLabel := MainGui.AddText("x660 y30 w130 h25 Center", "00:00:00")

MainGui.SetFont("s9 q5 Bold c8A82A0", "Segoe UI Variable Text")
MainGui.AddText("x800 y12 w130 h18 Center", "TOTAL TIME")
MainGui.SetFont("s12 q5 Bold cD1B3FF", "Segoe UI Variable Display")
TotalTimeLabel := MainGui.AddText("x800 y30 w130 h25 Center", "00:00:00")

; ==============================================================================
; ACTION TOOLBAR
; ==============================================================================
MainGui.SetFont("s10 q5 Bold cBlack", "Segoe UI Variable Text")

BtnLaunch  := MainGui.AddButton("x950 y15 w100 h40", "🚀 Launch")
BtnLaunch.OnEvent("Click", (*) => RunFLStudio())

BtnRefresh := MainGui.AddButton("x1060 y15 w85 h40", "🔄 Sync")
BtnRefresh.OnEvent("Click", (*) => RefreshAll())

MainGui.AddProgress("x25 y68 w1120 h2 Background23153D c23153D", 100)

; ==============================================================================
; SEARCH BAR & FILE ACTIONS
; ==============================================================================
MainGui.SetFont("s10 q5 Bold c80D8FF", "Segoe UI Variable Display")
MainGui.AddText("x25 y86 w260 h25", "FOLDERS")

MainGui.SetFont("s10 q5 Bold cE0E0E0", "Segoe UI Variable Text")
SearchEdit := MainGui.AddEdit("x310 y80 w460 h36 Background180F2B cE0E0E0 -Border", "")
SearchEdit.OnEvent("Change", (*) => DisplayProjects())
DllCall("SendMessage", "Ptr", SearchEdit.Hwnd, "UInt", 0x1501, "Ptr", 1, "Str", "🔍 Search project by name...")

MainGui.SetFont("s10 q5 Bold cBlack", "Segoe UI Variable Text")
BtnAdd    := MainGui.AddButton("x785 y80 w85 h36", "➕ Import")
BtnAdd.OnEvent("Click", (*) => AddExternalProject())

BtnMove   := MainGui.AddButton("x878 y80 w80 h36", "📦 Move")
BtnMove.OnEvent("Click", (*) => MoveSelectedItem())

BtnDelete := MainGui.AddButton("x966 y80 w85 h36", "🗑️ Delete")
BtnDelete.OnEvent("Click", (*) => DeleteSelectedItem())

BtnFolder := MainGui.AddButton("x1059 y80 w90 h36", "📂 Projects")
BtnFolder.OnEvent("Click", SelectProjectsFolder)

; ==============================================================================
; MAIN PANELS
; ==============================================================================
FolderTree := MainGui.AddTreeView("x25 y125 w260 h490 Background110A1F cE0E0E0 -Border")
FolderTree.OnEvent("ItemSelect", OnFolderSelect)
FolderTree.OnEvent("ContextMenu", ShowFolderContextMenu)

ProjectLV := MainGui.AddListView("x310 y125 w835 h490 -Multi Background110A1F cE0E0E0 -Border", ["Project Name", "Last Modified", "Path"])
ProjectLV.OnEvent("DoubleClick", OpenSelectedProject)
ProjectLV.OnEvent("ContextMenu", ShowLVContextMenu)

PopulateFolderTree()
SetTimer(TrackStatusAndTime, 1000)

MainGui.Show("w1170 h640")

; ==============================================================================
; CONTEXT MENUS & ZIPPING LOGIC WITH LOADING SCREEN
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
    TargetFolder := DirSelect("*" ProjectsFolder, 3, "Select where to save the ZIP file for folder: " FolderName)
    if !TargetFolder
        return

    DestZip := TargetFolder "\" FolderName ".zip"
    if FileExist(DestZip) {
        if (MsgBox("A ZIP file with this name already exists in the destination. Overwrite?", "File Exists", 4) != "Yes")
            return
        FileDelete(DestZip)
    }

    ; --- ZIPPING LOADING SCREEN ---
    ZipGui := Gui("+ToolWindow -Caption +AlwaysOnTop", "Compressing")
    ZipGui.BackColor := "0A0512"
    ZipGui.SetFont("s11 q5 Bold c80D8FF", "Segoe UI Variable Display")
    ZipGui.AddText("x20 y20 w260 h25 Center", "📦 Zipping folder...")
    ZipGui.SetFont("s9 q5 c8A82A0", "Segoe UI Variable Text")
    ZipGui.AddText("x20 y50 w260 h20 Center", "Please wait, compressing...")
    ZipGui.AddProgress("x20 y80 w260 h8 Background23153D c80D8FF")
    ZipGui.Show("w300 h110")

    try {
        RunWait('powershell -NoProfile -Command "Compress-Archive -Path \`"' FolderPath '\`" -DestinationPath \`"' DestZip '\`" -Force"', , "Hide")
        ZipGui.Destroy()
        MsgBox("Folder successfully zipped to:`n" DestZip, "Completed", "Iconi")
    } catch {
        ZipGui.Destroy()
        MsgBox("Error creating the ZIP file.", "Error", "Icon!")
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

    TargetFolder := DirSelect("*" ProjectsFolder, 3, "Select where to save the ZIP file for project: " ProjName)
    if !TargetFolder
        return

    SplitPath(ProjName, &NoExtName)
    DestZip := TargetFolder "\" NoExtName ".zip"

    if FileExist(DestZip) {
        if (MsgBox("A ZIP file with this name already exists in the destination. Overwrite?", "File Exists", 4) != "Yes")
            return
        FileDelete(DestZip)
    }

    ; --- ZIPPING LOADING SCREEN ---
    ZipGui := Gui("+ToolWindow -Caption +AlwaysOnTop", "Compressing")
    ZipGui.BackColor := "0A0512"
    ZipGui.SetFont("s11 q5 Bold c80D8FF", "Segoe UI Variable Display")
    ZipGui.AddText("x20 y20 w260 h25 Center", "📦 Zipping project...")
    ZipGui.SetFont("s9 q5 c8A82A0", "Segoe UI Variable Text")
    ZipGui.AddText("x20 y50 w260 h20 Center", "Please wait, compressing...")
    ZipGui.AddProgress("x20 y80 w260 h8 Background23153D c80D8FF")
    ZipGui.Show("w300 h110")

    try {
        RunWait('powershell -NoProfile -Command "Compress-Archive -Path \`"' ProjectPath '\`" -DestinationPath \`"' DestZip '\`" -Force"', , "Hide")
        ZipGui.Destroy()
        MsgBox("Project successfully zipped to:`n" DestZip, "Completed", "Iconi")
    } catch {
        ZipGui.Destroy()
        MsgBox("Error creating the ZIP file.", "Error", "Icon!")
    }
}

ShowProjectDetails(LV, RowNumber) {
    ProjectPath := LV.GetText(RowNumber, 3)
    ProjName := LV.GetText(RowNumber, 1)

    if !FileExist(ProjectPath)
        return

    FileModTime := FileGetTime(ProjectPath, "M")
    FormattedModTime := FormatTime(FileModTime, "yyyy/MM/dd, HH:mm")

    SavedProjectSeconds := Number(IniRead(IniPath, "ProjectStats", ProjName, 0))
    FormattedProjectTime := FormatSecondsLong(SavedProjectSeconds)

    DetailsGui := Gui("+Owner" MainGui.Hwnd " +ToolWindow", "Project Details — " ProjName)
    DetailsGui.BackColor := "0A0512"

    BtnBack := DetailsGui.AddButton("x20 y20 w90 h32", "⬅️ Back")
    BtnBack.OnEvent("Click", (*) => DetailsGui.Destroy())

    DetailsGui.SetFont("s14 q5 Bold c80D8FF", "Segoe UI Variable Display")
    DetailsGui.AddText("x125 y22 w320 h35", ProjName)

    BtnOpen := DetailsGui.AddButton("x465 y20 w80 h32", "Open")
    BtnOpen.OnEvent("Click", (*) => (DetailsGui.Destroy(), RunFLStudio(ProjectPath)))

    ; --- DETAILS SECTION ---
    DetailsGui.SetFont("s10 q5 Bold cD1B3FF", "Segoe UI Variable Text")
    DetailsGui.AddText("x20 y70 w525 h22", "Details")

    SavedDetails := IniRead(IniPath, "CustomDetails", ProjName, "")
    
    BpmText := "BPM: N/A"
    PluginsText := "Plugins: N/A"
    SamplesText := "Samples: N/A"
    TrackLenText := "Track Length: N/A"

    if (SavedDetails != "") {
        Loop Parse, SavedDetails, "`n", "`r" {
            line := Trim(A_LoopField)
            if RegExMatch(line, "i)^BPM:")
                BpmText := line
            else if RegExMatch(line, "i)^Plugins:")
                PluginsText := line
            else if RegExMatch(line, "i)^Samples:")
                SamplesText := line
            else if RegExMatch(line, "i)^Track Length:")
                TrackLenText := line
        }
    }

    DetailsText := BpmText "`n" 
                 . PluginsText "`n" 
                 . SamplesText "`n" 
                 . TrackLenText "`n" 
                 . "Project Time: " FormattedProjectTime "`n" 
                 . "Last Modified: " FormattedModTime

    DetailsGui.SetFont("s9 q5 cE0E0E0", "Segoe UI Variable Text")
    DetailsEdit := DetailsGui.AddEdit("x20 y95 w525 h210 Background110A1F -Border", DetailsText)
    
    DetailsEdit.OnEvent("Change", (Ctrl, *) => IniWrite(Ctrl.Value, IniPath, "CustomDetails", ProjName))

    DetailsGui.Show("w565 h330")
}

FormatSecondsLong(Sec) {
    Hours := Floor(Sec / 3600)
    Minutes := Floor(Mod(Sec, 3600) / 60)
    Seconds := Mod(Sec, 60)
    return Hours " Hours, " Minutes " Minutes, " Seconds " Seconds"
}

; ==============================================================================
; GENERAL LOGIC & TIME TRACKING
; ==============================================================================

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
        global ProjectsFolder := SelectedFolder
        global CurrentSelectedFolderPath := SelectedFolder
        IniWrite(ProjectsFolder, IniPath, "Settings", "ProjectsFolder")
        PopulateFolderTree()
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
        if (MsgBox("A file with this name already exists in the selected folder. Overwrite?", "File Exists", 4) != "Yes")
            return
    }

    FileCopy(SelectedFile, DestPath, 1)
    LoadProjectsFromFolder(TargetFolder)
}

MoveSelectedItem() {
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
        SelectedID := FolderTree.GetSelection()
        if SelectedID {
            FolderPath := GetFullPath(SelectedID)
            if (FolderPath == ProjectsFolder) {
                MsgBox("Cannot move the main Root folder.", "Action Blocked", "Icon!")
                return
            }
            
            SplitPath(FolderPath, &FolderName)
            TargetFolder := DirSelect("*" ProjectsFolder, 3, "Move folder " FolderName " to:")
            if !TargetFolder
                return
            
            DestPath := TargetFolder "\" FolderName
            DirMove(FolderPath, DestPath, "R")
            PopulateFolderTree()
        } else {
            MsgBox("Please select a project or folder to move first.", "No Selection", "Icon!")
        }
    }
}

DeleteSelectedItem() {
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
        SelectedID := FolderTree.GetSelection()
        if SelectedID {
            FolderPath := GetFullPath(SelectedID)
            if (FolderPath == ProjectsFolder) {
                MsgBox("Cannot delete the main Root folder.", "Action Blocked", "Icon!")
                return
            }
            
            SplitPath(FolderPath, &FolderName)
            if (MsgBox("Permanently delete this folder and all its contents?`n`n" FolderName, "Confirm Deletion", 4) == "Yes") {
                DirDelete(FolderPath, 1)
                PopulateFolderTree()
            }
        } else {
            MsgBox("Please select an item to delete.", "No Selection", "Icon!")
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
    
    ProjectLV.ModifyCol(1, 300)
    ProjectLV.ModifyCol(2, 170)
    ProjectLV.ModifyCol(3, 360)
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

    ; Controllo a mezzanotte se la data è cambiata
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
        ProjectSeconds++

        IniWrite(DailySeconds, IniPath, "Stats", CurrentDate)
        IniWrite(TotalSeconds, IniPath, "Stats", "TotalSeconds")

        WinTitle := ""
        if WinExist("ahk_exe FL64.exe")
            WinTitle := WinGetTitle("ahk_exe FL64.exe")
        else if WinExist("ahk_exe FL.exe")
            WinTitle := WinGetTitle("ahk_exe FL.exe")

        if (WinTitle != "") {
            CleanTitle := RegExReplace(WinTitle, "i)\s*-\s*FL Studio.*$", "")
            if (CleanTitle != LastDetectedProject) {
                LastDetectedProject := CleanTitle
                ProjectSeconds := Number(IniRead(IniPath, "ProjectStats", CleanTitle, 0))
            }
            IniWrite(ProjectSeconds, IniPath, "ProjectStats", CleanTitle)
        }
    } else {
        StatusDot.Value := "🔴"
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
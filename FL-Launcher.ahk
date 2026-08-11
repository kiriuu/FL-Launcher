#Requires AutoHotkey v2.0
#SingleInstance Force

global IniPath := A_ScriptDir "\launcher_config.ini"
global DefaultProjectsDir := A_MyDocuments "\Image-Line\FL Studio\Projects"
global ProjectsFolder := IniRead(IniPath, "Settings", "ProjectsFolder", DefaultProjectsDir)
global FLStudioPath := IniRead(IniPath, "Settings", "FLStudioPath", "C:\Program Files\Image-Line\FL Studio 2026\FL64.exe")

global DailySeconds := Number(IniRead(IniPath, "Stats", A_YYYY "_" A_MM "_" A_DD, 0))
global ProjectSeconds := 0
global LastDetectedProject := ""
global CurrentProjectList := []
global CurrentSelectedFolderPath := ProjectsFolder

MainGui := Gui("+Resize", "FL Launcher")
MainGui.BackColor := "141414" 

; --- HEADER: STATUS & TIMERS ---
MainGui.SetFont("s12 q5 cWhite", "Segoe UI")
StatusDot := MainGui.AddText("x20 y20 w25 h25 Center", "🔴")
StatusText := MainGui.AddText("x50 y20 w160 h25", "FL Studio: Offline")
StatusText.SetFont("Bold")

MainGui.SetFont("s11 q5 cFF9800", "Segoe UI Semibold")
DailyTimeLabel := MainGui.AddText("x220 y20 w170 h25", "Daily: 00:00:00")

MainGui.SetFont("s11 q5 c00E5FF", "Segoe UI Semibold")
ProjectTimeLabel := MainGui.AddText("x390 y20 w170 h25", "Project: 00:00:00")

; --- HEADER: ACTION BUTTONS ---
MainGui.SetFont("s9 q5 cBlack", "Segoe UI Semibold")
BtnRefresh := MainGui.AddButton("x570 y15 w80 h34", "🔄 Refresh")
BtnRefresh.OnEvent("Click", (*) => RefreshAll())

BtnLaunch := MainGui.AddButton("x655 y15 w85 h34", "🚀 Launch")
BtnLaunch.OnEvent("Click", (*) => RunFLStudio())

BtnAdd := MainGui.AddButton("x745 y15 w80 h34", "➕ Add")
BtnAdd.OnEvent("Click", (*) => AddExternalProject())

BtnMove := MainGui.AddButton("x830 y15 w80 h34", "📦 Move")
BtnMove.OnEvent("Click", (*) => MoveSelectedItem())

BtnDelete := MainGui.AddButton("x915 y15 w80 h34", "🗑️ Delete")
BtnDelete.OnEvent("Click", (*) => DeleteSelectedItem())

BtnFolder := MainGui.AddButton("x1000 y15 w85 h34", "📂 Folder")
BtnFolder.OnEvent("Click", SelectProjectsFolder)

; --- MAIN CONTENT HEADERS ---
MainGui.SetFont("s12 q5 cFF8C00", "Segoe UI Bold")
MainGui.AddText("x20 y68 w240 h25", "📁 FOLDERS")

MainGui.SetFont("s12 q5 cFF8C00", "Segoe UI Bold")
MainGui.AddText("x280 y68 w100 h25", "🎵 PROJECTS")

; --- SEARCH BAR WITH PLACEHOLDER ---
MainGui.SetFont("s10 q5 cE0E0E0", "Segoe UI")
SearchEdit := MainGui.AddEdit("x390 y65 w695 h30 Background222222 cE0E0E0", "")
SearchEdit.OnEvent("Change", (*) => DisplayProjects())

; Placeholder per la barra di ricerca
DllCall("SendMessage", "Ptr", SearchEdit.Hwnd, "UInt", 0x1501, "Ptr", 1, "Str", "🔍 Search projects...")

; --- MAIN VIEWS ---
FolderTree := MainGui.AddTreeView("x20 y100 w240 h490 Background222222 cE0E0E0")
FolderTree.OnEvent("ItemSelect", OnFolderSelect)

ProjectLV := MainGui.AddListView("x280 y100 w805 h490 -Multi Background222222 cE0E0E0", ["Project Name", "Last Modified", "Path"])
ProjectLV.OnEvent("DoubleClick", OpenSelectedProject)

PopulateFolderTree()
SetTimer(TrackStatusAndTime, 1000)

MainGui.Show("w1105 h610")

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
    SelectedFolder := DirSelect("*" ProjectsFolder, 3, "Select your FL Studio Projects Folder")
    if SelectedFolder {
        global ProjectsFolder := SelectedFolder
        global CurrentSelectedFolderPath := SelectedFolder
        IniWrite(ProjectsFolder, IniPath, "Settings", "ProjectsFolder")
        PopulateFolderTree()
    }
}

AddExternalProject() {
    SelectedFile := FileSelect(1, , "Select FLP file to add", "FL Studio Projects (*.flp)")
    if !SelectedFile
        return
    
    SplitPath(SelectedFile, &FileName)
    TargetFolder := CurrentSelectedFolderPath != "" ? CurrentSelectedFolderPath : ProjectsFolder
    
    if !DirExist(TargetFolder)
        TargetFolder := ProjectsFolder

    DestPath := TargetFolder "\" FileName
    
    if FileExist(DestPath) {
        MsgResult := MsgBox("A file with this name already exists in the selected folder. Overwrite it?", "File Exists", 4)
        if (MsgResult != "Yes")
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
            TargetFolder := DirSelect("*" ProjectsFolder, 3, "Select target folder for: " ProjName)
            if !TargetFolder
                return
            
            DestPath := TargetFolder "\" ProjName
            if FileExist(DestPath) {
                if (MsgBox("A file with this name already exists in target folder. Overwrite?", "File Exists", 4) != "Yes")
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
                MsgBox("You cannot move the root Projects folder.", "Action Blocked", "Icon!")
                return
            }
            
            SplitPath(FolderPath, &FolderName)
            TargetFolder := DirSelect("*" ProjectsFolder, 3, "Select destination folder for: " FolderName)
            if !TargetFolder
                return
            
            DestPath := TargetFolder "\" FolderName
            DirMove(FolderPath, DestPath, "R")
            PopulateFolderTree()
        } else {
            MsgBox("Please select a project or folder to move.", "Nothing Selected", "Icon!")
        }
    }
}

DeleteSelectedItem() {
    Row := ProjectLV.GetNext()
    if (Row > 0) {
        ProjectPath := ProjectLV.GetText(Row, 3)
        ProjName := ProjectLV.GetText(Row, 1)
        
        if (ProjectPath != "" && FileExist(ProjectPath)) {
            if (MsgBox("Are you sure you want to move this project to the Recycle Bin?`n`n" ProjName, "Confirm Delete", 4) == "Yes") {
                FileRecycle(ProjectPath)
                LoadProjectsFromFolder(CurrentSelectedFolderPath)
            }
        }
    } else {
        SelectedID := FolderTree.GetSelection()
        if SelectedID {
            FolderPath := GetFullPath(SelectedID)
            if (FolderPath == ProjectsFolder) {
                MsgBox("You cannot delete the root Projects folder.", "Action Blocked", "Icon!")
                return
            }
            
            SplitPath(FolderPath, &FolderName)
            if (MsgBox("Are you sure you want to delete this folder and all its contents?`n`n" FolderName, "Confirm Folder Delete", 4) == "Yes") {
                DirDelete(FolderPath, 1)
                PopulateFolderTree()
            }
        } else {
            MsgBox("Please select a project or folder to delete.", "Nothing Selected", "Icon!")
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
        FormattedDate := FormatTime(proj.Time, "yyyy-MM-dd HH:mm:ss")
        ProjectLV.Add(, proj.Name, FormattedDate, proj.Path)
    }
    
    ProjectLV.ModifyCol(1, 280)
    ProjectLV.ModifyCol(2, 150)
    ProjectLV.ModifyCol(3, 350)
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
    global DailySeconds, ProjectSeconds, LastDetectedProject

    IsRunning := ProcessExist("FL64.exe") || ProcessExist("FL.exe")

    if IsRunning {
        StatusDot.Value := "🟢"
        StatusText.Value := "FL Studio: Online"

        DailySeconds++
        ProjectSeconds++

        IniWrite(DailySeconds, IniPath, "Stats", A_YYYY "_" A_MM "_" A_DD)

        WinTitle := ""
        if WinExist("ahk_exe FL64.exe")
            WinTitle := WinGetTitle("ahk_exe FL64.exe")
        else if WinExist("ahk_exe FL.exe")
            WinTitle := WinGetTitle("ahk_exe FL.exe")

        if (WinTitle != "" && WinTitle != LastDetectedProject) {
            LastDetectedProject := WinTitle
            ProjectSeconds := 0
        }
    } else {
        StatusDot.Value := "🔴"
        StatusText.Value := "FL Studio: Offline"
        ProjectSeconds := 0
    }

    DailyTimeLabel.Value := "Daily: " FormatSeconds(DailySeconds)
    ProjectTimeLabel.Value := "Project: " FormatSeconds(ProjectSeconds)
}

FormatSeconds(Sec) {
    Hours := Floor(Sec / 3600)
    Minutes := Floor(Mod(Sec, 3600) / 60)
    Seconds := Mod(Sec, 60)
    return Format("{:02d}:{:02d}:{:02d}", Hours, Minutes, Seconds)
}
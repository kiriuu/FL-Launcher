#Requires AutoHotkey v2.0
#SingleInstance Force

global IniPath := A_ScriptDir "\launcher_config.ini"
global DefaultProjectsDir := A_MyDocuments "\Image-Line\FL Studio\Projects"
global ProjectsFolder := IniRead(IniPath, "Settings", "ProjectsFolder", DefaultProjectsDir)
global FLStudioPath := IniRead(IniPath, "Settings", "FLStudioPath", "C:\Program Files\Image-Line\FL Studio 2026\FL64.exe")

global DailySeconds := Number(IniRead(IniPath, "Stats", A_YYYY "_" A_MM "_" A_DD, 0))
global TotalSeconds := Number(IniRead(IniPath, "Stats", "TotalSeconds", 0))
global ProjectSeconds := 0
global LastDetectedProject := ""
global CurrentProjectList := []
global CurrentSelectedFolderPath := ProjectsFolder

; --- PALETTE COLORI (WAERA DEEP OBSIDIAN PURPLE) ---
; Background Principale: #0A0512 | Card/Pannelli: #110A1F | Input/List: #180F2B | Accento Light Blue: #80D8FF

MainGui := Gui("+Resize", "FL Launcher")
MainGui.BackColor := "0A0512"

; ==============================================================================
; TOP HEADER & BANNER (BRANDING & STATS)
; ==============================================================================

; App Title
MainGui.SetFont("s16 q5 Bold c80D8FF", "Segoe UI Variable Display")
MainGui.AddText("x25 y18 w220 h35", "FL LAUNCHER")

; Status Badge
MainGui.SetFont("s11 q5 Bold cWhite", "Segoe UI Variable Text")
StatusDot := MainGui.AddText("x220 y20 w25 h30 Center", "🔴")
StatusText := MainGui.AddText("x248 y20 w130 h30", "Offline")

; Stat Cards (Daily / Project / Total)
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
; TOOLBAR AZIONI (ACCESSO RAPIDO)
; ==============================================================================
MainGui.SetFont("s10 q5 Bold cBlack", "Segoe UI Variable Text")

BtnLaunch  := MainGui.AddButton("x950 y15 w100 h40", "🚀 Launch")
BtnLaunch.OnEvent("Click", (*) => RunFLStudio())

BtnRefresh := MainGui.AddButton("x1060 y15 w85 h40", "🔄 Sync")
BtnRefresh.OnEvent("Click", (*) => RefreshAll())

; Barra separatrice
MainGui.AddProgress("x25 y68 w1120 h2 Background23153D c23153D", 100)

; ==============================================================================
; BARRA DI RICERCA ED AZIONI FILE
; ==============================================================================
MainGui.SetFont("s10 q5 Bold c80D8FF", "Segoe UI Variable Display")
MainGui.AddText("x25 y86 w260 h25", "FOLDERS")

MainGui.SetFont("s10 q5 Bold cE0E0E0", "Segoe UI Variable Text")
SearchEdit := MainGui.AddEdit("x310 y80 w460 h36 Background180F2B cE0E0E0 -Border", "")
SearchEdit.OnEvent("Change", (*) => DisplayProjects())
DllCall("SendMessage", "Ptr", SearchEdit.Hwnd, "UInt", 0x1501, "Ptr", 1, "Str", "🔍 Cerca progetto per nome...")

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
; MAIN CONTENT PANELS (SIDEBAR & PROJECT LIST)
; ==============================================================================

; Sidebar: Navigation Tree
FolderTree := MainGui.AddTreeView("x25 y125 w260 h490 Background110A1F cE0E0E0 -Border")
FolderTree.OnEvent("ItemSelect", OnFolderSelect)

; Main Area: Projects ListView
ProjectLV := MainGui.AddListView("x310 y125 w835 h490 -Multi Background110A1F cE0E0E0 -Border", ["Project Name", "Last Modified", "Path"])
ProjectLV.OnEvent("DoubleClick", OpenSelectedProject)

; Inizializzazione dati e Timer
PopulateFolderTree()
SetTimer(TrackStatusAndTime, 1000)

MainGui.Show("w1170 h640")

; ==============================================================================
; FUNZIONI E LOGICA
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
    SelectedFolder := DirSelect("*" ProjectsFolder, 3, "Seleziona la cartella radice dei progetti FL Studio")
    if SelectedFolder {
        global ProjectsFolder := SelectedFolder
        global CurrentSelectedFolderPath := SelectedFolder
        IniWrite(ProjectsFolder, IniPath, "Settings", "ProjectsFolder")
        PopulateFolderTree()
    }
}

AddExternalProject() {
    SelectedFile := FileSelect(1, , "Seleziona file .flp da importare", "FL Studio Projects (*.flp)")
    if !SelectedFile
        return
    
    SplitPath(SelectedFile, &FileName)
    TargetFolder := CurrentSelectedFolderPath != "" ? CurrentSelectedFolderPath : ProjectsFolder
    
    if !DirExist(TargetFolder)
        TargetFolder := ProjectsFolder

    DestPath := TargetFolder "\" FileName
    
    if FileExist(DestPath) {
        if (MsgBox("Un file con questo nome esiste già nella cartella selezionata. Sovrascrivere?", "File Esistente", 4) != "Yes")
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
            TargetFolder := DirSelect("*" ProjectsFolder, 3, "Spostamento di: " ProjName)
            if !TargetFolder
                return
            
            DestPath := TargetFolder "\" ProjName
            if FileExist(DestPath) {
                if (MsgBox("File già presente nella destinazione. Sovrascrivere?", "Attenzione", 4) != "Yes")
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
                MsgBox("Impossibile spostare la cartella Root principale.", "Azione Bloccata", "Icon!")
                return
            }
            
            SplitPath(FolderPath, &FolderName)
            TargetFolder := DirSelect("*" ProjectsFolder, 3, "Sposta cartella " FolderName " in:")
            if !TargetFolder
                return
            
            DestPath := TargetFolder "\" FolderName
            DirMove(FolderPath, DestPath, "R")
            PopulateFolderTree()
        } else {
            MsgBox("Seleziona prima un progetto o una cartella da spostare.", "Nessuna Selezione", "Icon!")
        }
    }
}

DeleteSelectedItem() {
    Row := ProjectLV.GetNext()
    if (Row > 0) {
        ProjectPath := ProjectLV.GetText(Row, 3)
        ProjName := ProjectLV.GetText(Row, 1)
        
        if (ProjectPath != "" && FileExist(ProjectPath)) {
            if (MsgBox("Spostare questo progetto nel Cestino?`n`n" ProjName, "Conferma Eliminazione", 4) == "Yes") {
                FileRecycle(ProjectPath)
                LoadProjectsFromFolder(CurrentSelectedFolderPath)
            }
        }
    } else {
        SelectedID := FolderTree.GetSelection()
        if SelectedID {
            FolderPath := GetFullPath(SelectedID)
            if (FolderPath == ProjectsFolder) {
                MsgBox("Impossibile eliminare la cartella Root principale.", "Azione Bloccata", "Icon!")
                return
            }
            
            SplitPath(FolderPath, &FolderName)
            if (MsgBox("Eliminare definitivamente questa cartella e tutto il suo contenuto?`n`n" FolderName, "Conferma Eliminazione", 4) == "Yes") {
                DirDelete(FolderPath, 1)
                PopulateFolderTree()
            }
        } else {
            MsgBox("Seleziona un elemento da eliminare.", "Nessuna Selezione", "Icon!")
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
    global DailySeconds, TotalSeconds, ProjectSeconds, LastDetectedProject

    IsRunning := ProcessExist("FL64.exe") || ProcessExist("FL.exe")

    if IsRunning {
        StatusDot.Value := "🟢"
        StatusText.Value := "Online"

        DailySeconds++
        TotalSeconds++
        ProjectSeconds++

        IniWrite(DailySeconds, IniPath, "Stats", A_YYYY "_" A_MM "_" A_DD)
        IniWrite(TotalSeconds, IniPath, "Stats", "TotalSeconds")

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
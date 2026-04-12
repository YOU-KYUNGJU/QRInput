AcquireRunLock(sysCfg) {
    if !IsTrue(sysCfg.use_lock_file)
        return

    lockPath := sysCfg.lock_file_path
    if FileExist(lockPath) {
        if IsStaleLockFile(lockPath) {
            FileDelete, % lockPath
            Sleep, 100
        }
    }

    if FileExist(lockPath) {
        MsgBox, 48, QRinput, 이미 실행 중입니다.
        ExitApp
    }

    SplitPath, lockPath, , lockDir
    EnsureDir(lockDir)
    lockContent := "pid=" A_Pid "`r`n"
    lockContent .= "started_at=" A_Now "`r`n"
    lockContent .= "script_dir=" A_ScriptDir "`r`n"
    FileAppend, %lockContent%, %lockPath%, UTF-8
}

ReleaseRunLock(sysCfg) {
    if (IsTrue(sysCfg.use_lock_file) && FileExist(sysCfg.lock_file_path))
        FileDelete, % sysCfg.lock_file_path
}

IsStaleLockFile(lockPath) {
    lockInfo := ReadLockFile(lockPath)
    pid := lockInfo.HasKey("pid") ? Trim(lockInfo.pid) : ""

    if (pid = "" || !RegExMatch(pid, "^\d+$"))
        return true

    Process, Exist, % pid
    return (ErrorLevel = 0)
}

ReadLockFile(lockPath) {
    info := {}
    if !FileExist(lockPath)
        return info

    file := FileOpen(lockPath, "r", "UTF-8")
    if !IsObject(file)
        return info

    content := file.Read()
    file.Close()

    Loop, Parse, content, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        delimiterPos := InStr(line, "=")
        if (delimiterPos <= 0)
            continue
        key := Trim(SubStr(line, 1, delimiterPos - 1))
        value := Trim(SubStr(line, delimiterPos + 1))
        info[key] := value
    }

    return info
}

CreateRunId() {
    return NowFileStamp()
}

CollectCsvFiles(teamCfg) {
    files := []
    targetDir := ResolveTargetCsvDirectory(teamCfg)
    if (targetDir = "" || !DirExists(targetDir))
        return files

    Loop, Files, % targetDir "\*.csv", F
    {
        if ShouldIncludeCsvFile(A_LoopFileFullPath, teamCfg)
            files.Push(A_LoopFileFullPath)
    }
    return files
}

ResolveTargetCsvDirectory(teamCfg) {
    root := teamCfg.csv_root_path
    if (root = "" || !DirExists(root))
        return ""

    if HasDirectCsvFiles(root)
        return root

    FormatTime, today,, yyyyMMdd
    year := SubStr(today, 1, 4)
    month := SubStr(today, 5, 2)

    directToday := root "\" today
    if DirExists(directToday)
        return directToday

    nestedToday := root "\" year "\" month "\" today
    if DirExists(nestedToday)
        return nestedToday

    foundToday := FindDateFolderRecursive(root, today)
    if (foundToday != "")
        return foundToday

    return root
}

HasDirectCsvFiles(dirPath) {
    Loop, Files, % dirPath "\*.csv", F
        return true
    return false
}

FindDateFolderRecursive(rootDir, dateFolderName) {
    bestPath := ""
    Loop, Files, % rootDir "\*", DR
    {
        if (A_LoopFileName != dateFolderName)
            continue

        if (bestPath = "" || StrLen(A_LoopFileFullPath) < StrLen(bestPath))
            bestPath := A_LoopFileFullPath
    }
    return bestPath
}

ShouldIncludeCsvFile(csvPath, teamCfg) {
    policy := teamCfg.file_select_policy
    if (policy = "created_after_hour") {
        cutoffHour := ToInt(teamCfg.cutoff_hour, 0)
        createdAfterHour := ToInt(teamCfg.file_created_after_hour, -1)

        FormatTime, currentHour,, HH
        if (createdAfterHour >= 0 && currentHour + 0 < cutoffHour) {
            FileGetTime, createdTime, %csvPath%, C
            FormatTime, createdHour, %createdTime%, HH
            return (createdHour + 0 >= createdAfterHour)
        }
    }
    return true
}

LoadCsvRows(csvPath) {
    FileRead, raw, %csvPath%
    return ParseCsvText(raw)
}

ParseCsvText(raw) {
    rows := []
    row := []
    field := ""
    inQuotes := false
    rawLen := StrLen(raw)
    rowIndex := 0
    i := 1

    while (i <= rawLen) {
        ch := SubStr(raw, i, 1)
        nextCh := (i < rawLen) ? SubStr(raw, i + 1, 1) : ""

        if (ch = """") {
            if (inQuotes && nextCh = """") {
                field .= """"
                i += 2
                continue
            }
            inQuotes := !inQuotes
            i++
            continue
        }

        if (!inQuotes && ch = ",") {
            row.Push(field)
            field := ""
            i++
            continue
        }

        if (!inQuotes && (ch = "`r" || ch = "`n")) {
            row.Push(field)
            if !IsCsvRowBlank(row) {
                rowIndex++
                rows.Push(BuildCsvRowObject(row, rowIndex))
            }
            row := []
            field := ""
            if (ch = "`r" && nextCh = "`n")
                i += 2
            else
                i++
            continue
        }

        field .= ch
        i++
    }

    if (field != "" || row.Length() > 0) {
        row.Push(field)
        if !IsCsvRowBlank(row) {
            rowIndex++
            rows.Push(BuildCsvRowObject(row, rowIndex))
        }
    }

    return rows
}

IsCsvRowBlank(fields) {
    for _, value in fields {
        if (Trim(value) != "")
            return false
    }
    return true
}

BuildCsvRowObject(fields, rowNo) {
    rowObj := {_row_no: rowNo, _values: []}

    for index, value in fields {
        if (rowNo = 1 && index = 1 && Asc(SubStr(value, 1, 1)) = 65279)
            value := SubStr(value, 2)

        colName := ColumnNameByIndex(index)
        rowObj[colName] := value
        rowObj._values.Push(value)
    }

    return rowObj
}

ColumnNameByIndex(index) {
    name := ""
    while (index > 0) {
        modValue := Mod(index - 1, 26)
        name := Chr(65 + modValue) . name
        index := Floor((index - 1) / 26)
    }
    return name
}

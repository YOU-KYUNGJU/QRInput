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

CollectCsvFiles(teamCfg, ByRef targetDir := "") {
    files := []
    targetEntries := ResolveTargetCsvDirectories(teamCfg)
    targetDir := BuildTargetDirDebugText(targetEntries)
    if (targetEntries.Length() = 0)
        return files

    seen := {}
    for _, targetEntry in targetEntries {
        dirPath := IsObject(targetEntry) ? targetEntry.path : targetEntry
        if (dirPath = "" || !DirExists(dirPath))
            continue

        Loop, Files, % dirPath "\*.csv", F
        {
            csvPath := A_LoopFileFullPath
            if !ShouldIncludeCsvFile(csvPath, teamCfg, targetEntry)
                continue

            key := ToLower(csvPath)
            if seen.HasKey(key)
                continue

            seen[key] := true
            files.Push(csvPath)
        }
    }
    return files
}

ResolveTargetCsvDirectories(teamCfg) {
    dirs := []
    recentCount := ToInt(teamCfg.recent_date_folder_count, 1)
    if (recentCount > 1) {
        dirs := WrapTargetDirectoryPaths(FindRecentDateFolders(teamCfg.csv_root_path, recentCount), "recent_date_folder")
        if (dirs.Length() > 0)
            return dirs
    }

    todayDir := ResolveTodayCsvDirectory(teamCfg.csv_root_path)
    singleDir := ResolveTargetCsvDirectory(teamCfg)
    if (singleDir != "")
        dirs.Push({path: singleDir, role: "primary_target"})

    if (ShouldIncludeTodayFolderAfterCutoff(teamCfg, singleDir, todayDir))
        dirs.Push({path: todayDir, role: "today_created_after_cutoff"})

    return dirs
}

ResolveTargetCsvDirectory(teamCfg) {
    root := teamCfg.csv_root_path
    if (root = "" || !DirExists(root))
        return ""

    FormatTime, today,, yyyyMMdd
    foundToday := ResolveTodayCsvDirectory(root, today)

    if IsFutureFolderWindowActive(teamCfg) {
        futureDir := ResolveFutureTargetCsvDirectory(root, today, teamCfg)
        if (futureDir != "")
            return futureDir
    }

    if (foundToday != "")
        return foundToday

    if HasDirectCsvFiles(root)
        return root

    return root
}

ResolveTodayCsvDirectory(rootDir, todayYmd := "") {
    if (rootDir = "" || !DirExists(rootDir))
        return ""

    if (todayYmd = "")
        FormatTime, todayYmd,, yyyyMMdd

    year := SubStr(todayYmd, 1, 4)
    month := SubStr(todayYmd, 5, 2)
    directToday := rootDir "\" todayYmd
    nestedToday := rootDir "\" year "\" month "\" todayYmd

    if DirExists(directToday)
        return directToday
    if DirExists(nestedToday)
        return nestedToday
    return FindDateFolderRecursive(rootDir, todayYmd)
}

IsFutureFolderWindowActive(teamCfg) {
    if !IsTrue(teamCfg.allow_future_folder)
        return false

    cutoffHour := ToInt(teamCfg.cutoff_hour, -1)
    if (cutoffHour < 0)
        return false

    FormatTime, currentHour,, HH
    return (currentHour + 0 >= cutoffHour)
}

ShouldIncludeTodayFolderAfterCutoff(teamCfg, primaryDir, todayDir) {
    if !IsTrue(teamCfg.include_today_folder_after_cutoff)
        return false
    if !IsFutureFolderWindowActive(teamCfg)
        return false
    if (todayDir = "" || !DirExists(todayDir))
        return false
    if (primaryDir = "")
        return true
    return (ToLower(primaryDir) != ToLower(todayDir))
}

ResolveFutureTargetCsvDirectory(rootDir, todayYmd, teamCfg) {
    mode := ToLower(Trim(teamCfg.future_folder_mode))
    if (mode = "next_business_day") {
        futureDir := FindNextBusinessDayFolder(rootDir, todayYmd)
        if (futureDir != "")
            return futureDir
    }

    return FindNearestFutureDateFolder(rootDir, todayYmd)
}

BuildTargetDirDebugText(targetDirs) {
    text := ""
    for _, dirEntry in targetDirs {
        dirPath := IsObject(dirEntry) ? dirEntry.path : dirEntry
        if (dirPath = "")
            continue
        if (text != "")
            text .= " || "
        text .= dirPath
    }
    return text
}

WrapTargetDirectoryPaths(dirPaths, role) {
    entries := []
    for _, dirPath in dirPaths {
        if (dirPath = "")
            continue
        entries.Push({path: dirPath, role: role})
    }
    return entries
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

FindRecentDateFolders(rootDir, maxCount) {
    dirs := []
    if (rootDir = "" || !DirExists(rootDir) || maxCount <= 0)
        return dirs

    FormatTime, today,, yyyyMMdd
    dateMap := {}
    CollectDateFoldersForMonth(rootDir, today, 0, today, dateMap)
    if (CountDateMapKeys(dateMap) < maxCount)
        CollectDateFoldersForMonth(rootDir, today, -1, today, dateMap)

    sortedDates := BuildSortedDateKeyList(dateMap, "R")
    Loop, Parse, sortedDates, `n, `r
    {
        dateValue := Trim(A_LoopField)
        if (dateValue = "")
            continue
        dirs.Push(dateMap[dateValue])
        if (dirs.Length() >= maxCount)
            break
    }
    return dirs
}

FindNearestFutureDateFolder(rootDir, todayYmd) {
    currentYear := SubStr(todayYmd, 1, 4)
    currentMonth := SubStr(todayYmd, 5, 2)

    bestPath := FindNearestFutureDateFolderInMonth(rootDir "\" currentYear "\" currentMonth, todayYmd)
    if (bestPath != "")
        return bestPath

    nextMonthStamp := currentYear . currentMonth . "01000000"
    EnvAdd, nextMonthStamp, 1, Months
    nextYear := SubStr(nextMonthStamp, 1, 4)
    nextMonth := SubStr(nextMonthStamp, 5, 2)

    return FindNearestFutureDateFolderInMonth(rootDir "\" nextYear "\" nextMonth, todayYmd)
}

FindNextBusinessDayFolder(rootDir, todayYmd) {
    nextYmd := GetNextBusinessDayYmd(todayYmd)
    if (nextYmd = "")
        return ""

    year := SubStr(nextYmd, 1, 4)
    month := SubStr(nextYmd, 5, 2)

    directPath := rootDir "\" nextYmd
    nestedPath := rootDir "\" year "\" month "\" nextYmd
    if DirExists(directPath)
        return directPath
    if DirExists(nestedPath)
        return nestedPath

    return FindDateFolderRecursive(rootDir, nextYmd)
}

GetNextBusinessDayYmd(todayYmd) {
    probeStamp := todayYmd . "000000"
    Loop, 10 {
        EnvAdd, probeStamp, 1, Days
        probeYmd := SubStr(probeStamp, 1, 8)
        if !IsWeekendYmd(probeYmd)
            return probeYmd
    }
    return ""
}

IsWeekendYmd(ymd) {
    FormatTime, dayOfWeek, % ymd, WDay
    return (dayOfWeek = 1 || dayOfWeek = 7)
}

FindNearestFutureDateFolderInMonth(monthDir, todayYmd) {
    if !DirExists(monthDir)
        return ""

    bestDate := ""
    bestPath := ""
    Loop, Files, % monthDir "\*", D
    {
        folderName := A_LoopFileName
        if !RegExMatch(folderName, "^\d{8}$")
            continue
        if (folderName + 0 <= todayYmd + 0)
            continue

        if (bestDate = "" || folderName + 0 < bestDate + 0) {
            bestDate := folderName
            bestPath := A_LoopFileFullPath
            continue
        }

        if (folderName = bestDate && StrLen(A_LoopFileFullPath) < StrLen(bestPath))
            bestPath := A_LoopFileFullPath
    }
    return bestPath
}

CollectDateFoldersForMonth(rootDir, anchorYmd, monthOffset, maxYmd, ByRef dateMap) {
    monthStamp := SubStr(anchorYmd, 1, 6) . "01000000"
    EnvAdd, monthStamp, %monthOffset%, Months
    monthDir := rootDir "\" SubStr(monthStamp, 1, 4) "\" SubStr(monthStamp, 5, 2)
    if !DirExists(monthDir)
        return

    Loop, Files, % monthDir "\*", D
    {
        folderName := A_LoopFileName
        if !RegExMatch(folderName, "^\d{8}$")
            continue
        if (folderName + 0 > maxYmd + 0)
            continue

        if (!dateMap.HasKey(folderName) || StrLen(A_LoopFileFullPath) < StrLen(dateMap[folderName]))
            dateMap[folderName] := A_LoopFileFullPath
    }
}

CountDateMapKeys(dateMap) {
    count := 0
    for _, __ in dateMap
        count += 1
    return count
}

BuildSortedDateKeyList(dateMap, order := "A") {
    keyList := ""
    for dateValue, _ in dateMap
        keyList .= dateValue "`n"

    options := "N"
    if (order = "R")
        options .= " R"
    Sort, keyList, %options%
    return keyList
}

ShouldIncludeCsvFile(csvPath, teamCfg, targetEntry := "") {
    previousDatePolicy := EvaluatePreviousDateCsvPolicy(csvPath, teamCfg)
    if !previousDatePolicy.should_include {
        AppendDebug("csv_file_skipped", teamCfg.team_name . "|" . csvPath . "|reason=" . previousDatePolicy.reason)
        return false
    }

    targetPolicy := EvaluateTargetEntryCsvPolicy(csvPath, teamCfg, targetEntry)
    if !targetPolicy.should_include {
        AppendDebug("csv_file_skipped", teamCfg.team_name . "|" . csvPath . "|reason=" . targetPolicy.reason)
        return false
    }

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

EvaluateTargetEntryCsvPolicy(csvPath, teamCfg, targetEntry) {
    result := {should_include: true, reason: ""}
    if !IsObject(targetEntry)
        return result

    role := ToLower(Trim(targetEntry.role))
    if (role != "today_created_after_cutoff")
        return result

    createdAfterHour := ResolveTodayCreatedAfterHour(teamCfg)
    if (createdAfterHour < 0)
        return result

    FormatTime, todayYmd,, yyyyMMdd
    thresholdStamp := todayYmd . Format("{:02}", createdAfterHour + 0) . "0000"
    FileGetTime, createdTime, %csvPath%, C
    if (createdTime < thresholdStamp) {
        result.should_include := false
        result.reason := "today_created_before_cutoff"
    }
    return result
}

ResolveTodayCreatedAfterHour(teamCfg) {
    createdAfterHour := ToInt(teamCfg.today_file_created_after_hour, -1)
    if (createdAfterHour >= 0)
        return createdAfterHour
    return ToInt(teamCfg.cutoff_hour, -1)
}

EvaluatePreviousDateCsvPolicy(csvPath, teamCfg) {
    result := {should_include: true, reason: ""}
    scanBeforeHour := ToInt(teamCfg.previous_date_scan_before_hour, -1)
    createdAfterHour := ToInt(teamCfg.previous_date_created_after_hour, -1)
    if (scanBeforeHour < 0 && createdAfterHour < 0)
        return result

    dateFolder := ExtractCsvDateFolder(csvPath)
    if (dateFolder = "")
        return result

    FormatTime, today,, yyyyMMdd
    if (dateFolder + 0 >= today + 0)
        return result

    FormatTime, currentHour,, HH
    if (scanBeforeHour >= 0 && currentHour + 0 >= scanBeforeHour) {
        result.should_include := false
        result.reason := "previous_date_scan_window_closed"
        return result
    }

    if (createdAfterHour >= 0) {
        FileGetTime, createdTime, %csvPath%, C
        FormatTime, createdHour, %createdTime%, HH
        if (createdHour + 0 < createdAfterHour) {
            result.should_include := false
            result.reason := "previous_date_created_before_hour"
        }
    }

    return result
}

ExtractCsvDateFolder(csvPath) {
    normalizedPath := StrReplace(csvPath, "/", "\")
    if RegExMatch(normalizedPath, "\\(\d{8})\\", match)
        return match1
    return ""
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

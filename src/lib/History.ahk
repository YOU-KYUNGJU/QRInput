global g_HistoryCache := {}
global g_TodayReceiptSuccessCache := {}
global g_HistoryLoadedPath := ""
global g_HistoryTeamProfiles := []

InitializeHistoryStore(historyDir, teamProfiles := "") {
    global g_HistoryCache, g_TodayReceiptSuccessCache, g_HistoryLoadedPath, g_HistoryTeamProfiles
    g_HistoryCache := {}
    g_TodayReceiptSuccessCache := {}
    g_HistoryLoadedPath := historyDir
    g_HistoryTeamProfiles := IsObject(teamProfiles) ? teamProfiles : []

    EnsureDir(historyDir)
    filePaths := CollectHistoryStoreFiles(historyDir)
    for _, filePath in filePaths {
        rows := LoadCsvRows(filePath)
        for _, rowObj in rows {
            if IsHistoryHeaderRow(rowObj)
                continue
            rowData := ReadHistoryRow(rowObj)
            uniqueKey := rowData.unique_key
            if (uniqueKey != "")
                g_HistoryCache[uniqueKey] := true
            if IsHistorySuccessFromToday(filePath, rowData.success_at)
                AddTodayReceiptSuccess(rowData.team_name, rowData.part_name, rowData.receipt_no)
        }
    }
}

EnsureHistoryInitialized(historyDir) {
    global g_HistoryLoadedPath, g_HistoryTeamProfiles
    if (g_HistoryLoadedPath != historyDir)
        InitializeHistoryStore(historyDir, g_HistoryTeamProfiles)
}

IsAlreadySuccessful(historyDir, uniqueKey) {
    global g_HistoryCache
    EnsureHistoryInitialized(historyDir)
    return g_HistoryCache.HasKey(uniqueKey)
}

IsReceiptSuccessfulToday(historyDir, teamName, partName, receiptNo) {
    global g_TodayReceiptSuccessCache
    EnsureHistoryInitialized(historyDir)
    return g_TodayReceiptSuccessCache.HasKey(BuildTodayReceiptSuccessKey(teamName, partName, receiptNo))
}

AppendSuccessHistory(historyDir, teamName, partName, sourceFile, rowNo, receiptNo, uniqueKey) {
    global g_HistoryCache
    EnsureHistoryInitialized(historyDir)
    AddTodayReceiptSuccess(teamName, partName, receiptNo)
    if g_HistoryCache.HasKey(uniqueKey)
        return

    filePath := ResolveDatedLogFilePath(historyDir, "history_success.csv")
    EnsureCsvHeader(filePath, "team,source_file,row_no,receipt_no,unique_key,success_at")
    AppendCsvRecord(filePath, [teamName, sourceFile, rowNo, receiptNo, uniqueKey, NowIso()])
    g_HistoryCache[uniqueKey] := true
}

AddTodayReceiptSuccess(teamName, partName, receiptNo) {
    global g_TodayReceiptSuccessCache
    key := BuildTodayReceiptSuccessKey(teamName, partName, receiptNo)
    if (key != "")
        g_TodayReceiptSuccessCache[key] := true
}

BuildTodayReceiptSuccessKey(teamName, partName, receiptNo) {
    teamName := Trim(teamName)
    partName := Trim(partName)
    receiptNo := ToUpper(Trim(receiptNo))
    if (teamName = "" || receiptNo = "")
        return ""
    return BuildHistoryScopeName(teamName, partName) "|" receiptNo
}

BuildHistoryTeamProfiles(cfg) {
    profiles := []
    if !IsObject(cfg)
        return profiles

    for _, sectionName in cfg._team_sections {
        teamCfg := cfg[sectionName]
        profiles.Push({team_name: Trim(teamCfg.team_name), part_name: Trim(teamCfg.part_name), csv_root_path: NormalizeHistoryPath(teamCfg.csv_root_path)})
    }
    return profiles
}

IsHistoryHeaderRow(rowObj) {
    return (ToLower(Trim(rowObj.A)) = "team")
}

ReadHistoryRow(rowObj) {
    teamName := Trim(rowObj.A)
    sourceFile := Trim(rowObj.B)
    receiptNo := Trim(rowObj.D)
    uniqueKey := Trim(rowObj.E)
    successAt := Trim(rowObj.F)
    partName := ResolveHistoryPartName(teamName, sourceFile)
    return {team_name: teamName, part_name: partName, source_file: sourceFile, receipt_no: receiptNo, unique_key: uniqueKey, success_at: successAt}
}

ResolveHistoryPartName(teamName, sourceFile) {
    global g_HistoryTeamProfiles
    teamName := Trim(teamName)
    sourceFile := NormalizeHistoryPath(sourceFile)
    if (teamName = "" || sourceFile = "")
        return ""

    for _, profile in g_HistoryTeamProfiles {
        if (Trim(profile.team_name) != teamName)
            continue
        rootPath := NormalizeHistoryPath(profile.csv_root_path)
        if (rootPath = "")
            continue
        if IsPathWithinRoot(sourceFile, rootPath)
            return Trim(profile.part_name)
    }
    return ""
}

BuildHistoryScopeName(teamName, partName := "") {
    teamName := Trim(teamName)
    partName := Trim(partName)
    if (teamName = "")
        return ""
    if (partName = "")
        return teamName
    return teamName "|" partName
}

NormalizeHistoryPath(path) {
    path := Trim(path)
    if (path = "")
        return ""
    path := StrReplace(path, "/", "\")
    path := RegExReplace(path, "\\+$")
    return ToLower(path)
}

IsPathWithinRoot(path, rootPath) {
    if (path = "" || rootPath = "")
        return false
    if (path = rootPath)
        return true
    return (SubStr(path, 1, StrLen(rootPath) + 1) = rootPath . "\")
}

IsHistorySuccessFromToday(filePath, successAt) {
    FormatTime, todayCompact,, yyyyMMdd
    FormatTime, todayIso,, yyyy-MM-dd

    successAt := Trim(successAt)
    if (SubStr(successAt, 1, 10) = todayIso)
        return true

    filePath := StrReplace(filePath, "/", "\")
    if RegExMatch(filePath, "\\(\d{8})_history_success\.csv$", match)
        return (match1 = todayCompact)
    return false
}

CollectHistoryStoreFiles(historyDir) {
    files := []
    seen := {}

    legacyPath := historyDir "\history_success.csv"
    if FileExist(legacyPath) {
        files.Push(legacyPath)
        seen[ToLower(legacyPath)] := true
    }

    Loop, Files, % historyDir "\*_history_success.csv", FR
    {
        filePath := A_LoopFileFullPath
        key := ToLower(filePath)
        if seen.HasKey(key)
            continue
        seen[key] := true
        files.Push(filePath)
    }
    return files
}

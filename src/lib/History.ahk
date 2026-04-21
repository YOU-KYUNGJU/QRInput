global g_HistoryCache := {}
global g_TodayReceiptSuccessCache := {}
global g_HistoryLoadedPath := ""

InitializeHistoryStore(historyDir) {
    global g_HistoryCache, g_TodayReceiptSuccessCache, g_HistoryLoadedPath
    g_HistoryCache := {}
    g_TodayReceiptSuccessCache := {}
    g_HistoryLoadedPath := historyDir

    EnsureDir(historyDir)
    filePaths := CollectHistoryStoreFiles(historyDir)
    for _, filePath in filePaths {
        rows := LoadCsvRows(filePath)
        for _, rowObj in rows {
            if (ToLower(Trim(rowObj.A)) = "team")
                continue
            uniqueKey := Trim(rowObj.E)
            if (uniqueKey != "")
                g_HistoryCache[uniqueKey] := true
            if IsHistorySuccessFromToday(filePath, rowObj.F)
                AddTodayReceiptSuccess(rowObj.A, rowObj.D)
        }
    }
}

EnsureHistoryInitialized(historyDir) {
    global g_HistoryLoadedPath
    if (g_HistoryLoadedPath != historyDir)
        InitializeHistoryStore(historyDir)
}

IsAlreadySuccessful(historyDir, uniqueKey) {
    global g_HistoryCache
    EnsureHistoryInitialized(historyDir)
    return g_HistoryCache.HasKey(uniqueKey)
}

IsReceiptSuccessfulToday(historyDir, teamName, receiptNo) {
    global g_TodayReceiptSuccessCache
    EnsureHistoryInitialized(historyDir)
    return g_TodayReceiptSuccessCache.HasKey(BuildTodayReceiptSuccessKey(teamName, receiptNo))
}

AppendSuccessHistory(historyDir, teamName, sourceFile, rowNo, receiptNo, uniqueKey) {
    global g_HistoryCache
    EnsureHistoryInitialized(historyDir)
    AddTodayReceiptSuccess(teamName, receiptNo)
    if g_HistoryCache.HasKey(uniqueKey)
        return

    filePath := ResolveDatedLogFilePath(historyDir, "history_success.csv")
    EnsureCsvHeader(filePath, "team,source_file,row_no,receipt_no,unique_key,success_at")
    AppendCsvRecord(filePath, [teamName, sourceFile, rowNo, receiptNo, uniqueKey, NowIso()])
    g_HistoryCache[uniqueKey] := true
}

AddTodayReceiptSuccess(teamName, receiptNo) {
    global g_TodayReceiptSuccessCache
    key := BuildTodayReceiptSuccessKey(teamName, receiptNo)
    if (key != "")
        g_TodayReceiptSuccessCache[key] := true
}

BuildTodayReceiptSuccessKey(teamName, receiptNo) {
    teamName := Trim(teamName)
    receiptNo := ToUpper(Trim(receiptNo))
    if (teamName = "" || receiptNo = "")
        return ""
    return teamName "|" receiptNo
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

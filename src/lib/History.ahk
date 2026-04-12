global g_HistoryCache := {}
global g_HistoryLoadedPath := ""

InitializeHistoryStore(historyDir) {
    global g_HistoryCache, g_HistoryLoadedPath
    g_HistoryCache := {}
    g_HistoryLoadedPath := historyDir

    EnsureDir(historyDir)
    filePath := historyDir "\history_success.csv"
    if !FileExist(filePath)
        return

    rows := LoadCsvRows(filePath)
    for _, rowObj in rows {
        if (ToLower(Trim(rowObj.A)) = "team")
            continue
        uniqueKey := Trim(rowObj.E)
        if (uniqueKey != "")
            g_HistoryCache[uniqueKey] := true
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

AppendSuccessHistory(historyDir, teamName, sourceFile, rowNo, receiptNo, uniqueKey) {
    global g_HistoryCache
    EnsureHistoryInitialized(historyDir)
    if g_HistoryCache.HasKey(uniqueKey)
        return

    filePath := historyDir "\history_success.csv"
    EnsureCsvHeader(filePath, "team,source_file,row_no,receipt_no,unique_key,success_at")
    AppendCsvRecord(filePath, [teamName, sourceFile, rowNo, receiptNo, uniqueKey, NowIso()])
    g_HistoryCache[uniqueKey] := true
}

AppendRunSummary(runId, teamName, status, note := "", stats := "") {
    global g_Runtime
    filePath := g_Runtime.cfg.system.run_log_dir "\run_summary.csv"
    EnsureDir(g_Runtime.cfg.system.run_log_dir)
    EnsureCsvHeader(filePath, "run_id,started_at,finished_at,team,source_file_count,source_row_count,success_count,failure_count,relogin_count,elapsed_ms,longest_step,note")

    startedAt := IsObject(stats) ? stats.started_at : ""
    finishedAt := IsObject(stats) ? stats.finished_at : ""
    fileCount := IsObject(stats) ? stats.source_file_count : ""
    rowCount := IsObject(stats) ? stats.source_row_count : ""
    successCount := IsObject(stats) ? stats.success_count : ""
    failureCount := IsObject(stats) ? stats.failure_count : ""
    reloginCount := IsObject(stats) ? stats.relogin_count : ""
    elapsedMs := IsObject(stats) ? stats.elapsed_ms : ""
    longestStep := IsObject(stats) ? stats.longest_step : ""

    AppendCsvRecord(filePath, [runId, startedAt, finishedAt, teamName, fileCount, rowCount, successCount, failureCount, reloginCount, elapsedMs, longestStep, status . "|" . note])
}

AppendRowResult(runId, teamName, sourceFile, rowNo, receiptNo, uniqueKey, result) {
    global g_Runtime
    teamCfg := g_Runtime.currentTeamCfg
    EnsureDir(teamCfg.log_dir)
    filePath := teamCfg.log_dir "\row_results.csv"
    EnsureCsvHeader(filePath, "run_id,team,source_file,row_no,receipt_no,unique_key,status,error_code,reason,row_retry_count,session_retry_count,screenshot_path,started_at,finished_at,elapsed_ms")

    AppendCsvRecord(filePath, [runId, teamName, sourceFile, rowNo, receiptNo, uniqueKey, result.status, result.error_code, result.reason, result.row_retry_count, result.session_retry_count, result.screenshot_path, result.started_at, result.finished_at, result.elapsed_ms])
}

AppendDebug(code, message) {
    global g_Runtime
    if !IsObject(g_Runtime.cfg)
        return
    if !IsTrue(g_Runtime.cfg.system.debug_log_enabled)
        return

    EnsureDir(g_Runtime.cfg.system.debug_log_dir)
    FormatTime, ymd,, yyyyMMdd
    filePath := g_Runtime.cfg.system.debug_log_dir "\" ymd "_debug.txt"
    FileAppend, % "[" NowIso() "][" code "] " message "`r`n", %filePath%, UTF-8
}

CaptureQrScreenshot(teamCfg, sysCfg, receiptNo, status) {
    global g_Runtime
    if (status = "success" && !IsTrue(g_Runtime.cfg.system.success_screenshot_enabled))
        return ""
    if (status != "success" && !IsTrue(g_Runtime.cfg.system.failure_screenshot_enabled))
        return ""

    if !WinExist(sysCfg.qr_window_title)
        return ""

    captureDir := ResolveTeamScreenshotDir(teamCfg)
    if (captureDir = "")
        return ""

    EnsureDir(captureDir)
    WinGetPos, winX, winY, winW, winH, % sysCfg.qr_window_title
    if (winW = "" || winH = "" || winW <= 0 || winH <= 0)
        return ""

    pToken := Gdip_Startup()
    if !pToken
        return ""

    sanitizedTeam := SanitizeFileName(teamCfg.team_name)
    sanitizedReceipt := SanitizeFileName(receiptNo)
    filePath := captureDir "\" NowFileStamp() "_" sanitizedTeam "_" sanitizedReceipt "_" status ".png"

    pBitmap := Gdip_BitmapFromScreen(winX "|" winY "|" winW "|" winH)
    Gdip_SaveBitmapToFile(pBitmap, filePath)
    Gdip_DisposeImage(pBitmap)
    Gdip_Shutdown(pToken)
    return filePath
}

ResolveTeamScreenshotDir(teamCfg, ymd := "") {
    rootDir := TrimTrailingSlash(teamCfg.screenshot_dir)
    if (rootDir = "")
        return ""

    if (ymd = "")
        FormatTime, ymd,, yyyyMMdd

    year := SubStr(ymd, 1, 4)
    month := SubStr(ymd, 5, 2)
    return rootDir "\" year "\" month "\" ymd
}

CaptureDiagnosticScreenshot(label, windowRef := "") {
    global g_Runtime
    if !IsObject(g_Runtime.cfg)
        return ""
    if !IsTrue(g_Runtime.cfg.system.debug_log_enabled)
        return ""
    if IsLoginWindowRefForDiagnostic(windowRef)
        return ""

    captureArea := ResolveWindowCaptureArea(windowRef)
    if (captureArea = "")
        return ""

    captureDir := g_Runtime.cfg.system.debug_log_dir "\captures"
    EnsureDir(captureDir)

    pToken := Gdip_Startup()
    if !pToken
        return ""

    sanitizedLabel := SanitizeFileName(label)
    if (sanitizedLabel = "")
        sanitizedLabel := "diagnostic"
    filePath := captureDir "\" NowFileStamp() "_" sanitizedLabel ".png"

    pBitmap := Gdip_BitmapFromScreen(captureArea)
    Gdip_SaveBitmapToFile(pBitmap, filePath)
    Gdip_DisposeImage(pBitmap)
    Gdip_Shutdown(pToken)
    return filePath
}

IsLoginWindowRefForDiagnostic(windowRef := "") {
    global g_Runtime
    if (windowRef = "" || !WinExist(windowRef))
        return false
    if !IsObject(g_Runtime.cfg)
        return false

    loginTitle := g_Runtime.cfg.system.login_window_title
    if (loginTitle = "")
        return false

    WinGetTitle, currentTitle, % windowRef
    return InStr(currentTitle, loginTitle)
}

ResolveWindowCaptureArea(windowRef := "") {
    if (windowRef != "" && WinExist(windowRef)) {
        WinGetPos, winX, winY, winW, winH, % windowRef
        if (winW != "" && winH != "" && winW > 0 && winH > 0)
            return winX "|" winY "|" winW "|" winH
    }

    if (A_ScreenWidth <= 0 || A_ScreenHeight <= 0)
        return ""
    return "0|0|" A_ScreenWidth "|" A_ScreenHeight
}

TrimTrailingSlash(path) {
    return RegExReplace(path, "[\\/]+$")
}

EnsureCsvHeader(filePath, headerLine) {
    if FileExist(filePath)
        return
    SplitPath, filePath, , dirPath
    EnsureDir(dirPath)
    FileAppend, %headerLine%`r`n, %filePath%, UTF-8
}

AppendCsvRecord(filePath, values) {
    line := ""
    for index, value in values {
        if (index > 1)
            line .= ","
        line .= EscapeCsvValue(value)
    }
    FileAppend, %line%`r`n, %filePath%, UTF-8
}

EscapeCsvValue(value) {
    value := value . ""
    value := StrReplace(value, """", """""")
    if InStr(value, ",") || InStr(value, """") || InStr(value, "`r") || InStr(value, "`n")
        return """" value """"
    return value
}

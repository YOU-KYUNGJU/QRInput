#NoEnv
#SingleInstance Force
SetBatchLines, -1
ListLines, Off
SetTitleMatchMode, 2
SetWorkingDir, %A_ScriptDir%

#Include %A_ScriptDir%\lib\Config.ahk
#Include %A_ScriptDir%\lib\Runner.ahk
#Include %A_ScriptDir%\lib\Receipt.ahk
#Include %A_ScriptDir%\lib\FitiSession.ahk
#Include %A_ScriptDir%\lib\Logger.ahk
#Include %A_ScriptDir%\lib\History.ahk
#Include %A_ScriptDir%\lib\Gdip_All.ahk

global g_Runtime := {}

Main() {
    global g_Runtime

    configPath := ResolveRuntimeConfigPath()
    cfg := LoadConfig(configPath)
    g_Runtime.cfg := cfg

    InitializeHistoryStore(cfg.system.history_dir)
    AcquireRunLock(cfg.system)

    runId := CreateRunId()
    g_Runtime.runId := runId

    try {
        teamSections := ["team.analysis", "team.processing"]
        for _, section in teamSections {
            teamCfg := cfg[section]
            if !IsTrue(teamCfg.enabled)
                continue
            RunTeam(teamCfg, cfg.system, cfg.ui, runId)
        }
    } catch e {
        AppendDebug("fatal_exception", e.Message)
    } finally {
        ReleaseRunLock(cfg.system)
    }
}

ResolveRuntimeConfigPath() {
    localPath := A_ScriptDir "\..\config\qr_input.local.ini"
    if FileExist(localPath)
        return localPath
    return A_ScriptDir "\..\config\qr_input_config.template.ini"
}

RunTeam(teamCfg, sysCfg, uiCfg, runId) {
    global g_Runtime
    g_Runtime.currentTeamCfg := teamCfg
    g_Runtime.currentTeamStats := CreateTeamStats()
    g_Runtime.currentTeamStats.started_at := NowIso()
    teamStartTick := A_TickCount

    AppendDebug("team_start", teamCfg.team_name)
    CloseExistingFitiIfNeeded(sysCfg)

    if !StartFiti(sysCfg, uiCfg) {
        g_Runtime.currentTeamStats.failure_count += 1
        g_Runtime.currentTeamStats.longest_step := "start_fiti"
        FinishTeamRun(runId, teamCfg.team_name, "team_login_failed", "start_fiti_failed", teamStartTick)
        return
    }

    if !EnsureLoggedIn(teamCfg, sysCfg, uiCfg) {
        g_Runtime.currentTeamStats.failure_count += 1
        g_Runtime.currentTeamStats.longest_step := "login"
        FinishTeamRun(runId, teamCfg.team_name, "team_login_failed", "login_failed", teamStartTick)
        return
    }

    if !EnsureQrWindow(sysCfg, uiCfg) {
        g_Runtime.currentTeamStats.failure_count += 1
        g_Runtime.currentTeamStats.longest_step := "open_qr"
        FinishTeamRun(runId, teamCfg.team_name, "team_wait_next_schedule", "qr_window_failed", teamStartTick)
        return
    }

    files := CollectCsvFiles(teamCfg)
    g_Runtime.currentTeamStats.source_file_count := files.Length()

    continueTeam := true
    for _, csvPath in files {
        if !ProcessCsvFile(csvPath, teamCfg, sysCfg, uiCfg, runId) {
            continueTeam := false
            break
        }
    }

    finalStatus := continueTeam ? "team_finished" : "team_wait_next_schedule"
    finalNote := continueTeam ? "completed" : "session_retry_exhausted"
    FinishTeamRun(runId, teamCfg.team_name, finalStatus, finalNote, teamStartTick)
}

FinishTeamRun(runId, teamName, status, note, teamStartTick) {
    global g_Runtime
    g_Runtime.currentTeamStats.finished_at := NowIso()
    g_Runtime.currentTeamStats.elapsed_ms := ElapsedMs(teamStartTick)
    if IsTrue(g_Runtime.cfg.system.close_fiti_after_team_run)
        CloseFiti(g_Runtime.cfg.system)
    AppendRunSummary(runId, teamName, status, note, g_Runtime.currentTeamStats)
    AppendDebug("team_end", teamName . "|" . status . "|" . note)
}

ProcessCsvFile(csvPath, teamCfg, sysCfg, uiCfg, runId) {
    global g_Runtime
    rows := LoadCsvRows(csvPath)
    rowCount := rows.Length()
    g_Runtime.currentTeamStats.source_row_count += rowCount

    for _, rowObj in rows {
        rowNo := rowObj._row_no

        if !ShouldProcessRow(rowObj, teamCfg)
            continue

        receipt := ExtractReceipt(rowObj, teamCfg)
        if (receipt.status != "ok") {
            invalidResult := CreateBasicResult("skipped_invalid", "invalid_receipt", receipt.reason)
            AppendRowResult(runId, teamCfg.team_name, csvPath, rowNo, "", "", invalidResult)
            continue
        }

        uniqueKey := BuildUniqueKey(teamCfg.team_name, csvPath, rowNo, receipt.value)
        if (IsAlreadySuccessful(sysCfg.history_dir, uniqueKey)) {
            skippedResult := CreateBasicResult("skipped_done", "", "already_successful")
            AppendRowResult(runId, teamCfg.team_name, csvPath, rowNo, receipt.value, uniqueKey, skippedResult)
            continue
        }

        result := ExecuteReceipt(receipt.value, teamCfg, sysCfg, uiCfg)
        AppendRowResult(runId, teamCfg.team_name, csvPath, rowNo, receipt.value, uniqueKey, result)

        if (result.status = "success") {
            g_Runtime.currentTeamStats.success_count += 1
            AppendSuccessHistory(sysCfg.history_dir, teamCfg.team_name, csvPath, rowNo, receipt.value, uniqueKey)
        } else if (result.status = "failed") {
            g_Runtime.currentTeamStats.failure_count += 1
        } else if (result.status = "wait_next_schedule") {
            g_Runtime.currentTeamStats.failure_count += 1
            g_Runtime.currentTeamStats.longest_step := "session_recovery"
            return false
        }
    }

    return true
}

CreateTeamStats() {
    return {started_at: "", finished_at: "", source_file_count: 0, source_row_count: 0, success_count: 0, failure_count: 0, relogin_count: 0, elapsed_ms: 0, longest_step: ""}
}

CreateBasicResult(status, errorCode := "", reason := "") {
    return {status: status, error_code: errorCode, reason: reason, row_retry_count: 0, session_retry_count: GetCurrentTeamReloginCount(), screenshot_path: "", started_at: NowIso(), finished_at: NowIso(), elapsed_ms: 0}
}

Main()

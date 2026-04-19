CloseExistingFitiIfNeeded(sysCfg) {
    if !IsTrue(sysCfg.close_existing_fiti_before_run)
        return

    CloseAllKnownFitiWindows(sysCfg)
    if WaitForKnownFitiWindowsClosed(sysCfg, 1500, 200)
        return

    CloseKnownFitiProcesses(sysCfg)
    Sleep, 500
    CloseAllKnownFitiWindows(sysCfg)
    WaitForKnownFitiWindowsClosed(sysCfg, 2000, 200)
}

CloseAllKnownFitiWindows(sysCfg) {
    CloseWindowsByTitle(sysCfg.qr_window_title)
    CloseWindowsByTitle(sysCfg.main_window_title)
    CloseWindowsByTitle(sysCfg.login_window_title)
    CloseWindowsByTitle("협조요청")
}

CloseWindowsByTitle(windowTitle) {
    if (windowTitle = "")
        return

    WinGet, idList, List, % windowTitle
    Loop, %idList%
    {
        hwnd := idList%A_Index%
        if !hwnd
            continue
        WinClose, % "ahk_id " . hwnd
    }
}

WaitForKnownFitiWindowsClosed(sysCfg, timeoutMs, pollMs) {
    started := A_TickCount
    while (ElapsedMs(started) <= timeoutMs) {
        if !HasKnownFitiWindows(sysCfg)
            return true
        Sleep, %pollMs%
    }
    return !HasKnownFitiWindows(sysCfg)
}

HasKnownFitiWindows(sysCfg) {
    knownTitles := [sysCfg.login_window_title, sysCfg.main_window_title, sysCfg.qr_window_title, "협조요청"]
    for _, title in knownTitles {
        if (title != "" && WinExist(title))
            return true
    }
    return false
}

ResolveReadySessionWindowRef(sysCfg) {
    if (sysCfg.qr_window_title != "" && WinExist(sysCfg.qr_window_title))
        return sysCfg.qr_window_title
    if (sysCfg.main_window_title != "" && WinExist(sysCfg.main_window_title))
        return sysCfg.main_window_title
    return ""
}

HasReadySessionWindow(sysCfg) {
    return (ResolveReadySessionWindowRef(sysCfg) != "")
}

WaitForReadySessionWindow(sysCfg, timeoutMs, pollMs) {
    started := A_TickCount
    while (ElapsedMs(started) <= timeoutMs) {
        if HasReadySessionWindow(sysCfg)
            return true
        Sleep, %pollMs%
    }
    return HasReadySessionWindow(sysCfg)
}

StartFiti(sysCfg, uiCfg) {
    Run, % sysCfg.fiti_exe_path, , UseErrorLevel
    if ErrorLevel {
        AppendDebug("fiti_start_failed", sysCfg.fiti_exe_path)
        return false
    }

    if !WaitForFitiStartupWindow(sysCfg, ToInt(sysCfg.wait_main_timeout_ms, 12000), ToInt(sysCfg.default_poll_interval_ms, 200)) {
        AppendDebug("fiti_start_timeout", sysCfg.main_window_title . "|" . DescribeOpenFitiWindows(sysCfg))
        return false
    }

    MoveMainWindowIfNeeded(sysCfg, uiCfg)
    return true
}

EnsureLoggedIn(teamCfg, sysCfg, uiCfg) {
    if !WaitForLoginWindow(sysCfg, ToInt(sysCfg.wait_login_timeout_ms, 12000), ToInt(sysCfg.default_poll_interval_ms, 200)) {
        AppendDebug("login_window_missing", teamCfg.team_name . "|" . DescribeOpenFitiWindows(sysCfg))
        if !HasReadySessionWindow(sysCfg)
            RecordLoginDiagnostics(teamCfg, sysCfg, uiCfg, "login_window_missing")
        return HasReadySessionWindow(sysCfg)
    }

    loginWindowRef := ResolveLoginWindowRef(sysCfg)
    if (loginWindowRef = "") {
        AppendDebug("login_window_unresolved", teamCfg.team_name . "|" . DescribeOpenFitiWindows(sysCfg))
        if !HasReadySessionWindow(sysCfg)
            RecordLoginDiagnostics(teamCfg, sysCfg, uiCfg, "login_window_unresolved")
        return HasReadySessionWindow(sysCfg)
    }

    WinActivate, % loginWindowRef
    WinWaitActive, % loginWindowRef, , 3

    AppendDebug("login_begin", teamCfg.team_name . "|" . MaskLoginValue(teamCfg.login_id))

    userOk := SetLoginFieldValue(loginWindowRef, uiCfg.login_user_control, teamCfg.login_id, true)
    passOk := SetLoginFieldValue(loginWindowRef, uiCfg.login_password_control, teamCfg.login_password, false)

    AppendDebug("login_field_status", "user=" . userOk . "|pass=" . passOk)
    AppendDebug("login_submit_begin", teamCfg.team_name . "|" . loginWindowRef)
    SubmitLogin(loginWindowRef, uiCfg)
    AppendDebug("login_submit_done", DescribeOpenFitiWindows(sysCfg))

    postKeys := uiCfg.login_post_submit_keys
    if (postKeys != "" && WinExist(loginWindowRef)) {
        AppendDebug("login_post_keys", postKeys)
        Sleep, 300
        SendInput, % postKeys
    }

    HandleImmediatePostLoginNotice(sysCfg, uiCfg, 3000, 100)

    AppendDebug("login_wait_main", sysCfg.main_window_title)
    loginOutcome := WaitForLoginOutcome(sysCfg, uiCfg, ToInt(sysCfg.wait_main_timeout_ms, 12000), ToInt(sysCfg.default_poll_interval_ms, 200))
    if (loginOutcome = "main" || loginOutcome = "qr") {
        MoveMainWindowIfNeeded(sysCfg, uiCfg)
        AppendDebug("login_success", teamCfg.team_name . "|" . loginOutcome)
        return true
    }

    if (loginOutcome = "modal") {
        popupInfo := DescribeUnexpectedFitiWindow(sysCfg)
        AppendDebug("login_modal_unhandled", popupInfo)
        RecordLoginDiagnostics(teamCfg, sysCfg, uiCfg, "login_modal_unhandled", ResolveUnexpectedFitiWindowRef(sysCfg), popupInfo)
        return false
    }

    if (loginOutcome = "process_closed") {
        AppendDebug("login_process_closed", teamCfg.team_name . "|" . DescribeOpenFitiWindows(sysCfg))
        RecordLoginDiagnostics(teamCfg, sysCfg, uiCfg, "login_process_closed", loginWindowRef)
        return false
    }

    if (loginOutcome = "login_closed") {
        AppendDebug("login_window_closed_without_main", teamCfg.team_name . "|" . DescribeOpenFitiWindows(sysCfg))
        RecordLoginDiagnostics(teamCfg, sysCfg, uiCfg, "login_closed_without_main")
        return false
    }

    if !WaitForReadySessionWindow(sysCfg, 1, 1) {
        userText := SafeReadLoginField(loginWindowRef, uiCfg.login_user_control)
        AppendDebug("login_main_timeout", teamCfg.team_name . "|user=" . MaskLoginValue(userText) . "|" . DescribeOpenFitiWindows(sysCfg))
        RecordLoginDiagnostics(teamCfg, sysCfg, uiCfg, "login_main_timeout", loginWindowRef, "user=" . MaskLoginValue(userText) . "|outcome=" . loginOutcome)
        return false
    }
    MoveMainWindowIfNeeded(sysCfg, uiCfg)
    AppendDebug("login_success", teamCfg.team_name . "|late_ready")
    return true
}

EnsureQrWindow(sysCfg, uiCfg) {
    if WinExist(sysCfg.qr_window_title) {
        AppendDebug("qr_open_skip", "already_open")
        return true
    }
    if !WinExist(sysCfg.main_window_title) {
        AppendDebug("qr_open_main_missing", DescribeOpenFitiWindows(sysCfg))
        return false
    }

    clickCount := ToInt(uiCfg.qr_button_click_count, 2)
    waitMs := ToInt(uiCfg.qr_button_wait_ms, 400)
    AppendDebug("qr_open_begin", "attempts=" . clickCount . "|wait_ms=" . waitMs . "|main=" . sysCfg.main_window_title)

    try {
        WinActivate, % sysCfg.main_window_title
        WinWaitActive, % sysCfg.main_window_title, , 3
    } catch e {
        AppendDebug("qr_open_activate_error", DescribeException(e) . "|" . DescribeOpenFitiWindows(sysCfg))
    }
    MoveMainWindowIfNeeded(sysCfg, uiCfg)

    Loop, %clickCount%
    {
        AppendDebug("qr_open_click", A_Index . "/" . clickCount . "|x=" . uiCfg.qr_button_x . "|y=" . uiCfg.qr_button_y)
        MouseClick, left, % uiCfg.qr_button_x, % uiCfg.qr_button_y, 1, 0
        Sleep, %waitMs%
        if WinExist(sysCfg.qr_window_title) {
            AppendDebug("qr_open_success", "click=" . A_Index . "|" . DescribeOpenFitiWindows(sysCfg))
            return true
        }
    }

    timeoutMs := ToInt(sysCfg.wait_qr_window_timeout_ms, 8000)
    pollMs := ToInt(sysCfg.default_poll_interval_ms, 200)
    AppendDebug("qr_open_wait", "timeout_ms=" . timeoutMs . "|poll_ms=" . pollMs)

    if WaitForWindow(sysCfg.qr_window_title, timeoutMs, pollMs) {
        AppendDebug("qr_open_success", "wait|" . DescribeOpenFitiWindows(sysCfg))
        return true
    }

    AppendDebug("qr_open_timeout", DescribeOpenFitiWindows(sysCfg))
    return false
}

ExecuteReceipt(receiptNo, teamCfg, sysCfg, uiCfg) {
    result := {status: "failed", error_code: "row_retry_exhausted", reason: "row_retry_exhausted", row_retry_count: 0, session_retry_count: GetCurrentTeamReloginCount(), screenshot_path: "", started_at: NowIso(), finished_at: "", elapsed_ms: 0, longest_step: "execute_receipt"}
    startTick := A_TickCount
    maxRetry := ToInt(sysCfg.max_row_retry_count, 3)

    Loop, %maxRetry%
    {
        result.row_retry_count := A_Index - 1

        if !EnsureSessionReady(teamCfg, sysCfg, uiCfg) {
            result.status := "wait_next_schedule"
            result.error_code := "session_relogin_exhausted"
            result.reason := "session_relogin_exhausted"
            break
        }

        if !SendReceiptToQr(receiptNo, sysCfg) {
            result.status := "failed"
            result.error_code := "send_failed"
            result.reason := "send_failed"
            continue
        }

        if !VerifyReceiptEcho(receiptNo, sysCfg, uiCfg) {
            result.status := "failed"
            result.error_code := "verify_mismatch"
            result.reason := "verify_mismatch"
            continue
        }

        checkboxState := GetCheckboxState(uiCfg)
        if (checkboxState = "checked") {
            result.status := "success"
            result.error_code := ""
            result.reason := "already_checked"
            result.screenshot_path := CaptureQrScreenshot(teamCfg, sysCfg, receiptNo, "success")
            break
        }

        if (checkboxState = "unchecked") {
            if ApplyCheckboxAndSave(sysCfg, uiCfg) {
                if WaitForCheckboxState(uiCfg, "checked", ToInt(sysCfg.wait_save_timeout_ms, 5000), ToInt(sysCfg.default_poll_interval_ms, 200)) {
                    result.status := "success"
                    result.error_code := ""
                    result.reason := "checked_and_saved"
                    result.screenshot_path := CaptureQrScreenshot(teamCfg, sysCfg, receiptNo, "success")
                    break
                }
                result.status := "failed"
                result.error_code := "checkbox_not_confirmed"
                result.reason := "checkbox_not_confirmed"
            } else {
                result.status := "failed"
                result.error_code := "save_action_failed"
                result.reason := "save_action_failed"
            }
            continue
        }

        result.status := "failed"
        result.error_code := "checkbox_state_unknown"
        result.reason := "checkbox_state_unknown"
    }

    if (result.status != "success")
        result.screenshot_path := CaptureQrScreenshot(teamCfg, sysCfg, receiptNo, "failure")

    result.session_retry_count := GetCurrentTeamReloginCount()
    result.finished_at := NowIso()
    result.elapsed_ms := ElapsedMs(startTick)
    return result
}

EnsureSessionReady(teamCfg, sysCfg, uiCfg) {
    if WinExist(sysCfg.login_window_title)
        return TryRecoverSession(teamCfg, sysCfg, uiCfg, "login_window_reappeared")
    if !WinExist(sysCfg.main_window_title)
        return TryRecoverSession(teamCfg, sysCfg, uiCfg, "main_window_missing")
    if WinExist(sysCfg.qr_window_title)
        return true
    if EnsureQrWindow(sysCfg, uiCfg)
        return true
    return TryRecoverSession(teamCfg, sysCfg, uiCfg, "qr_window_missing")
}

TryRecoverSession(teamCfg, sysCfg, uiCfg, reason) {
    maxRelogin := ToInt(sysCfg.max_relogin_count, 3)
    Loop, %maxRelogin%
    {
        if (GetCurrentTeamReloginCount() >= maxRelogin)
            break

        IncrementTeamReloginCount()
        AppendDebug("session_relogin", teamCfg.team_name . "|" . reason . "|" . GetCurrentTeamReloginCount())

        CloseExistingFitiIfNeeded(sysCfg)
        if !StartFiti(sysCfg, uiCfg)
            continue
        if !EnsureLoggedIn(teamCfg, sysCfg, uiCfg)
            continue
        if EnsureQrWindow(sysCfg, uiCfg)
            return true
    }
    return false
}

SendReceiptToQr(receiptNo, sysCfg) {
    if !WinExist(sysCfg.qr_window_title)
        return false

    WinActivate, % sysCfg.qr_window_title
    WinWaitActive, % sysCfg.qr_window_title, , 3
    SendInput, %receiptNo%
    Sleep, 250
    return true
}

VerifyReceiptEcho(receiptNo, sysCfg, uiCfg) {
    controls := StrSplit(uiCfg.qr_verify_controls, "|")
    timeoutMs := ToInt(sysCfg.default_wait_timeout_ms, 7000)
    pollMs := ToInt(sysCfg.default_poll_interval_ms, 200)
    started := A_TickCount

    while (ElapsedMs(started) <= timeoutMs) {
        echoed := "@"
        for _, controlName in controls {
            controlText := ""
            ControlGetText, controlText, % Trim(controlName), % sysCfg.qr_window_title
            echoed .= Trim(controlText)
        }
        echoed .= "@"

        if (echoed = receiptNo)
            return true

        Sleep, %pollMs%
    }

    return false
}

GetCheckboxState(uiCfg) {
    if (uiCfg.checkbox_pixel_x = "" || uiCfg.checkbox_pixel_y = "")
        return "unknown"

    PixelGetColor, pixelColor, % uiCfg.checkbox_pixel_x, % uiCfg.checkbox_pixel_y, RGB
    pixelColor := ToUpper(pixelColor)

    if (uiCfg.checkbox_checked_color != "" && pixelColor = ToUpper(uiCfg.checkbox_checked_color))
        return "checked"
    if (uiCfg.checkbox_unchecked_color != "" && pixelColor = ToUpper(uiCfg.checkbox_unchecked_color))
        return "unchecked"
    return "unknown"
}

WaitForCheckboxState(uiCfg, desiredState, timeoutMs, pollMs) {
    started := A_TickCount
    while (ElapsedMs(started) <= timeoutMs) {
        if (GetCheckboxState(uiCfg) = desiredState)
            return true
        Sleep, %pollMs%
    }
    return false
}

ApplyCheckboxAndSave(sysCfg, uiCfg) {
    if !WinExist(sysCfg.qr_window_title)
        return false

    qrTitle := sysCfg.qr_window_title
    if (uiCfg.checkbox_control != "")
        ControlClick, % uiCfg.checkbox_control, % qrTitle
    if (uiCfg.save_control != "")
        ControlClick, % uiCfg.save_control, % qrTitle

    if (uiCfg.save_result_pixel_x = "" || uiCfg.save_result_pixel_y = "")
        return true

    return WaitForSaveResult(uiCfg, ToInt(sysCfg.wait_save_timeout_ms, 5000), ToInt(sysCfg.default_poll_interval_ms, 200))
}

WaitForSaveResult(uiCfg, timeoutMs, pollMs) {
    started := A_TickCount
    while (ElapsedMs(started) <= timeoutMs) {
        PixelGetColor, pixelColor, % uiCfg.save_result_pixel_x, % uiCfg.save_result_pixel_y, RGB
        pixelColor := ToUpper(pixelColor)

        if (uiCfg.save_result_color != "" && pixelColor = ToUpper(uiCfg.save_result_color))
            return true
        if (uiCfg.save_result_pending_color != "" && pixelColor = ToUpper(uiCfg.save_result_pending_color)) {
            Sleep, %pollMs%
            continue
        }
        Sleep, %pollMs%
    }
    return false
}

MoveMainWindowIfNeeded(sysCfg, uiCfg) {
    mainWindowRef := ResolveMainWindowRef(sysCfg)
    if (mainWindowRef = "")
        return
    if (uiCfg.main_window_x = "" || uiCfg.main_window_y = "" || uiCfg.main_window_w = "" || uiCfg.main_window_h = "")
        return

    WinMove, % mainWindowRef, , % uiCfg.main_window_x, % uiCfg.main_window_y, % uiCfg.main_window_w, % uiCfg.main_window_h
}

WaitForWindow(windowTitle, timeoutMs, pollMs) {
    started := A_TickCount
    while (ElapsedMs(started) <= timeoutMs) {
        if WinExist(windowTitle)
            return true
        Sleep, %pollMs%
    }
    return false
}

WaitForAnyWindow(primaryTitle, secondaryTitle, timeoutMs, pollMs) {
    started := A_TickCount
    while (ElapsedMs(started) <= timeoutMs) {
        if WinExist(primaryTitle) || WinExist(secondaryTitle)
            return true
        Sleep, %pollMs%
    }
    return false
}

WaitForFitiStartupWindow(sysCfg, timeoutMs, pollMs) {
    started := A_TickCount
    while (ElapsedMs(started) <= timeoutMs) {
        if (ResolveLoginWindowRef(sysCfg) != "")
            return true
        if HasReadySessionWindow(sysCfg)
            return true
        Sleep, %pollMs%
    }
    return false
}

WaitForLoginWindow(sysCfg, timeoutMs, pollMs) {
    started := A_TickCount
    while (ElapsedMs(started) <= timeoutMs) {
        if (ResolveLoginWindowRef(sysCfg) != "")
            return true
        Sleep, %pollMs%
    }
    return false
}

ResolveLoginWindowRef(sysCfg) {
    if (sysCfg.login_window_title != "" && WinExist(sysCfg.login_window_title))
        return sysCfg.login_window_title
    if (sysCfg.qr_window_title != "" && WinExist(sysCfg.qr_window_title))
        return ""
    if (sysCfg.main_window_title != "" && WinExist(sysCfg.main_window_title))
        return ""
    return ""
}

ResolveMainWindowRef(sysCfg) {
    if (sysCfg.main_window_title != "" && WinExist(sysCfg.main_window_title))
        return sysCfg.main_window_title
    return ""
}

GetFirstFitiWindowRef(sysCfg, mode := "any") {
    windowRefs := GetFitiWindowRefsByProcess(sysCfg)
    for _, windowRef in windowRefs {
        if !WinExist(windowRef)
            continue
        WinGetTitle, currentTitle, % windowRef
        if (Trim(currentTitle) = "")
            continue

        if (mode = "login") {
            if (sysCfg.qr_window_title != "" && InStr(currentTitle, sysCfg.qr_window_title))
                continue
            if (sysCfg.main_window_title != "" && InStr(currentTitle, sysCfg.main_window_title))
                continue
        }

        if (mode = "main") {
            if (sysCfg.qr_window_title != "" && InStr(currentTitle, sysCfg.qr_window_title))
                continue
            if (sysCfg.login_window_title != "" && InStr(currentTitle, sysCfg.login_window_title))
                continue
        }

        return windowRef
    }
    return ""
}

GetFitiWindowRefsByProcess(sysCfg) {
    refs := []
    seen := {}
    processNames := GetKnownFitiProcessNames(sysCfg)

    for _, processName in processNames {
        processSelector := "ahk_exe " . processName
        WinGet, idList, List, % processSelector
        Loop, %idList%
        {
            hwnd := idList%A_Index%
            if !hwnd
                continue
            if seen.HasKey(hwnd . "")
                continue
            seen[hwnd . ""] := true
            refs.Push("ahk_id " . hwnd)
        }
    }

    return refs
}

GetKnownFitiProcessNames(sysCfg) {
    processNames := []
    seen := {}

    AddKnownFitiProcessName(processNames, seen, sysCfg.fiti_process_name)

    exeName := ""
    if (sysCfg.fiti_exe_path != "")
        SplitPath, % sysCfg.fiti_exe_path, exeName

    AddKnownFitiProcessName(processNames, seen, exeName)
    AddAlternateFitiProcessName(processNames, seen, sysCfg.fiti_process_name)
    AddAlternateFitiProcessName(processNames, seen, exeName)
    return processNames
}

AddKnownFitiProcessName(ByRef processNames, ByRef seen, processName) {
    processName := Trim(processName . "")
    if (processName = "")
        return

    normalized := ToLower(processName)
    if seen.HasKey(normalized)
        return

    seen[normalized] := true
    processNames.Push(processName)
}

AddAlternateFitiProcessName(ByRef processNames, ByRef seen, processName) {
    processName := Trim(processName . "")
    if (processName = "")
        return

    lowerName := ToLower(processName)
    if RegExMatch(lowerName, "\.exe$")
        AddKnownFitiProcessName(processNames, seen, RegExReplace(processName, "i)\.exe$", ".dll"))
    else if RegExMatch(lowerName, "\.dll$")
        AddKnownFitiProcessName(processNames, seen, RegExReplace(processName, "i)\.dll$", ".exe"))
}

CloseKnownFitiProcesses(sysCfg) {
    processNames := GetKnownFitiProcessNames(sysCfg)
    for _, processName in processNames {
        Process, Close, % processName
    }
}

DescribeTitleMatchedWindows(sysCfg) {
    description := ""
    titleGroups := [["login", sysCfg.login_window_title], ["main", sysCfg.main_window_title], ["qr", sysCfg.qr_window_title]]

    for _, pair in titleGroups {
        titleLabel := pair[1]
        windowTitle := pair[2]
        if (windowTitle = "")
            continue

        WinGet, idList, List, % windowTitle
        Loop, %idList%
        {
            hwnd := idList%A_Index%
            if !hwnd
                continue

            windowRef := "ahk_id " . hwnd
            WinGetTitle, currentTitle, % windowRef
            if (description != "")
                description .= " || "
            description .= titleLabel . ":" . hwnd . ":" . currentTitle
        }
    }

    return description = "" ? "no_title_window" : description
}

DescribeOpenFitiWindows(sysCfg) {
    processDescription := DescribeProcessMatchedWindows(sysCfg)
    titleProcessDescription := DescribeTitleWindowProcesses(sysCfg)
    return "proc=" . processDescription . " | title=" . DescribeTitleMatchedWindows(sysCfg) . " | title_proc=" . titleProcessDescription
}

DescribeProcessMatchedWindows(sysCfg) {
    description := ""
    windowRefs := GetFitiWindowRefsByProcess(sysCfg)
    for _, windowRef in windowRefs {
        if !WinExist(windowRef)
            continue

        WinGetTitle, currentTitle, % windowRef
        WinGet, windowPid, PID, % windowRef
        WinGet, processName, ProcessName, % windowRef
        if (description != "")
            description .= " || "
        description .= windowPid . ":" . processName . ":" . currentTitle
    }
    return description = "" ? "no_process_window" : description
}

DescribeTitleWindowProcesses(sysCfg) {
    description := ""
    knownRefs := ResolveKnownFitiWindowRefs(sysCfg)

    for _, windowRef in knownRefs {
        if (windowRef = "" || !WinExist(windowRef))
            continue

        WinGetTitle, currentTitle, % windowRef
        WinGet, windowPid, PID, % windowRef
        WinGet, processName, ProcessName, % windowRef
        if (description != "")
            description .= " || "
        description .= windowPid . ":" . processName . ":" . currentTitle
    }

    return description = "" ? "no_title_process_window" : description
}

ResolveKnownFitiWindowRefs(sysCfg) {
    refs := []
    knownTitles := [sysCfg.login_window_title, sysCfg.main_window_title, sysCfg.qr_window_title, "협조요청"]

    for _, windowTitle in knownTitles {
        if (windowTitle = "")
            continue

        WinGet, idList, List, % windowTitle
        Loop, %idList%
        {
            hwnd := idList%A_Index%
            if !hwnd
                continue
            refs.Push("ahk_id " . hwnd)
        }
    }

    return refs
}

RecordLoginDiagnostics(teamCfg, sysCfg, uiCfg, reason, preferredWindowRef := "", extraInfo := "") {
    diagWindowRef := ResolveLoginDiagnosticWindowRef(sysCfg, preferredWindowRef)
    diagLabel := teamCfg.team_name . "|" . reason

    AppendDebug("login_diag_state", diagLabel . "|" . DescribeOpenFitiWindows(sysCfg))

    userValue := ReadLoginUserForDiagnostics(sysCfg, uiCfg)
    if (userValue != "")
        AppendDebug("login_diag_user", diagLabel . "|user=" . userValue)

    if (extraInfo != "")
        AppendDebug("login_diag_extra", diagLabel . "|" . NormalizeDiagnosticText(extraInfo, 800))

    if (diagWindowRef != "") {
        AppendDebug("login_diag_window", diagLabel . "|" . DescribeWindowDiagnostics(diagWindowRef))

        controlInfo := DescribeWindowControls(diagWindowRef)
        if (controlInfo != "")
            AppendDebug("login_diag_controls", diagLabel . "|" . controlInfo)

        windowText := DescribeWindowTextForDiagnostics(diagWindowRef, 800)
        if (windowText != "")
            AppendDebug("login_diag_text", diagLabel . "|" . windowText)
    }

    popupRef := ResolveUnexpectedFitiWindowRef(sysCfg)
    if (popupRef != "" && popupRef != diagWindowRef)
        AppendDebug("login_diag_popup", diagLabel . "|" . DescribeWindowDiagnostics(popupRef))

    screenshotPath := CaptureDiagnosticScreenshot(SanitizeFileName(teamCfg.team_name . "_" . reason), diagWindowRef)
    if (screenshotPath != "")
        AppendDebug("login_diag_screenshot", diagLabel . "|" . screenshotPath)
}

ResolveLoginDiagnosticWindowRef(sysCfg, preferredWindowRef := "") {
    if (preferredWindowRef != "" && WinExist(preferredWindowRef))
        return preferredWindowRef

    popupRef := ResolveUnexpectedFitiWindowRef(sysCfg)
    if (popupRef != "")
        return popupRef

    loginWindowRef := ResolveLoginWindowRef(sysCfg)
    if (loginWindowRef != "")
        return loginWindowRef

    readyWindowRef := ResolveReadySessionWindowRef(sysCfg)
    if (readyWindowRef != "")
        return readyWindowRef

    return ""
}

ReadLoginUserForDiagnostics(sysCfg, uiCfg) {
    loginWindowRef := ResolveLoginWindowRef(sysCfg)
    if (loginWindowRef = "")
        return ""
    if (uiCfg.login_user_control = "")
        return ""
    return MaskLoginValue(SafeReadLoginField(loginWindowRef, uiCfg.login_user_control))
}

DescribeWindowDiagnostics(windowRef) {
    if (windowRef = "" || !WinExist(windowRef))
        return "window_missing"

    WinGetTitle, windowTitle, % windowRef
    WinGetClass, windowClass, % windowRef
    WinGet, windowPid, PID, % windowRef
    WinGet, processName, ProcessName, % windowRef
    return "ref=" . windowRef . "|title=" . NormalizeDiagnosticText(windowTitle, 200) . "|class=" . windowClass . "|pid=" . windowPid . "|process=" . processName
}

DescribeWindowControls(windowRef) {
    if (windowRef = "" || !WinExist(windowRef))
        return ""

    controlList := ""
    WinGet, controlList, ControlList, % windowRef
    return NormalizeDiagnosticText(StrReplace(controlList, "`n", "|"), 800)
}

DescribeWindowTextForDiagnostics(windowRef, maxLen := 500) {
    if (windowRef = "" || !WinExist(windowRef))
        return ""
    return NormalizeDiagnosticText(MaskSensitiveDiagnosticText(ReadWindowText(windowRef)), maxLen)
}

NormalizeDiagnosticText(text, maxLen := 500) {
    text := RegExReplace(Trim(text . ""), "\s+", " ")
    if (text = "")
        return ""
    if (StrLen(text) <= maxLen)
        return text
    return SubStr(text, 1, maxLen) . "...(truncated)"
}

MaskSensitiveDiagnosticText(text) {
    global g_Runtime
    masked := text . ""

    if IsObject(g_Runtime) && IsObject(g_Runtime.cfg) {
        for _, section in ["team.analysis", "team.processing"] {
            if !g_Runtime.cfg.HasKey(section)
                continue

            teamCfg := g_Runtime.cfg[section]
            if IsObject(teamCfg) {
                masked := ReplaceMaskedSecret(masked, teamCfg.login_id)
                masked := ReplaceMaskedSecret(masked, teamCfg.login_password)
            }
        }
    }

    masked := RegExReplace(masked, "(\b[A-Za-z]{1,3}\d{5,}\b)", Func("MaskRegexToken"))
    masked := RegExReplace(masked, "([A-Za-z0-9]{4,}[!@#$%^&*()_+\-=\[\]{};':"",.<>/?\\|`~]+[A-Za-z0-9!@#$%^&*()_+\-=\[\]{};':"",.<>/?\\|`~]{2,})", Func("MaskRegexToken"))
    return masked
}

ReplaceMaskedSecret(sourceText, secretValue) {
    secretValue := secretValue . ""
    if (Trim(secretValue) = "")
        return sourceText
    return StrReplace(sourceText, secretValue, MaskLoginValue(secretValue))
}

MaskRegexToken(match) {
    return MaskLoginValue(match.Value)
}

CloseFiti(sysCfg) {
    WinClose, % sysCfg.qr_window_title
    WinClose, % sysCfg.main_window_title
    WinClose, % sysCfg.login_window_title
    Sleep, 500
    CloseKnownFitiProcesses(sysCfg)
}

GetCurrentTeamReloginCount() {
    global g_Runtime
    if !IsObject(g_Runtime.currentTeamStats)
        return 0
    return g_Runtime.currentTeamStats.relogin_count
}

IncrementTeamReloginCount() {
    global g_Runtime
    if !IsObject(g_Runtime.currentTeamStats)
        g_Runtime.currentTeamStats := {}
    if !g_Runtime.currentTeamStats.HasKey("relogin_count")
        g_Runtime.currentTeamStats.relogin_count := 0
    g_Runtime.currentTeamStats.relogin_count += 1
}

MaskLoginValue(value) {
    value := Trim(value . "")
    if (value = "" || value = "window_closed" || value = "read_failed")
        return value

    valueLen := StrLen(value)
    if (valueLen <= 4)
        return SubStr("****", 1, valueLen)

    return SubStr(value, 1, 2) . "***" . SubStr(value, valueLen - 1)
}

TryFocusControl(windowTitle, controlName, debugCode := "control_focus_error") {
    if (controlName = "")
        return false
    if !WinExist(windowTitle) {
        AppendDebug(debugCode, controlName . "|window_missing|" . windowTitle)
        return false
    }

    try {
        ControlFocus, % controlName, % windowTitle
        Sleep, 100
        return true
    } catch e {
        AppendDebug(debugCode, controlName . "|" . DescribeException(e))
        return false
    }
}

SetLoginFieldValue(windowTitle, controlName, value, verifyText := true) {
    if (controlName = "")
        return false

    writeOk := false
    TryFocusControl(windowTitle, controlName, "login_field_focus_error")

    try {
        ControlSetText, % controlName, , % windowTitle
        Sleep, 100
        ControlSetText, % controlName, % value, % windowTitle
        Sleep, 100
        writeOk := true
    } catch e {
        AppendDebug("login_settext_error", controlName . "|" . DescribeException(e))
    }

    if (!verifyText && writeOk)
        return true

    actual := SafeReadLoginField(windowTitle, controlName)
    if (actual = value)
        return true

    try {
        Control, EditPaste, % value, % controlName, % windowTitle
        Sleep, 100
        writeOk := true
    } catch e {
        AppendDebug("login_editpaste_error", controlName . "|" . DescribeException(e))
    }

    if (!verifyText && writeOk)
        return true

    actual := SafeReadLoginField(windowTitle, controlName)
    if (actual = value)
        return true

    if !TryFocusControl(windowTitle, controlName, "login_field_refocus_error")
        return false

    try {
        ControlSend, % controlName, ^a{Del}, % windowTitle
        Sleep, 100
        ControlSend, % controlName, {Raw}%value%, % windowTitle
        Sleep, 150
        writeOk := true
    } catch e {
        AppendDebug("login_controlsend_error", controlName . "|" . DescribeException(e))
        return false
    }

    if (!verifyText)
        return writeOk

    actual := SafeReadLoginField(windowTitle, controlName)
    return (actual = value)
}

ReadLoginField(windowTitle, controlName) {
    currentValue := ""
    ControlGetText, currentValue, % controlName, % windowTitle
    return Trim(currentValue)
}

SafeReadLoginField(windowTitle, controlName) {
    if !WinExist(windowTitle)
        return "window_closed"

    try {
        return ReadLoginField(windowTitle, controlName)
    } catch e {
        AppendDebug("login_read_error", controlName . "|" . DescribeException(e))
        return "read_failed"
    }
}

SubmitLogin(windowTitle, uiCfg) {
    if (uiCfg.login_submit_button != "") {
        TryClickLoginButton(windowTitle, uiCfg.login_submit_button, uiCfg.login_password_control)
        return
    }
    if TryClickLoginButton(windowTitle, "Button1", uiCfg.login_password_control)
        return
    if TryClickLoginButton(windowTitle, "ThunderRT6CommandButton1", uiCfg.login_password_control)
        return

    if !TryFocusControl(windowTitle, uiCfg.login_password_control, "login_submit_focus_error")
        return

    try {
        ControlSend, % uiCfg.login_password_control, {Enter}, % windowTitle
        Sleep, 150
    } catch e {
        AppendDebug("login_submit_send_error", DescribeException(e))
    }
}

TryClickLoginButton(windowTitle, buttonName, passwordControl := "") {
    if (buttonName = "")
        return false

    AppendDebug("login_submit_try", buttonName)

    controlHwnd := ""
    try {
        ControlGet, controlHwnd, Hwnd,, % buttonName, % windowTitle
    } catch e {
        AppendDebug("login_submit_hwnd_error", buttonName . "|" . DescribeException(e))
    }

    if (controlHwnd != "")
        AppendDebug("login_submit_hwnd", buttonName . "|" . controlHwnd)

    try {
        ControlClick, % buttonName, % windowTitle,,,, NA
        Sleep, 250
        if !WinExist(windowTitle)
            return true
    } catch e {
        AppendDebug("login_submit_click_error", buttonName . "|" . DescribeException(e))
    }

    if (passwordControl != "") {
        if TryFocusControl(windowTitle, passwordControl, "login_submit_focus_error") {
            try {
            ControlSend, % passwordControl, {Enter}, % windowTitle
            Sleep, 250
            if !WinExist(windowTitle)
                return true
            } catch e {
                AppendDebug("login_submit_enter_error", buttonName . "|" . DescribeException(e))
            }
        }
    }

    return false
}

WaitForLoginOutcome(sysCfg, uiCfg, timeoutMs, pollMs) {
    started := A_TickCount
    loginClosedLogged := false
    processMissingLogged := false
    overlapLogged := false
    while (ElapsedMs(started) <= timeoutMs) {
        popupRef := ResolveUnexpectedFitiWindowRef(sysCfg)
        if (popupRef != "") {
            popupInfo := DescribeUnexpectedFitiWindow(sysCfg)
            AppendDebug("login_modal_popup", popupInfo)
            if DismissUnexpectedFitiWindow(sysCfg, uiCfg) {
                Sleep, %pollMs%
                continue
            }
            return "modal"
        }

        loginExists := WinExist(sysCfg.login_window_title)
        qrExists := (sysCfg.qr_window_title != "" && WinExist(sysCfg.qr_window_title))
        mainExists := qrExists || HasReadySessionWindow(sysCfg)

        if (loginExists) {
            noticeText := DetectEmbeddedLoginNotice(sysCfg)
            if (noticeText != "") {
                AppendDebug("login_notice_embedded", noticeText)
                if DismissEmbeddedLoginNotice(sysCfg, uiCfg) {
                    Sleep, %pollMs%
                    continue
                }
            }
        }

        if qrExists
            return "qr"

        if (mainExists && !loginExists)
            return "main"

        if (mainExists && loginExists && !overlapLogged) {
            AppendDebug("login_wait_overlap", DescribeOpenFitiWindows(sysCfg))
            overlapLogged := true
        }

        if !IsFitiProcessRunning(sysCfg) {
            if !processMissingLogged {
                AppendDebug("login_wait_process_missing", DescribeOpenFitiWindows(sysCfg))
                processMissingLogged := true
            }
        }

        if !loginExists {
            if !loginClosedLogged {
                AppendDebug("login_wait_login_closed", DescribeOpenFitiWindows(sysCfg))
                loginClosedLogged := true
            }
        }

        Sleep, %pollMs%
    }

    if (sysCfg.qr_window_title != "" && WinExist(sysCfg.qr_window_title))
        return "qr"
    if WinExist(sysCfg.main_window_title)
        return "main"
    if !WinExist(sysCfg.login_window_title) {
        if WaitForReadySessionWindow(sysCfg, 2000, pollMs) {
            if (sysCfg.qr_window_title != "" && WinExist(sysCfg.qr_window_title))
                return "qr"
            return "main"
        }
    }
    if !IsFitiProcessRunning(sysCfg)
        return "process_closed"
    if !WinExist(sysCfg.login_window_title)
        return "login_closed"
    return "timeout"
}

HandleImmediatePostLoginNotice(sysCfg, uiCfg, timeoutMs, pollMs) {
    started := A_TickCount
    while (ElapsedMs(started) <= timeoutMs) {
        popupRef := ResolveUnexpectedFitiWindowRef(sysCfg)
        if (popupRef != "") {
            popupInfo := DescribeUnexpectedFitiWindow(sysCfg)
            AppendDebug("login_notice_fast", popupInfo)
            if DismissUnexpectedFitiWindow(sysCfg, uiCfg) {
                Sleep, %pollMs%
                return true
            }
        }

        noticeText := DetectEmbeddedLoginNotice(sysCfg)
        if (noticeText != "") {
            AppendDebug("login_notice_fast_embedded", noticeText)
            if DismissEmbeddedLoginNotice(sysCfg, uiCfg) {
                Sleep, %pollMs%
                return true
            }
        }

        if HasReadySessionWindow(sysCfg)
            return false

        Sleep, %pollMs%
    }
    return false
}

ContainsLoginNoticeText(sourceText) {
    normalized := RegExReplace(Trim(sourceText), "\s+", " ")
    if (normalized = "")
        return false
    if InStr(normalized, "협조요청")
        return true
    if InStr(normalized, "전산 사용이 집중되는")
        return true
    if InStr(normalized, "조회시간이 오래 걸리는 통계작업")
        return true
    if InStr(normalized, "전산부서로 요청")
        return true
    return false
}

FindNoticeDialogRef(selector) {
    WinGet, idList, List, % selector
    Loop, %idList%
    {
        hwnd := idList%A_Index%
        if !hwnd
            continue

        windowRef := "ahk_id " . hwnd
        WinGetTitle, popupTitle, % windowRef
        popupText := ReadWindowText(windowRef)
        if ContainsLoginNoticeText(popupTitle . " " . popupText)
            return windowRef
    }
    return ""
}

DetectEmbeddedLoginNotice(sysCfg) {
    loginWindowRef := ResolveLoginWindowRef(sysCfg)
    if (loginWindowRef = "")
        return ""

    popupText := ReadWindowText(loginWindowRef)
    if !ContainsLoginNoticeText(popupText)
        return ""
    return RegExReplace(Trim(popupText), "\s+", " ")
}

DismissEmbeddedLoginNotice(sysCfg, uiCfg) {
    loginWindowRef := ResolveLoginWindowRef(sysCfg)
    if (loginWindowRef = "")
        return false

    buttonName := uiCfg.dialog_confirm_button
    if (buttonName != "") {
        try {
            ControlClick, % buttonName, % loginWindowRef
            Sleep, 300
            if (DetectEmbeddedLoginNotice(sysCfg) = "")
                return true
        } catch e {
            AppendDebug("login_notice_click_error", DescribeException(e))
        }
    }

    try {
        WinActivate, % loginWindowRef
        WinWaitActive, % loginWindowRef, , 2
        SendInput, {Enter}
        Sleep, 300
        return (DetectEmbeddedLoginNotice(sysCfg) = "")
    } catch e {
        AppendDebug("login_notice_enter_error", DescribeException(e))
    }
    return false
}

ReadWindowText(windowRef) {
    popupText := ""
    if (windowRef = "")
        return popupText
    try {
        WinGetText, popupText, % windowRef
    } catch e {
        return ""
    }
    return popupText
}

ResolveUnexpectedFitiWindowRef(sysCfg) {
    if WinExist("협조요청")
        return "협조요청"

    dialogRef := FindNoticeDialogRef("ahk_class #32770")
    if (dialogRef != "")
        return dialogRef

    windowRefs := GetFitiWindowRefsByProcess(sysCfg)
    for _, windowRef in windowRefs {
        if !WinExist(windowRef)
            continue
        WinGetTitle, currentTitle, % windowRef
        currentTitle := Trim(currentTitle)
        if (currentTitle = "")
            continue
        if (sysCfg.login_window_title != "" && InStr(currentTitle, sysCfg.login_window_title))
            continue
        if (sysCfg.main_window_title != "" && InStr(currentTitle, sysCfg.main_window_title))
            continue
        if (sysCfg.qr_window_title != "" && InStr(currentTitle, sysCfg.qr_window_title))
            continue
        return windowRef
    }
    return ""
}

DescribeUnexpectedFitiWindow(sysCfg) {
    popupRef := ResolveUnexpectedFitiWindowRef(sysCfg)
    if (popupRef = "")
        return "unexpected_window_not_found"

    popupTitle := ""
    popupText := ""
    WinGetTitle, popupTitle, % popupRef
    WinGetText, popupText, % popupRef
    popupText := RegExReplace(Trim(popupText), "\s+", " ")
    return popupTitle . "|" . popupText
}

DismissUnexpectedFitiWindow(sysCfg, uiCfg) {
    popupRef := ResolveUnexpectedFitiWindowRef(sysCfg)
    if (popupRef = "")
        return false

    buttonName := uiCfg.dialog_confirm_button
    if (buttonName != "") {
        try {
            ControlClick, % buttonName, % popupRef
            Sleep, 250
            if !WinExist(popupRef) {
                PostDismissDialogInput(sysCfg, uiCfg)
                return true
            }
        } catch e {
            AppendDebug("dialog_confirm_click_error", DescribeException(e))
        }
    }

    try {
        WinActivate, % popupRef
        WinWaitActive, % popupRef, , 2
        SendInput, {Enter}
        Sleep, 250
        if !WinExist(popupRef) {
            PostDismissDialogInput(sysCfg, uiCfg)
            return true
        }
    } catch e {
        AppendDebug("dialog_confirm_enter_error", DescribeException(e))
    }

    return false
}

PostDismissDialogInput(sysCfg, uiCfg) {
    postKeys := uiCfg.dialog_post_confirm_keys
    if (postKeys = "")
        return

    delayMs := ToInt(uiCfg.dialog_post_confirm_delay_ms, 500)
    if (delayMs > 0)
        Sleep, %delayMs%

    targetWindow := ResolveMainWindowRef(sysCfg)
    if (targetWindow = "")
        targetWindow := ResolveLoginWindowRef(sysCfg)
    if (targetWindow = "")
        return

    try {
        WinActivate, % targetWindow
        WinWaitActive, % targetWindow, , 2
        AppendDebug("dialog_post_confirm_keys", postKeys)
        SendInput, % postKeys
    } catch e {
        AppendDebug("dialog_post_confirm_error", DescribeException(e))
    }
}

IsFitiProcessRunning(sysCfg) {
    if HasKnownFitiWindows(sysCfg)
        return true

    processNames := GetKnownFitiProcessNames(sysCfg)
    for _, processName in processNames {
        Process, Exist, % processName
        if (ErrorLevel != 0)
            return true
    }
    return false
}

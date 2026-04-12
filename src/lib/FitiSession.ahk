CloseExistingFitiIfNeeded(sysCfg) {
    if !IsTrue(sysCfg.close_existing_fiti_before_run)
        return

    WinClose, % sysCfg.qr_window_title
    WinClose, % sysCfg.main_window_title
    WinClose, % sysCfg.login_window_title
    Sleep, 500
    Process, Close, % sysCfg.fiti_process_name
    Sleep, 500
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
    if WinExist(sysCfg.main_window_title) && !WinExist(sysCfg.login_window_title) {
        MoveMainWindowIfNeeded(sysCfg, uiCfg)
        return true
    }

    if !WaitForLoginWindow(sysCfg, ToInt(sysCfg.wait_login_timeout_ms, 12000), ToInt(sysCfg.default_poll_interval_ms, 200)) {
        AppendDebug("login_window_missing", teamCfg.team_name . "|" . DescribeOpenFitiWindows(sysCfg))
        return WinExist(sysCfg.main_window_title)
    }

    loginWindowRef := ResolveLoginWindowRef(sysCfg)
    if (loginWindowRef = "") {
        AppendDebug("login_window_unresolved", teamCfg.team_name . "|" . DescribeOpenFitiWindows(sysCfg))
        return WinExist(sysCfg.main_window_title)
    }

    WinActivate, % loginWindowRef
    WinWaitActive, % loginWindowRef, , 3

    AppendDebug("login_begin", teamCfg.team_name . "|" . teamCfg.login_id)

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

    AppendDebug("login_wait_main", sysCfg.main_window_title)
    loginOutcome := WaitForLoginOutcome(sysCfg, uiCfg, ToInt(sysCfg.wait_main_timeout_ms, 12000), ToInt(sysCfg.default_poll_interval_ms, 200))
    if (loginOutcome = "main") {
        MoveMainWindowIfNeeded(sysCfg, uiCfg)
        AppendDebug("login_success", teamCfg.team_name)
        return true
    }

    if (loginOutcome = "modal") {
        popupInfo := DescribeUnexpectedFitiWindow(sysCfg)
        AppendDebug("login_modal_unhandled", popupInfo)
        return false
    }

    if (loginOutcome = "process_closed") {
        AppendDebug("login_process_closed", teamCfg.team_name . "|" . DescribeOpenFitiWindows(sysCfg))
        return false
    }

    if (loginOutcome = "login_closed") {
        AppendDebug("login_window_closed_without_main", teamCfg.team_name . "|" . DescribeOpenFitiWindows(sysCfg))
        return false
    }

    if !WaitForWindow(sysCfg.main_window_title, 1, 1) {
        userText := SafeReadLoginField(loginWindowRef, uiCfg.login_user_control)
        AppendDebug("login_main_timeout", teamCfg.team_name . "|user=" . userText . "|" . DescribeOpenFitiWindows(sysCfg))
        return false
    }
    return false
}

EnsureQrWindow(sysCfg, uiCfg) {
    if WinExist(sysCfg.qr_window_title)
        return true
    if !WinExist(sysCfg.main_window_title)
        return false

    WinActivate, % sysCfg.main_window_title
    WinWaitActive, % sysCfg.main_window_title, , 3
    MoveMainWindowIfNeeded(sysCfg, uiCfg)

    clickCount := ToInt(uiCfg.qr_button_click_count, 2)
    waitMs := ToInt(uiCfg.qr_button_wait_ms, 400)

    Loop, %clickCount%
    {
        MouseClick, left, % uiCfg.qr_button_x, % uiCfg.qr_button_y, 1, 0
        Sleep, %waitMs%
        if WinExist(sysCfg.qr_window_title)
            return true
    }

    return WaitForWindow(sysCfg.qr_window_title, ToInt(sysCfg.wait_qr_window_timeout_ms, 8000), ToInt(sysCfg.default_poll_interval_ms, 200))
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
        if (ResolveMainWindowRef(sysCfg) != "")
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
        if WinExist(sysCfg.main_window_title)
            return false
        Sleep, %pollMs%
    }
    return false
}

ResolveLoginWindowRef(sysCfg) {
    if (sysCfg.login_window_title != "" && WinExist(sysCfg.login_window_title))
        return sysCfg.login_window_title
    return GetFirstFitiWindowRef(sysCfg, "login")
}

ResolveMainWindowRef(sysCfg) {
    if (sysCfg.main_window_title != "" && WinExist(sysCfg.main_window_title))
        return sysCfg.main_window_title
    return GetFirstFitiWindowRef(sysCfg, "main")
}

GetFirstFitiWindowRef(sysCfg, mode := "any") {
    processSelector := "ahk_exe " . sysCfg.fiti_process_name
    WinGet, idList, List, % processSelector
    Loop, %idList%
    {
        hwnd := idList%A_Index%
        if !hwnd
            continue

        windowRef := "ahk_id " . hwnd
        WinGetTitle, currentTitle, % windowRef
        if (Trim(currentTitle) = "")
            continue

        if (mode = "login" && sysCfg.qr_window_title != "" && InStr(currentTitle, sysCfg.qr_window_title))
            continue

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

DescribeOpenFitiWindows(sysCfg) {
    processSelector := "ahk_exe " . sysCfg.fiti_process_name
    WinGet, idList, List, % processSelector
    if (idList = 0)
        return "no_process_window"

    description := ""
    Loop, %idList%
    {
        hwnd := idList%A_Index%
        if !hwnd
            continue

        windowRef := "ahk_id " . hwnd
        WinGetTitle, currentTitle, % windowRef
        if (description != "")
            description .= " || "
        description .= hwnd . ":" . currentTitle
    }

    return description = "" ? "no_process_window" : description
}

CloseFiti(sysCfg) {
    WinClose, % sysCfg.qr_window_title
    WinClose, % sysCfg.main_window_title
    WinClose, % sysCfg.login_window_title
    Sleep, 500
    Process, Close, % sysCfg.fiti_process_name
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

SetLoginFieldValue(windowTitle, controlName, value, verifyText := true) {
    if (controlName = "")
        return false

    ControlFocus, % controlName, % windowTitle
    Sleep, 100

    ControlSetText, % controlName, , % windowTitle
    Sleep, 100
    ControlSetText, % controlName, % value, % windowTitle
    Sleep, 100

    if (!verifyText)
        return true

    actual := ReadLoginField(windowTitle, controlName)
    if (actual = value)
        return true

    Control, EditPaste, % value, % controlName, % windowTitle
    Sleep, 100
    actual := ReadLoginField(windowTitle, controlName)
    if (actual = value)
        return true

    ControlFocus, % controlName, % windowTitle
    Sleep, 100
    ControlSend, % controlName, ^a{Del}, % windowTitle
    Sleep, 100
    ControlSend, % controlName, {Raw}%value%, % windowTitle
    Sleep, 150
    actual := ReadLoginField(windowTitle, controlName)
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

    ControlFocus, % uiCfg.login_password_control, % windowTitle
    Sleep, 100
    ControlSend, % uiCfg.login_password_control, {Enter}, % windowTitle
    Sleep, 150
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
        try {
            ControlFocus, % passwordControl, % windowTitle
            Sleep, 100
            ControlSend, % passwordControl, {Enter}, % windowTitle
            Sleep, 250
            if !WinExist(windowTitle)
                return true
        } catch e {
            AppendDebug("login_submit_enter_error", buttonName . "|" . DescribeException(e))
        }
    }

    return false
}

WaitForLoginOutcome(sysCfg, uiCfg, timeoutMs, pollMs) {
    started := A_TickCount
    while (ElapsedMs(started) <= timeoutMs) {
        if WinExist(sysCfg.main_window_title)
            return "main"

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

        if (ResolveMainWindowRef(sysCfg) != "")
            return "main"

        if !IsFitiProcessRunning(sysCfg)
            return "process_closed"

        if !WinExist(sysCfg.login_window_title)
            return "login_closed"

        Sleep, %pollMs%
    }

    return "timeout"
}

ResolveUnexpectedFitiWindowRef(sysCfg) {
    processSelector := "ahk_exe " . sysCfg.fiti_process_name
    WinGet, idList, List, % processSelector
    Loop, %idList%
    {
        hwnd := idList%A_Index%
        if !hwnd
            continue

        windowRef := "ahk_id " . hwnd
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
    Process, Exist, % sysCfg.fiti_process_name
    return (ErrorLevel != 0)
}

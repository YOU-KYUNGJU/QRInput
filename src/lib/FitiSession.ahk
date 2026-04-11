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

    if !WaitForAnyWindow(sysCfg.login_window_title, sysCfg.main_window_title, ToInt(sysCfg.wait_main_timeout_ms, 12000), ToInt(sysCfg.default_poll_interval_ms, 200)) {
        AppendDebug("fiti_start_timeout", sysCfg.main_window_title)
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

    if !WaitForWindow(sysCfg.login_window_title, ToInt(sysCfg.wait_login_timeout_ms, 12000), ToInt(sysCfg.default_poll_interval_ms, 200)) {
        AppendDebug("login_window_missing", teamCfg.team_name)
        return WinExist(sysCfg.main_window_title)
    }

    WinActivate, % sysCfg.login_window_title
    WinWaitActive, % sysCfg.login_window_title, , 3

    ControlSetText, % uiCfg.login_user_control, % teamCfg.login_id, % sysCfg.login_window_title
    ControlSetText, % uiCfg.login_password_control, % teamCfg.login_password, % sysCfg.login_window_title

    if (uiCfg.login_submit_button != "")
        ControlClick, % uiCfg.login_submit_button, % sysCfg.login_window_title
    else
        SendInput, {Enter}

    postKeys := uiCfg.login_post_submit_keys
    if (postKeys != "") {
        Sleep, 300
        SendInput, % postKeys
    }

    if !WaitForWindow(sysCfg.main_window_title, ToInt(sysCfg.wait_main_timeout_ms, 12000), ToInt(sysCfg.default_poll_interval_ms, 200)) {
        AppendDebug("login_main_timeout", teamCfg.team_name)
        return false
    }

    MoveMainWindowIfNeeded(sysCfg, uiCfg)
    return true
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
    pixelColor := StrUpper(pixelColor)

    if (uiCfg.checkbox_checked_color != "" && pixelColor = StrUpper(uiCfg.checkbox_checked_color))
        return "checked"
    if (uiCfg.checkbox_unchecked_color != "" && pixelColor = StrUpper(uiCfg.checkbox_unchecked_color))
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
        pixelColor := StrUpper(pixelColor)

        if (uiCfg.save_result_color != "" && pixelColor = StrUpper(uiCfg.save_result_color))
            return true
        if (uiCfg.save_result_pending_color != "" && pixelColor = StrUpper(uiCfg.save_result_pending_color)) {
            Sleep, %pollMs%
            continue
        }
        Sleep, %pollMs%
    }
    return false
}

MoveMainWindowIfNeeded(sysCfg, uiCfg) {
    if !WinExist(sysCfg.main_window_title)
        return
    if (uiCfg.main_window_x = "" || uiCfg.main_window_y = "" || uiCfg.main_window_w = "" || uiCfg.main_window_h = "")
        return

    WinMove, % sysCfg.main_window_title, , % uiCfg.main_window_x, % uiCfg.main_window_y, % uiCfg.main_window_w, % uiCfg.main_window_h
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

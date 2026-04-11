LoadConfig(path) {
    if !FileExist(path)
        throw Exception("config_not_found: " . path)

    cfg := {}
    cfg._path := path
    cfg.system := LoadIniSection(path, "system")
    cfg.ui := LoadIniSection(path, "ui")
    cfg["team.analysis"] := LoadIniSection(path, "team.analysis")
    cfg["team.processing"] := LoadIniSection(path, "team.processing")
    NormalizeConfig(cfg, path)
    return cfg
}

LoadIniSection(path, section) {
    obj := {}
    keys := GetSectionKeys(section)
    for _, key in keys {
        IniRead, value, %path%, %section%, %key%, %A_Space%
        obj[key] := Trim(value)
    }
    return obj
}

GetSectionKeys(section) {
    if (section = "system")
        return ["app_name","fiti_exe_path","login_window_title","main_window_title","qr_window_title","fiti_process_name","max_relogin_count","max_row_retry_count","close_existing_fiti_before_run","close_fiti_after_team_run","keep_source_csv","use_lock_file","lock_file_path","history_dir","run_log_dir","debug_log_enabled","debug_log_dir","success_screenshot_enabled","failure_screenshot_enabled","default_wait_timeout_ms","default_poll_interval_ms","wait_login_timeout_ms","wait_main_timeout_ms","wait_qr_window_timeout_ms","wait_save_timeout_ms"]

    if (section = "ui")
        return ["main_window_x","main_window_y","main_window_w","main_window_h","dpi_scale","login_user_control","login_password_control","login_submit_button","login_post_submit_keys","qr_button_x","qr_button_y","qr_button_click_count","qr_button_wait_ms","qr_verify_controls","checkbox_pixel_x","checkbox_pixel_y","checkbox_checked_color","checkbox_unchecked_color","checkbox_control","save_control","post_save_control","save_result_pixel_x","save_result_pixel_y","save_result_color","save_result_pending_color"]

    if (section = "team.analysis" or section = "team.processing")
        return ["enabled","team_name","part_name","login_id","login_password","csv_root_path","receipt_mode","receipt_compose_columns","receipt_direct_column","row_scan_column","row_scan_pattern","cutoff_hour","allow_future_folder","file_select_policy","file_created_after_hour","postprocess_mode","failure_policy","stop_on_check_failure","move_processed_file","processed_file_dir","log_dir","screenshot_dir"]

    return []
}

NormalizeConfig(ByRef cfg, path) {
    configDir := GetParentDir(path)
    repoRoot := GetParentDir(configDir)
    cfg.system.repo_root := repoRoot

    for _, key in ["fiti_exe_path","lock_file_path","history_dir","run_log_dir","debug_log_dir"] {
        cfg.system[key] := ResolveConfigPath(cfg.system[key], repoRoot)
    }

    for _, section in ["team.analysis", "team.processing"] {
        teamCfg := cfg[section]
        for _, key in ["csv_root_path","processed_file_dir","log_dir","screenshot_dir"] {
            teamCfg[key] := ResolveConfigPath(teamCfg[key], repoRoot)
        }
        cfg[section] := teamCfg
    }

    if (cfg.system.app_name = "")
        cfg.system.app_name := "QRinputUnified"
    if (cfg.system.fiti_process_name = "")
        cfg.system.fiti_process_name := "fiti.exe"
    if (cfg.system.default_wait_timeout_ms = "")
        cfg.system.default_wait_timeout_ms := "7000"
    if (cfg.system.default_poll_interval_ms = "")
        cfg.system.default_poll_interval_ms := "200"
    if (cfg.system.wait_login_timeout_ms = "")
        cfg.system.wait_login_timeout_ms := cfg.system.default_wait_timeout_ms
    if (cfg.system.wait_main_timeout_ms = "")
        cfg.system.wait_main_timeout_ms := cfg.system.default_wait_timeout_ms
    if (cfg.system.wait_qr_window_timeout_ms = "")
        cfg.system.wait_qr_window_timeout_ms := cfg.system.default_wait_timeout_ms
    if (cfg.system.wait_save_timeout_ms = "")
        cfg.system.wait_save_timeout_ms := cfg.system.default_wait_timeout_ms

    if (cfg.ui.login_user_control = "")
        cfg.ui.login_user_control := "ThunderRT6TextBox1"
    if (cfg.ui.login_password_control = "")
        cfg.ui.login_password_control := "ThunderRT6TextBox2"
    if (cfg.ui.qr_button_click_count = "")
        cfg.ui.qr_button_click_count := "2"
    if (cfg.ui.qr_button_wait_ms = "")
        cfg.ui.qr_button_wait_ms := "400"
    if (cfg.ui.qr_verify_controls = "")
        cfg.ui.qr_verify_controls := "ThunderRT6TextBox2|ThunderRT6TextBox3|ThunderRT6TextBox4|ThunderRT6TextBox5"
}

ResolveConfigPath(value, baseDir) {
    value := Trim(value)
    if (value = "")
        return ""
    if IsAbsolutePath(value)
        return value

    value := StrReplace(value, "/", "\")
    if (SubStr(value, 1, 2) = ".\")
        return baseDir "\" SubStr(value, 3)
    if (SubStr(value, 1, 3) = "..\")
        return baseDir "\" value
    return baseDir "\" value
}

IsAbsolutePath(path) {
    return RegExMatch(path, "i)^[A-Z]:\\") || (SubStr(path, 1, 2) = "\\")
}

GetParentDir(path) {
    SplitPath, path, , parentDir
    return parentDir
}

ToInt(value, defaultValue := 0) {
    value := Trim(value)
    if RegExMatch(value, "^-?\d+$")
        return value + 0
    return defaultValue
}

IsTrue(value) {
    value := StrLower(Trim(value))
    return (value = "true" or value = "1" or value = "yes" or value = "y")
}

DirExists(path) {
    return (path != "" && InStr(FileExist(path), "D"))
}

EnsureDir(path) {
    if (path = "")
        return
    if !DirExists(path)
        FileCreateDir, %path%
}

NowIso() {
    FormatTime, ts,, yyyy-MM-dd HH:mm:ss
    return ts
}

NowFileStamp() {
    FormatTime, ts,, yyyyMMdd_HHmmss
    return ts
}

ElapsedMs(startTick) {
    return A_TickCount - startTick
}

SanitizeFileName(text) {
    text := RegExReplace(text, "[\\/:*?""<>|]", "_")
    text := RegExReplace(text, "\s+", "_")
    return Trim(text, "_")
}

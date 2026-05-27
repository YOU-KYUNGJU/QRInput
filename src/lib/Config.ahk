LoadConfig(path) {
    if !FileExist(path)
        throw Exception("config_not_found: " . path)

    iniData := ParseIniFile(path)
    cfg := {}
    cfg._path := path
    cfg.system := LoadIniSectionData(iniData, "system")
    cfg.ui := LoadIniSectionData(iniData, "ui")
    cfg._team_sections := []
    for _, sectionName in GetTeamSectionNames(iniData) {
        cfg[sectionName] := LoadIniSectionData(iniData, sectionName)
        cfg[sectionName]._section_name := sectionName
        cfg._team_sections.Push(sectionName)
    }
    NormalizeConfig(cfg, path)
    return cfg
}

GetTeamSectionNames(iniData) {
    sectionNames := []
    for sectionName, _ in iniData {
        if RegExMatch(sectionName, "^team\.")
            sectionNames.Push(sectionName)
    }
    return sectionNames
}

LoadIniSectionData(iniData, section) {
    obj := {}
    keys := GetSectionKeys(section)
    sectionData := iniData.HasKey(section) ? iniData[section] : {}
    for _, key in keys {
        value := sectionData.HasKey(key) ? sectionData[key] : ""
        obj[key] := Trim(value)
    }
    return obj
}

ParseIniFile(path) {
    content := ReadUtf8TextFile(path)
    sections := {}
    currentSection := ""

    Loop, Parse, content, `n, `r
    {
        line := A_LoopField
        if (A_Index = 1)
            line := StripUtf8Bom(line)
        trimmed := Trim(line)
        if (trimmed = "")
            continue
        if RegExMatch(trimmed, "^[;#]")
            continue

        if RegExMatch(trimmed, "^\[(.+)\]$", match) {
            currentSection := Trim(match1)
            if !sections.HasKey(currentSection)
                sections[currentSection] := {}
            continue
        }

        if (currentSection = "")
            continue

        delimiterPos := InStr(line, "=")
        if (delimiterPos <= 0)
            continue

        key := Trim(SubStr(line, 1, delimiterPos - 1))
        value := SubStr(line, delimiterPos + 1)
        if !sections[currentSection].HasKey(key)
            sections[currentSection][key] := value
        else
            sections[currentSection][key] := value
    }

    return sections
}

ReadUtf8TextFile(path) {
    file := FileOpen(path, "r", "UTF-8")
    if !IsObject(file)
        throw Exception("config_open_failed: " . path)
    content := file.Read()
    file.Close()
    return content
}

StripUtf8Bom(text) {
    if (text = "")
        return text

    firstChar := SubStr(text, 1, 1)
    if (Asc(firstChar) = 65279)
        return SubStr(text, 2)
    return text
}

GetSectionKeys(section) {
    if (section = "system")
        return ["app_name","fiti_exe_path","login_window_title","main_window_title","qr_window_title","fiti_process_name","max_relogin_count","max_row_retry_count","close_existing_fiti_before_run","close_fiti_after_team_run","keep_source_csv","use_lock_file","lock_file_path","history_dir","run_log_dir","debug_log_enabled","debug_log_dir","success_screenshot_enabled","already_checked_success_screenshot_enabled","failure_screenshot_enabled","default_wait_timeout_ms","default_poll_interval_ms","wait_login_timeout_ms","wait_main_timeout_ms","wait_qr_window_timeout_ms","wait_save_timeout_ms"]

    if (section = "ui")
        return ["main_window_x","main_window_y","main_window_w","main_window_h","dpi_scale","login_user_control","login_password_control","login_submit_button","dialog_confirm_button","dialog_post_confirm_delay_ms","dialog_post_confirm_keys","login_post_submit_keys","qr_button_x","qr_button_y","qr_button_click_count","qr_button_wait_ms","qr_verify_controls","checkbox_pixel_x","checkbox_pixel_y","checkbox_checked_color","checkbox_unchecked_color","checkbox_control","save_control","post_save_control","save_result_pixel_x","save_result_pixel_y","save_result_color","save_result_pending_color"]

    if RegExMatch(section, "^team\.")
        return ["enabled","team_name","part_name","login_id","login_password","csv_root_path","receipt_mode","receipt_compose_columns","receipt_direct_column","row_scan_column","row_scan_pattern","stop_file_on_empty_scan_column","skip_today_success_receipt","cutoff_hour","allow_future_folder","recent_date_folder_count","file_select_policy","file_created_after_hour","previous_date_scan_before_hour","previous_date_created_after_hour","postprocess_mode","failure_policy","stop_on_check_failure","move_processed_file","processed_file_dir","log_dir","screenshot_dir","screenshot_sync_dir"]

    return []
}

NormalizeConfig(ByRef cfg, path) {
    configDir := GetParentDir(path)
    repoRoot := GetParentDir(configDir)
    cfg.system.repo_root := repoRoot

    for _, key in ["fiti_exe_path","lock_file_path","history_dir","run_log_dir","debug_log_dir"] {
        cfg.system[key] := ResolveConfigPath(cfg.system[key], repoRoot)
    }

    for _, section in cfg._team_sections {
        teamCfg := cfg[section]
        for _, key in ["csv_root_path","processed_file_dir","log_dir","screenshot_dir","screenshot_sync_dir"] {
            teamCfg[key] := ResolveConfigPath(teamCfg[key], repoRoot)
        }
        if (teamCfg.stop_file_on_empty_scan_column = "")
            teamCfg.stop_file_on_empty_scan_column := "false"
        if (teamCfg.skip_today_success_receipt = "")
            teamCfg.skip_today_success_receipt := "false"
        if (teamCfg.recent_date_folder_count = "")
            teamCfg.recent_date_folder_count := "1"
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
    if (cfg.system.already_checked_success_screenshot_enabled = "")
        cfg.system.already_checked_success_screenshot_enabled := "false"

    if (cfg.ui.login_user_control = "")
        cfg.ui.login_user_control := "ThunderRT6TextBox1"
    if (cfg.ui.login_password_control = "")
        cfg.ui.login_password_control := "ThunderRT6TextBox2"
    if (cfg.ui.login_submit_button = "")
        cfg.ui.login_submit_button := "Button1"
    if (cfg.ui.dialog_confirm_button = "")
        cfg.ui.dialog_confirm_button := "Button1"
    if (cfg.ui.dialog_post_confirm_delay_ms = "")
        cfg.ui.dialog_post_confirm_delay_ms := "500"
    if (cfg.ui.dialog_post_confirm_keys = "")
        cfg.ui.dialog_post_confirm_keys := ""
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
    value := ToLower(Trim(value))
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

ResolveMonthlyLogDir(rootDir, ymd := "") {
    rootDir := TrimTrailingSlash(rootDir)
    if (rootDir = "")
        return ""

    if (ymd = "")
        FormatTime, ymd,, yyyyMMdd

    year := SubStr(ymd, 1, 4)
    month := SubStr(ymd, 5, 2)
    return rootDir "\" year "\" month
}

ResolveDatedLogFilePath(rootDir, baseFileName, ymd := "") {
    monthlyDir := ResolveMonthlyLogDir(rootDir, ymd)
    if (monthlyDir = "")
        return ""

    if (ymd = "")
        FormatTime, ymd,, yyyyMMdd
    return monthlyDir "\" ymd "_" baseFileName
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

TrimTrailingSlash(path) {
    return RegExReplace(path, "[\\/]+$")
}

ToLower(value) {
    StringLower, output, value
    return output
}

ToUpper(value) {
    StringUpper, output, value
    return output
}

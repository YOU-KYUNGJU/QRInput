param(
    [string]$Team = "all",
    [string]$ConfigPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ConfigPath {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $localPath = Join-Path $repoRoot "config\qr_input.local.ini"
    if (Test-Path -LiteralPath $localPath) {
        return $localPath
    }

    $templatePath = Join-Path $repoRoot "config\qr_input_config.template.ini"
    if (Test-Path -LiteralPath $templatePath) {
        return $templatePath
    }

    throw "runtime_config_missing: $localPath | $templatePath"
}

function Read-IniFile {
    param([string]$Path)

    $sections = @{}
    $currentSection = ""

    foreach ($rawLine in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line = $rawLine.Trim()
        if (-not $line) {
            continue
        }
        if ($line.StartsWith(";") -or $line.StartsWith("#")) {
            continue
        }
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $matches[1].Trim()
            if (-not $sections.ContainsKey($currentSection)) {
                $sections[$currentSection] = @{}
            }
            continue
        }
        if (-not $currentSection) {
            continue
        }

        $delimiterIndex = $rawLine.IndexOf("=")
        if ($delimiterIndex -lt 0) {
            continue
        }

        $key = $rawLine.Substring(0, $delimiterIndex).Trim()
        $value = $rawLine.Substring($delimiterIndex + 1).Trim()
        $sections[$currentSection][$key] = $value
    }

    return $sections
}

function Invoke-RobocopySync {
    param(
        [string]$SourceRoot,
        [string]$DestinationRoot,
        [string]$Label
    )

    if (-not $SourceRoot -or -not (Test-Path -LiteralPath $SourceRoot)) {
        Write-Host "[$Label] source_missing: $SourceRoot"
        return
    }

    if (-not $DestinationRoot) {
        Write-Host "[$Label] destination_missing"
        return
    }

    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null

    $robocopyArgs = @(
        $SourceRoot
        $DestinationRoot
        "/E"
        "/R:1"
        "/W:2"
        "/FFT"
        "/NP"
        "/NJH"
        "/NJS"
        "/NFL"
        "/NDL"
    )

    Write-Host "[$Label] sync_begin: $SourceRoot -> $DestinationRoot"
    & robocopy @robocopyArgs | Out-Null
    $exitCode = $LASTEXITCODE
    if ($exitCode -gt 7) {
        throw "[$Label] robocopy_failed: exit_code=$exitCode"
    }
    Write-Host "[$Label] sync_end: exit_code=$exitCode"
}

function Get-TeamMap {
    param([hashtable]$Ini)

    $teamMap = [ordered]@{}
    foreach ($sectionName in $Ini.Keys | Sort-Object) {
        if ($sectionName -notmatch '^team\.') {
            continue
        }

        $alias = $sectionName.Substring(5)
        $teamMap[$alias] = $sectionName
    }

    return $teamMap
}

$resolvedConfigPath = Resolve-ConfigPath -ExplicitPath $ConfigPath
$ini = Read-IniFile -Path $resolvedConfigPath

$teamMap = Get-TeamMap -Ini $ini

if ($teamMap.Count -eq 0) {
    throw "team_section_missing: no [team.*] section found in $resolvedConfigPath"
}

if ($Team -ne "all" -and -not $teamMap.Contains($Team)) {
    $availableTeams = ($teamMap.Keys -join ", ")
    throw "unknown_team: $Team | available=$availableTeams"
}

$selectedTeams = if ($Team -eq "all") { $teamMap.Keys } else { @($Team) }

foreach ($teamName in $selectedTeams) {
    $sectionName = $teamMap[$teamName]
    if (-not $ini.ContainsKey($sectionName)) {
        Write-Host "[$teamName] section_missing: $sectionName"
        continue
    }

    $section = $ini[$sectionName]
    $sourceRoot = $section["screenshot_dir"]
    $destinationRoot = $section["screenshot_sync_dir"]
    Invoke-RobocopySync -SourceRoot $sourceRoot -DestinationRoot $destinationRoot -Label $teamName
}

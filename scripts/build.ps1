param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$srcScript = Join-Path $repoRoot "src\QRinput_main.ahk"
$distDir = Join-Path $repoRoot "dist"
$configDir = Join-Path $distDir "config"
$docsDir = Join-Path $distDir "docs"
$outputExe = Join-Path $distDir "QRinput_main.exe"
$ahkCompiler = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
$ahkBase = "C:\Program Files\AutoHotkey\Compiler\Unicode 64-bit.bin"

if (-not (Test-Path $ahkCompiler)) {
    throw "Ahk2Exe not found: $ahkCompiler"
}

if (-not (Test-Path $srcScript)) {
    throw "Source script not found: $srcScript"
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
New-Item -ItemType Directory -Force -Path $docsDir | Out-Null

& $ahkCompiler /in $srcScript /out $outputExe /base $ahkBase /ErrorStdOut

Copy-Item -LiteralPath (Join-Path $repoRoot "config\qr_input_config.template.ini") -Destination (Join-Path $configDir "qr_input_config.template.ini") -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "README.md") -Destination (Join-Path $distDir "README.md") -Force
Copy-Item -LiteralPath (Join-Path $repoRoot "docs\manual-test-checklist.md") -Destination (Join-Path $docsDir "manual-test-checklist.md") -Force

Write-Host "Build completed:"
Write-Host "  EXE  : $outputExe"
Write-Host "  Config: $configDir"
Write-Host "  Docs : $docsDir"

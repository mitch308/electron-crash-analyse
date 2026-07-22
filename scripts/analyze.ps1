# analyze.ps1
# 一键分析 Electron crash dump 文件
# 自动检测 Electron 版本、安装缺失工具和符号、生成分析报告
# 用法: .\scripts\analyze.ps1 <path-to-dump-file> [-Proxy "http://127.0.0.1:7897"] [-Json]

param(
    [Parameter(Mandatory=$true)]
    [string]$DumpPath,

    [Parameter(Mandatory=$false)]
    [string]$Proxy = "",

    [Parameter(Mandatory=$false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"

# 设置控制台编码为 UTF-8，避免中文输出乱码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ToolsDir = Join-Path $ProjectRoot "tools"
$SymbolsDir = Join-Path $ProjectRoot "symbols"
$BreakpadDir = Join-Path $SymbolsDir "breakpad_symbols"
$ReportsDir = Join-Path $ProjectRoot "reports"

# Proxy 配置（环境变量传递给 minidump-stackwalk 子进程）
if ($Proxy) {
    $env:HTTP_PROXY = $Proxy
    $env:HTTPS_PROXY = $Proxy
    Write-Host "使用代理: $Proxy" -ForegroundColor Cyan
}

# 验证 dump 文件
if (-not (Test-Path $DumpPath)) {
    Write-Host "ERROR: 找不到文件: $DumpPath" -ForegroundColor Red
    exit 1
}

$DumpFile = Get-Item $DumpPath
Write-Host "分析 dump: $($DumpFile.FullName)" -ForegroundColor Cyan
$sizeMB = [Math]::Round($DumpFile.Length / 1MB, 1)
Write-Host "  大小: $sizeMB MB"
Write-Host ""

# ==================== 步骤 1: 检测 Electron 版本 ====================

Write-Host "=== [1/4] 检测 Electron 版本 ===" -ForegroundColor Cyan

$ElectronVersion = & "$PSScriptRoot\detect-version.ps1" $DumpFile.FullName 2>$null
if ($LASTEXITCODE -ne 0 -or -not $ElectronVersion) {
    Write-Host "ERROR: 无法从 dump 文件检测 Electron 版本" -ForegroundColor Red
    Write-Host "请确认 dump 文件是 Electron 应用产生的" -ForegroundColor Yellow
    exit 1
}
Write-Host "  检测到版本: v$ElectronVersion" -ForegroundColor Green
Write-Host ""

# ==================== 步骤 2: 检查并安装工具 ====================

Write-Host "=== [2/4] 检查工具和符号 ===" -ForegroundColor Cyan

$needInstall = $false
$installReason = @()

# 检查 minidump-stackwalk 是否存在
$StackwalkExe = Get-ChildItem -Path $ToolsDir -Filter "minidump-stackwalk*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $StackwalkExe) {
    $needInstall = $true
    $installReason += "minidump-stackwalk.exe 未安装"
}

# 检查符号是否存在且版本匹配
$symCount = (Get-ChildItem -Path $BreakpadDir -Recurse -Filter "*.sym" -ErrorAction SilentlyContinue).Count
$versionFile = Join-Path $BreakpadDir "version"
$cachedVersion = ""

if ($symCount -gt 0 -and (Test-Path $versionFile)) {
    $cachedVersion = (Get-Content $versionFile -ErrorAction SilentlyContinue).Trim()
}

if ($symCount -eq 0) {
    $needInstall = $true
    $installReason += "本地无 Electron 符号文件"
} elseif ($cachedVersion -and $cachedVersion -ne $ElectronVersion) {
    $needInstall = $true
    $installReason += "符号版本不匹配 (本地: v$cachedVersion, 需要: v$ElectronVersion)"
}

if ($needInstall) {
    Write-Host "  需要安装:" -ForegroundColor Yellow
    foreach ($reason in $installReason) {
        Write-Host "    - $reason" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  调用 install-tools.ps1 安装 v$ElectronVersion ..." -ForegroundColor Cyan
    & "$PSScriptRoot\install-tools.ps1" -ElectronVersion $ElectronVersion -Proxy $Proxy
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: install-tools.ps1 执行失败" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    # 重新查找工具和符号
    $StackwalkExe = Get-ChildItem -Path $ToolsDir -Filter "minidump-stackwalk*.exe" | Select-Object -First 1
    if ($null -eq $StackwalkExe) {
        Write-Host "ERROR: 安装后仍未找到 minidump-stackwalk.exe" -ForegroundColor Red
        exit 1
    }
    $symCount = (Get-ChildItem -Path $BreakpadDir -Recurse -Filter "*.sym" -ErrorAction SilentlyContinue).Count
} else {
    if ($StackwalkExe) {
        Write-Host "  minidump-stackwalk: 已安装" -ForegroundColor Green
    }
    if ($symCount -gt 0) {
        Write-Host "  Electron 符号: ${symCount} 个文件 (v$cachedVersion)" -ForegroundColor Green
    }
}
Write-Host ""

# ==================== 步骤 3: 配置符号路径 ====================

Write-Host "=== [3/4] 配置符号路径 ===" -ForegroundColor Cyan

$SymbolPaths = @()

# 1. 本地预下载的符号（如果有）
if ($symCount -gt 0) {
    $SymbolPaths += $BreakpadDir
    Write-Host "  本地符号: $BreakpadDir (${symCount} 个文件)" -ForegroundColor Green
}

# 2. Electron 符号服务器（用于补充缺失符号）
$SymbolPaths += "https://symbols.electronjs.org"
Write-Host "  在线符号: https://symbols.electronjs.org" -ForegroundColor Green
Write-Host ""

# 确保 reports 目录存在
if (-not (Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
}

$ReportName = [System.IO.Path]::GetFileNameWithoutExtension($DumpFile.Name) + ".txt"
$ReportPath = Join-Path $ReportsDir $ReportName
$dumpBaseName = [System.IO.Path]::GetFileNameWithoutExtension($DumpFile.Name)
$JsonReportPath = Join-Path $ReportsDir "$dumpBaseName-modules.json"

# ==================== 步骤 4: 分析 dump ====================

Write-Host "=== [4/4] 分析 dump ===" -ForegroundColor Cyan
Write-Host "  Electron 版本: v$ElectronVersion"
Write-Host "  符号路径: $SymbolsDir"
Write-Host "  输出报告: $ReportPath"
Write-Host ""

# 提取模块信息 (JSON)
$jsonOutput = & $StackwalkExe.FullName --symbols-path $SymbolsDir --json $DumpFile.FullName 2>&1 | Out-String
$jsonOutput | Out-File -FilePath $JsonReportPath -Encoding utf8

# 生成人类可读报告
if (-not $Json) {
    $stackwalkOutput = & $StackwalkExe.FullName --symbols-path $SymbolsDir $DumpFile.FullName 2>&1 | Out-String
    $stackwalkOutput | Out-File -FilePath $ReportPath -Encoding utf8
    Write-Host $stackwalkOutput

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "分析完成!" -ForegroundColor Green
        Write-Host "  文本报告: $ReportPath"
        Write-Host "  模块信息(JSON): $JsonReportPath"
    } else {
        Write-Host ""
        Write-Host "ERROR: 分析失败 (exit code: ${LASTEXITCODE})" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} else {
    Write-Host ""
    Write-Host "JSON 报告: $JsonReportPath" -ForegroundColor Green
}

# ==================== WinDbg 指引 ====================

Write-Host ""
Write-Host "使用 WinDbg 进行深度分析:" -ForegroundColor Yellow
Write-Host "  1. 打开 WinDbg Preview"
Write-Host "  2. File > Open Dump File > 选择 $($DumpFile.FullName)"
Write-Host "  3. 设置符号路径 (File > Symbol File Path):"
Write-Host "     SRV*$SymbolsDir*https://msdl.microsoft.com/download/symbols;SRV*$SymbolsDir*https://symbols.electronjs.org"
Write-Host "  4. 运行: .reload"
Write-Host "  5. 常用命令: !analyze -v, kv, r, !peb"

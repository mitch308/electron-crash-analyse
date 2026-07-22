# analyze.ps1
# 分析 Electron crash dump 文件
# 用法: .\scripts\analyze.ps1 <path-to-dump-file> -ElectronVersion "39.4.0" [-Proxy "http://127.0.0.1:7897"] [-Json]
# -ElectronVersion 为必传参数，可用 detect-version.ps1 从 dump 自动获取:
#   $ver = .\scripts\detect-version.ps1 .\dumps\crash.dmp; .\scripts\analyze.ps1 .\dumps\crash.dmp -ElectronVersion $ver

param(
    [Parameter(Mandatory=$true)]
    [string]$DumpPath,

    [Parameter(Mandatory=$true)]
    [string]$ElectronVersion,

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

# 查找 minidump-stackwalk
$StackwalkExe = Get-ChildItem -Path $ToolsDir -Filter "minidump-stackwalk*.exe" | Select-Object -First 1
if ($null -eq $StackwalkExe) {
    Write-Host "ERROR: 未找到 minidump-stackwalk.exe" -ForegroundColor Red
    Write-Host "请先运行: .\scripts\install-tools.ps1" -ForegroundColor Yellow
    exit 1
}

# 确保 reports 目录存在
if (-not (Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
}

# 确保 symbols 目录存在
if (-not (Test-Path $BreakpadDir)) {
    New-Item -ItemType Directory -Path $BreakpadDir -Force | Out-Null
}

$ReportName = [System.IO.Path]::GetFileNameWithoutExtension($DumpFile.Name) + ".txt"
$ReportPath = Join-Path $ReportsDir $ReportName

# ==================== 步骤 A: 显示 Electron 版本并准备符号 ====================

Write-Host "--- Electron 版本 ---" -ForegroundColor Cyan
Write-Host "  v$ElectronVersion" -ForegroundColor Green
Write-Host ""

# 判断是否需要下载符号：本地无符号 → 自动安装
$symCount = (Get-ChildItem -Path $BreakpadDir -Recurse -Filter "*.sym" -ErrorAction SilentlyContinue).Count
if ($symCount -eq 0) {
    Write-Host "本地缺少 Electron 符号，安装 v$ElectronVersion ..." -ForegroundColor Yellow
    & "$PSScriptRoot\install-tools.ps1" -ElectronVersion $ElectronVersion -Proxy $Proxy | Out-Null
    # 重新统计
    $symCount = (Get-ChildItem -Path $BreakpadDir -Recurse -Filter "*.sym" -ErrorAction SilentlyContinue).Count
}

# ==================== 步骤 B: 配置符号路径 ====================

$SymbolPaths = @()

# 1. 本地预下载的符号（如果有）
if ($symCount -gt 0) {
    $SymbolPaths += $BreakpadDir
    Write-Host "本地符号: $BreakpadDir (${symCount} 个文件)" -ForegroundColor Green
}

# 2. Electron 符号服务器（用于补充缺失符号）
$SymbolPaths += "https://symbols.electronjs.org"

# ==================== 步骤 C: 提取模块信息 (JSON) ====================

Write-Host ""
Write-Host "--- 提取模块信息 ---" -ForegroundColor Cyan

$dumpBaseName = [System.IO.Path]::GetFileNameWithoutExtension($DumpFile.Name)
$JsonReportPath = Join-Path $ReportsDir "$dumpBaseName-modules.json"

$jsonOutput = & $StackwalkExe.FullName --symbols-path $SymbolsDir --json $DumpFile.FullName 2>&1 | Out-String
$jsonOutput | Out-File -FilePath $JsonReportPath -Encoding utf8

# ==================== 步骤 D: 生成人类可读报告 ====================

if (-not $Json) {
    Write-Host ""
    Write-Host "--- 生成人类可读报告 ---" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "符号路径: $SymbolsDir"
    if ($ElectronVersion) {
        Write-Host "Electron 版本: v$ElectronVersion"
    }
    Write-Host "输出报告: $ReportPath"
    Write-Host ""

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

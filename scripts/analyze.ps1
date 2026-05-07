# analyze.ps1
# 分析 Electron crash dump 文件
# 用法: .\scripts\analyze.ps1 <path-to-dump-file> [-ElectronVersion "39.4.0"] [-Proxy "http://127.0.0.1:7897"] [-Json]

param(
    [Parameter(Mandatory=$true)]
    [string]$DumpPath,

    [Parameter(Mandatory=$false)]
    [string]$ElectronVersion,

    [Parameter(Mandatory=$false)]
    [string]$Proxy = "",

    [Parameter(Mandatory=$false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ToolsDir = Join-Path $ProjectRoot "tools"
$SymbolsDir = Join-Path $ProjectRoot "symbols"
$BreakpadDir = Join-Path $SymbolsDir "breakpad_symbols"
$ReportsDir = Join-Path $ProjectRoot "reports"

# Proxy 配置
$ProxyEnv = @{}
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
Write-Host "  大小: $([Math]::Round($DumpFile.Length / 1MB, 1)) MB"
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

# ==================== 符号路径配置 ====================

$SymbolPaths = @()

# 1. 本地预下载的符号（如果有）
if (Test-Path $BreakpadDir) {
    $symCount = (Get-ChildItem -Path $BreakpadDir -Recurse -Filter "*.sym" -ErrorAction SilentlyContinue).Count
    if ($symCount -gt 0) {
        $SymbolPaths += $BreakpadDir
        Write-Host "本地符号: $BreakpadDir ($symCount 个文件)" -ForegroundColor Green
    }
}

# 2. Electron 符号服务器（用于补充缺失符号）
$SymbolPaths += "https://symbols.electronjs.org"

# ==================== 步骤 A: 提取模块信息 (JSON) ====================

Write-Host ""
Write-Host "--- 提取模块信息 ---" -ForegroundColor Cyan

$JsonReportPath = Join-Path $ReportsDir "$([System.IO.Path]::GetFileNameWithoutExtension($DumpFile.Name))-modules.json"

$stackwalkArgs = @($StackwalkExe.FullName, "--symbols-path", $SymbolsDir, "--json", $DumpFile.FullName)
$jsonOutput = & $stackwalkArgs 2>&1 | Out-String
$jsonOutput | Out-File -FilePath $JsonReportPath -Encoding utf8

# ==================== 步骤 B: 生成人类可读报告 ====================

if (-not $Json) {
    Write-Host ""
    Write-Host "--- 生成人类可读报告 ---" -ForegroundColor Cyan
    Write-Host ""

    # 构建符号路径参数
    $symbolsArg = "--symbols-path"
    $symbolsValue = $SymbolsDir

    # 如果指定了 Electron 版本且本地没有完整符号，先尝试下载
    if ($ElectronVersion -and $symCount -eq 0) {
        Write-Host "检测到缺少 Electron 符号，正在下载 v$ElectronVersion ..." -ForegroundColor Yellow
        & "$PSScriptRoot\install-tools.ps1" -ElectronVersion $ElectronVersion -Proxy $Proxy
        # 重新统计
        $symCount = (Get-ChildItem -Path $BreakpadDir -Recurse -Filter "*.sym" -ErrorAction SilentlyContinue).Count
    }

    Write-Host "符号路径: $SymbolsDir"
    if ($ElectronVersion) {
        Write-Host "Electron 版本: v$ElectronVersion"
    }
    Write-Host "输出报告: $ReportPath"
    Write-Host ""

    & $StackwalkExe.FullName --symbols-path $SymbolsDir $DumpFile.FullName 2>&1 | Tee-Object -FilePath $ReportPath

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "分析完成!" -ForegroundColor Green
        Write-Host "  文本报告: $ReportPath"
        Write-Host "  模块信息(JSON): $JsonReportPath"
    } else {
        Write-Host ""
        Write-Host "ERROR: 分析失败 (exit code: $LASTEXITCODE)" -ForegroundColor Red
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

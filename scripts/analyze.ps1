# analyze.ps1
# 一键分析 Electron crash dump 文件
# 用法: .\scripts\analyze.ps1 <path-to-dump-file>

param(
    [Parameter(Mandatory=$true)]
    [string]$DumpPath
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ToolsDir = Join-Path $ProjectRoot "tools"
$SymbolsDir = Join-Path $ProjectRoot "symbols"
$ReportsDir = Join-Path $ProjectRoot "reports"

# Electron 和 Microsoft 符号服务器
$SymbolServer = "https://symbols.electronjs.org"
$MsSymbolServer = "https://msdl.microsoft.com/download/symbols"

# 验证 dump 文件
if (-not (Test-Path $DumpPath)) {
    Write-Host "ERROR: 找不到文件: $DumpPath" -ForegroundColor Red
    exit 1
}

$DumpFile = Get-Item $DumpPath
Write-Host "分析 dump: $($DumpFile.FullName)" -ForegroundColor Cyan
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
if (-not (Test-Path $SymbolsDir)) {
    New-Item -ItemType Directory -Path $SymbolsDir -Force | Out-Null
}

$ReportName = [System.IO.Path]::GetFileNameWithoutExtension($DumpFile.Name) + ".txt"
$ReportPath = Join-Path $ReportsDir $ReportName

Write-Host "符号服务器:" -ForegroundColor Cyan
Write-Host "  Electron: $SymbolServer"
Write-Host "  Microsoft: $MsSymbolServer"
Write-Host ""
Write-Host "正在分析 (首次运行需下载符号文件，请耐心等待)..." -ForegroundColor Cyan
Write-Host ""

# 构建符号路径：本地缓存 + 远程服务器
# minidump-stackwalk 支持 --symbols-path 参数指定符号目录
# 它会从 Electron symbol server 自动下载符号到指定目录
& $StackwalkExe.FullName --symbols-path $SymbolsDir $DumpFile.FullName 2>&1 | Tee-Object -FilePath $ReportPath

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "分析完成!" -ForegroundColor Green
    Write-Host "  报告: $ReportPath"
    Write-Host ""
    Write-Host "使用 WinDbg 进行深度分析:" -ForegroundColor Yellow
    Write-Host "  1. 打开 WinDbg Preview"
    Write-Host "  2. File > Open Dump File > 选择 $($DumpFile.FullName)"
    Write-Host "  3. 设置符号路径 (File > Symbol File Path):"
    Write-Host "     SRV*$SymbolsDir*$MsSymbolServer;SRV*$SymbolsDir*$SymbolServer"
    Write-Host "  4. 运行: .reload"
} else {
    Write-Host ""
    Write-Host "ERROR: 分析失败 (exit code: $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

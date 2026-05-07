# install-tools.ps1
# 下载并安装 minidump-stackwalk 到 tools/ 目录

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ToolsDir = Join-Path $ProjectRoot "tools"
$StackwalkUrl = "https://github.com/rust-minidump/rust-minidump/releases/latest/download/minidump-stackwalk-x86_64-pc-windows-msvc.zip"
$ZipPath = Join-Path $ToolsDir "minidump-stackwalk.zip"

Write-Host "[1/3] 下载 minidump-stackwalk..." -ForegroundColor Cyan

# 确保 tools 目录存在
if (-not (Test-Path $ToolsDir)) {
    New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
}

# 下载 zip
Invoke-WebRequest -Uri $StackwalkUrl -OutFile $ZipPath -UseBasicParsing

Write-Host "[2/3] 解压到 tools/..." -ForegroundColor Cyan

# 解压（zip 内通常是一个 .exe 文件）
Expand-Archive -Path $ZipPath -DestinationPath $ToolsDir -Force

# 清理 zip
Remove-Item $ZipPath -Force

Write-Host "[3/3] 验证安装..." -ForegroundColor Cyan

$ExePath = Get-ChildItem -Path $ToolsDir -Filter "minidump-stackwalk*.exe" | Select-Object -First 1

if ($null -eq $ExePath) {
    Write-Host "ERROR: 未找到 minidump-stackwalk.exe，请检查 tools/ 目录" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "安装成功!" -ForegroundColor Green
Write-Host "  路径: $($ExePath.FullName)"
Write-Host ""
Write-Host "测试运行: & '$($ExePath.FullName)' --version"

# download-symbols.ps1
# 从 Electron 符号服务器下载指定版本的符号文件
# 用法: .\scripts\download-symbols.ps1 -ElectronVersion "32.0.0"

param(
    [Parameter(Mandatory=$true)]
    [string]$ElectronVersion
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$SymbolsDir = Join-Path $ProjectRoot "symbols"

if (-not (Test-Path $SymbolsDir)) {
    New-Item -ItemType Directory -Path $SymbolsDir -Force | Out-Null
}

Write-Host "下载 Electron v$ElectronVersion 符号文件..." -ForegroundColor Cyan
Write-Host "符号目录: $SymbolsDir"
Write-Host ""

# Electron 符号服务器基础 URL
$BaseUrl = "https://symbols.electronjs.org"

# Electron 主要模块的符号文件列表
$SymbolFiles = @(
    "electron.exe.pdb",
    "ffmpeg.dll.pdb",
    "chrome_child.dll.pdb",
    "v8.dll.pdb",
    "v8_libbase.dll.pdb",
    "v8_libplatform.dll.pdb",
    "icudtl.dat.pdb",
    "snapshot_blob.bin.pdb"
)

# 注意：符号服务器需要正确的 GUID/age 路径才能下载
# 这里提供的是查询接口，实际下载需要从 dump 文件中提取 GUID
Write-Host "提示: 符号文件需要根据 crash dump 中的 GUID 精确下载。" -ForegroundColor Yellow
Write-Host "推荐使用 analyze.ps1 自动处理符号下载。" -ForegroundColor Yellow
Write-Host ""
Write-Host "如需手动配置 WinDbg 符号路径，使用:" -ForegroundColor Cyan
Write-Host "  SRV*$SymbolsDir*https://msdl.microsoft.com/download/symbols;SRV*$SymbolsDir*https://symbols.electronjs.org"

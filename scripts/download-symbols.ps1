# download-symbols.ps1
# 从 Electron 符号服务器下载指定版本的符号文件到本地缓存
# 用法: .\scripts\download-symbols.ps1 -ElectronVersion "39.4.0" [-Proxy "http://127.0.0.1:7897"]

param(
    [Parameter(Mandatory=$true)]
    [string]$ElectronVersion,

    [Parameter(Mandatory=$false)]
    [string]$Proxy = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$SymbolsDir = Join-Path $ProjectRoot "symbols"
$BreakpadDir = Join-Path $SymbolsDir "breakpad_symbols"

$ProxyEnv = @{}
if ($Proxy) {
    $ProxyEnv = @{ HTTP_PROXY = $Proxy; HTTPS_PROXY = $Proxy }
    Write-Host "使用代理: $Proxy" -ForegroundColor Cyan
}

Write-Host "下载 Electron v$ElectronVersion 符号文件..." -ForegroundColor Cyan

$SymbolsZipName = "electron-v${ElectronVersion}-win32-x64-symbols.zip"
$SymbolsZipUrl = "https://github.com/electron/electron/releases/download/v${ElectronVersion}/${SymbolsZipName}"
$ZipPath = Join-Path $SymbolsDir "electron-symbols.zip"

# 确保目录存在
if (-not (Test-Path $BreakpadDir)) {
    New-Item -ItemType Directory -Path $BreakpadDir -Force | Out-Null
}

Write-Host "下载: $SymbolsZipUrl"
Invoke-WebRequest -Uri $SymbolsZipUrl -OutFile $ZipPath -UseBasicParsing @ProxyEnv

Write-Host "解压到 $BreakpadDir ..."
Expand-Archive -Path $ZipPath -DestinationPath $BreakpadDir -Force
Remove-Item $ZipPath -Force

# 验证
$symCount = (Get-ChildItem -Path $BreakpadDir -Recurse -Filter "*.sym" -ErrorAction SilentlyContinue).Count
Write-Host ""
Write-Host "安装完成! 共 $symCount 个符号文件" -ForegroundColor Green

$electronSym = Get-ChildItem -Path $BreakpadDir -Recurse -Filter "electron.exe.sym" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $electronSym) {
    Write-Host "  electron.exe.sym: $($electronSym.FullName)"
}

# 提取 debug_id
if ($null -ne $electronSym) {
    $firstLine = Get-Content $electronSym.FullName -TotalCount 1
    if ($firstLine -match "^MODULE windows (x86|amd64|arm64) ([A-F0-9]+) ") {
        $debugId = $matches[2]
        Write-Host "  debug_id: $debugId"
    }
}

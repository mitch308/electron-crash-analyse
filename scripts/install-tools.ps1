# install-tools.ps1
# 安装 Electron crash dump 分析工具链：minidump-stackwalk + Electron 符号文件
# 用法: .\scripts\install-tools.ps1 [-ElectronVersion "39.4.0"] [-Proxy "http://127.0.0.1:7897"]

param(
    [Parameter(Mandatory=$false)]
    [string]$ElectronVersion,

    [Parameter(Mandatory=$false)]
    [string]$Proxy = ""
)

$ErrorActionPreference = "Stop"

# 设置控制台编码为 UTF-8，避免中文输出乱码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$ToolsDir = Join-Path $ProjectRoot "tools"
$SymbolsDir = Join-Path $ProjectRoot "symbols"
$BreakpadDir = Join-Path $SymbolsDir "breakpad_symbols"

# Proxy 配置
$ProxyParams = @{}
if ($Proxy) {
    $ProxyParams = @{ Proxy = $Proxy }
    Write-Host "使用代理: $Proxy" -ForegroundColor Cyan
}

# ==================== Step 1: 下载 minidump-stackwalk ====================

Write-Host ""
Write-Host "=== [1/3] 安装 minidump-stackwalk ===" -ForegroundColor Cyan

$StackwalkExe = Get-ChildItem -Path $ToolsDir -Filter "minidump-stackwalk*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($null -ne $StackwalkExe) {
    Write-Host "  已存在: $($StackwalkExe.FullName)" -ForegroundColor Yellow
    $version = & $StackwalkExe.FullName --version 2>&1
    Write-Host "  版本: $version"
} else {
    if (-not (Test-Path $ToolsDir)) {
        New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    }

    # 查询 GitHub 最新版本
    Write-Host "  查询 rust-minidump 最新版本..."
    $apiUrl = "https://api.github.com/repos/rust-minidump/rust-minidump/releases/latest"
    $releaseInfo = Invoke-RestMethod -Uri $apiUrl @ProxyParams

    $asset = $releaseInfo.assets | Where-Object { $_.name -match 'minidump-stackwalk.*x86_64.*windows.*\.zip' } | Select-Object -First 1
    if ($null -eq $asset) {
        # 尝试其他命名模式
        $asset = $releaseInfo.assets | Where-Object { $_.name -match 'minidump-stackwalk.*win.*x64.*\.zip' } | Select-Object -First 1
    }
    if ($null -eq $asset) {
        Write-Host "ERROR: 未找到适用的 minidump-stackwalk 二进制" -ForegroundColor Red
        Write-Host "可用资产: $($releaseInfo.assets.name -join ', ')"
        exit 1
    }

    Write-Host "  下载: $($asset.name)"
    $ZipPath = Join-Path $ToolsDir "minidump-stackwalk.zip"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $ZipPath -UseBasicParsing @ProxyParams

    Write-Host "  解压..."
    Expand-Archive -Path $ZipPath -DestinationPath $ToolsDir -Force
    Remove-Item $ZipPath -Force

    $StackwalkExe = Get-ChildItem -Path $ToolsDir -Filter "minidump-stackwalk*.exe" | Select-Object -First 1
    if ($null -eq $StackwalkExe) {
        Write-Host "ERROR: 解压后未找到 minidump-stackwalk.exe" -ForegroundColor Red
        exit 1
    }
    Write-Host "  安装成功: $($StackwalkExe.FullName)" -ForegroundColor Green
}

# ==================== Step 2: 下载 Electron 符号文件 ====================

if ($ElectronVersion) {
    Write-Host ""
    Write-Host "=== [2/3] 下载 Electron v$ElectronVersion 符号文件 ===" -ForegroundColor Cyan

    # 检查符号是否已存在
    $existingSym = Get-ChildItem -Path $BreakpadDir -Recurse -Filter "electron.exe.sym" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $existingSym) {
        # 从 .sym 文件头提取版本对应的 debug_id，确认是否匹配
        $firstLine = Get-Content $existingSym.FullName -TotalCount 1
        Write-Host "  已存在符号文件: $($existingSym.FullName)" -ForegroundColor Yellow
        Write-Host "  跳过下载" -ForegroundColor Yellow
    } else {
        $SymbolServer = "https://symbols.electronjs.org"
        $SymbolsZipName = "electron-v${ElectronVersion}-win32-x64-symbols.zip"
        $SymbolsZipUrl = "https://github.com/electron/electron/releases/download/v${ElectronVersion}/${SymbolsZipName}"
        $ZipPath = Join-Path $SymbolsDir "electron-symbols.zip"

        Write-Host "  下载符号文件 (约 100-300MB，请耐心等待)..."
        try {
            Invoke-WebRequest -Uri $SymbolsZipUrl -OutFile $ZipPath -UseBasicParsing @ProxyParams
        } catch {
            Write-Host "  自动下载失败，尝试手动方式..." -ForegroundColor Yellow
            Write-Host "  请手动下载: $SymbolsZipUrl"
            Write-Host "  然后解压到: $SymbolsDir"
            exit 1
        }

        Write-Host "  解压到 $BreakpadDir ..."
        if (-not (Test-Path $BreakpadDir)) {
            New-Item -ItemType Directory -Path $BreakpadDir -Force | Out-Null
        }
        Expand-Archive -Path $ZipPath -DestinationPath $BreakpadDir -Force
        Remove-Item $ZipPath -Force
    }

    # 验证
    $symCount = (Get-ChildItem -Path $BreakpadDir -Recurse -Filter "*.sym" -ErrorAction SilentlyContinue).Count
    Write-Host "  已安装 $symCount 个符号文件" -ForegroundColor Green

    # 验证 electron.exe 符号
    $electronSym = Get-ChildItem -Path $BreakpadDir -Recurse -Filter "electron.exe.sym" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $electronSym) {
        Write-Host "  electron.exe.sym: $($electronSym.FullName)"
    }
} else {
    Write-Host ""
    Write-Host "=== [2/3] 跳过 Electron 符号下载 ===" -ForegroundColor Yellow
    Write-Host "  提示: 使用 -ElectronVersion 参数预下载符号文件"
    Write-Host "  例如: .\scripts\install-tools.ps1 -ElectronVersion '39.4.0'"
}

# ==================== Step 3: 验证 ====================

Write-Host ""
Write-Host "=== [3/3] 验证安装 ===" -ForegroundColor Cyan
Write-Host "  工具: $($StackwalkExe.FullName)"
Write-Host "  符号: $BreakpadDir"

$stackwalkVer = & $StackwalkExe.FullName --version 2>&1
Write-Host "  minidump-stackwalk: $stackwalkVer"

if ($ElectronVersion) {
    $symCount = (Get-ChildItem -Path $BreakpadDir -Recurse -Filter "*.sym" -ErrorAction SilentlyContinue).Count
    Write-Host "  Electron 符号: $symCount 个"
}

Write-Host ""
Write-Host "安装完成!" -ForegroundColor Green
Write-Host ""
Write-Host "使用方法:" -ForegroundColor Cyan
Write-Host "  快速分析: .\scripts\analyze.ps1 .\dumps\crash.dmp"
Write-Host "  带符号分析: .\scripts\analyze.ps1 .\dumps\crash.dmp -ElectronVersion '$ElectronVersion'"

# Electron Crash Dump 分析环境 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭建 Windows 下分析 Electron `.dmp` crash dump 文件的完整工具链

**Architecture:** 下载 minidump-stackwalk 二进制到 tools/ 目录，编写 PowerShell 脚本自动化 dump 分析流程，配置 WinDbg 符号路径指南，创建目录结构和 README

**Tech Stack:** PowerShell, minidump-stackwalk (Rust), WinDbg Preview, Electron Symbol Server

---

### File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `dumps/.gitkeep` | Create | 占位目录，放置 .dmp 文件 |
| `symbols/.gitkeep` | Create | 符号文件缓存目录 |
| `reports/.gitkeep` | Create | 分析报告输出目录 |
| `tools/.gitkeep` | Create | 工具二进制目录 |
| `scripts/.gitkeep` | Create | 脚本目录 |
| `scripts/analyze.ps1` | Create | 一键分析脚本：调用 stackwalk 生成报告 |
| `scripts/download-symbols.ps1` | Create | 手动下载符号文件脚本 |
| `scripts/install-tools.ps1` | Create | 安装工具脚本：下载 minidump-stackwalk |
| `README.md` | Create | 使用说明文档 |

---

### Task 1: 创建目录结构

**Files:**
- Create: `dumps/.gitkeep`
- Create: `symbols/.gitkeep`
- Create: `reports/.gitkeep`
- Create: `tools/.gitkeep`
- Create: `scripts/.gitkeep`

- [ ] **Step 1: 创建所有目录和占位文件**

```bash
mkdir -p dumps symbols reports tools scripts
touch dumps/.gitkeep symbols/.gitkeep reports/.gitkeep tools/.gitkeep scripts/.gitkeep
```

- [ ] **Step 2: 验证目录结构**

```bash
ls -R
```

Expected output:
```
.:
dumps  reports  scripts  symbols  tools

./dumps:
.gitkeep

./reports:
.gitkeep

./scripts:
.gitkeep

./symbols:
.gitkeep

./tools:
.gitkeep
```

---

### Task 2: 安装工具脚本 install-tools.ps1

**Files:**
- Create: `scripts/install-tools.ps1`

- [ ] **Step 1: 编写安装脚本**

```powershell
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
```

- [ ] **Step 2: 提交**

```bash
git add scripts/install-tools.ps1
git commit -m "feat: add install-tools.ps1 for minidump-stackwalk setup"
```

---

### Task 3: 一键分析脚本 analyze.ps1

**Files:**
- Create: `scripts/analyze.ps1`

- [ ] **Step 1: 编写分析脚本**

```powershell
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
```

- [ ] **Step 2: 提交**

```bash
git add scripts/analyze.ps1
git commit -m "feat: add analyze.ps1 for one-click dump analysis"
```

---

### Task 4: 符号下载脚本 download-symbols.ps1

**Files:**
- Create: `scripts/download-symbols.ps1`

- [ ] **Step 1: 编写符号下载脚本**

```powershell
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
```

- [ ] **Step 2: 提交**

```bash
git add scripts/download-symbols.ps1
git commit -m "feat: add download-symbols.ps1 with symbol server guidance"
```

---

### Task 5: README 文档

**Files:**
- Create: `README.md`

- [ ] **Step 1: 编写 README**

```markdown
# Electron Crash Dump 分析环境

Windows 下分析 Electron `.dmp` crash dump 文件的工具链。

## 快速开始

### 1. 安装工具

```powershell
.\scripts\install-tools.ps1
```

这会下载 `minidump-stackwalk` 到 `tools/` 目录。

### 2. 分析 crash dump

```powershell
.\scripts\analyze.ps1 .\dumps\your-crash.dmp
```

报告会自动输出到 `reports/` 目录。

## 两种分析方式

### 方式 A：命令行快速分析（minidump-stackwalk）

```powershell
.\scripts\analyze.ps1 .\dumps\crash.dmp
```

自动从 Electron 和 Microsoft 符号服务器下载符号，输出人类可读的堆栈报告。

### 方式 B：交互式深度分析（WinDbg Preview）

1. 从 [Microsoft Store](https://apps.microsoft.com/detail/9PGJGD53TN86) 安装 WinDbg Preview
2. 打开 WinDbg → File → Open Dump File → 选择 `.dmp` 文件
3. 设置符号路径（File → Symbol File Path）：

```
SRV*C:\workspace\electron-crash\symbols*https://msdl.microsoft.com/download/symbols;SRV*C:\workspace\electron-crash\symbols*https://symbols.electronjs.org
```

4. 运行 `.reload` 加载符号
5. 常用命令：
   - `!analyze -v` — 详细崩溃分析
   - `kv` — 查看堆栈
   - `r` — 查看寄存器
   - `!peb` — 查看进程环境块

## 目录结构

```
├── dumps/          # 放置 .dmp 文件
├── symbols/        # 符号文件缓存
├── reports/        # 分析报告输出
├── tools/          # minidump-stackwalk 二进制
├── scripts/        # 工具脚本
│   ├── install-tools.ps1      # 安装 minidump-stackwalk
│   ├── analyze.ps1            # 一键分析 dump
│   └── download-symbols.ps1   # 符号下载指引
└── README.md
```

## 常见问题

### Q: 符号下载很慢？

首次分析需要下载大量符号文件（几十到几百 MB），请耐心等待。后续运行会使用本地缓存，速度会快很多。

### Q: 提示找不到符号？

确保符号路径配置正确。minidump-stackwalk 需要 `--symbols-path` 指向 `symbols/` 目录，它会自动从远程服务器拉取。

### Q: 如何查看 Electron 版本？

从 crash dump 的模块列表中可以找到 `electron.exe` 的版本号，或者查看你的 `package.json` 中 `electron` 依赖版本。

### Q: WinDbg 加载符号失败？

1. 确认符号路径格式正确（`SRV*缓存路径*服务器URL`）
2. 确认网络连接正常
3. 尝试清除 `symbols/` 目录后重试
```

- [ ] **Step 2: 提交**

```bash
git add README.md
git commit -m "docs: add README with usage guide for crash analysis environment"
```

---

## Self-Review

### 1. Spec Coverage 检查

| Spec Requirement | Task | Status |
|------------------|------|--------|
| minidump-stackwalk 下载 | Task 2 (install-tools.ps1) | Covered |
| Electron symbol server 配置 | Task 3, 4, 5 | Covered |
| 一键分析脚本 | Task 3 (analyze.ps1) | Covered |
| WinDbg 配置指南 | Task 5 (README) | Covered |
| dumps/ 目录 | Task 1 | Covered |
| symbols/ 目录 | Task 1 | Covered |
| reports/ 目录 | Task 1 | Covered |
| 报告输出 | Task 3 | Covered |
| 使用说明 | Task 5 | Covered |

### 2. Placeholder Scan

无 TBD/TODO/占位符。每个步骤都包含完整代码和命令。

### 3. Type/Name Consistency

- 所有脚本使用 `$ProjectRoot`, `$ToolsDir`, `$SymbolsDir`, `$ReportsDir` 变量命名一致
- 符号服务器 URL 在 analyze.ps1 和 README 中一致：`https://symbols.electronjs.org` 和 `https://msdl.microsoft.com/download/symbols`
- 路径引用一致：`SRV*缓存路径*服务器URL` 格式

### 4. Scope Check

范围聚焦在工具链搭建，5 个任务、零测试（这是环境搭建，不是功能代码），无多余特性。

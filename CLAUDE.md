# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Windows 下分析 Electron `.dmp` crash dump 文件的工具链环境。不是应用代码，而是分析工具集——提供命令行快速分析（minidump-stackwalk）和交互式深度调试（WinDbg Preview）两种能力。

## Key Commands

```powershell
# 1. 从 dump 检测 Electron 版本
$ver = .\scripts\detect-version.ps1 .\dumps\crash.dmp

# 2. 安装工具 + 下载符号（首次使用或本地缺少符号）
.\scripts\install-tools.ps1 -ElectronVersion $ver [-Proxy "http://127.0.0.1:7897"]

# 3. 分析 crash dump（核心命令，-ElectronVersion 必传）
.\scripts\analyze.ps1 .\dumps\crash.dmp -ElectronVersion $ver [-Proxy "..."] [-Json]

# 单独下载符号文件
.\scripts\download-symbols.ps1 -ElectronVersion $ver [-Proxy "..."]
```

典型工作流：`detect-version` → `install-tools` → `analyze`。`analyze.ps1` 在本地无符号时会自动调用 `install-tools.ps1` 下载，第二步可省略。

分析报告输出到 `reports/` 目录：`<dump-name>.txt`（人类可读堆栈）+ `<dump-name>-modules.json`（模块列表）。

## Architecture

四个 PowerShell 脚本构成工具链，全部使用 `$ProjectRoot = Split-Path $PSScriptRoot -Parent` 定位项目根目录：

- **install-tools.ps1** — 从 GitHub releases 下载 rust-minidump 的 `minidump-stackwalk` 到 `tools/`；可选从 Electron releases 下载 breakpad `.sym` 符号到 `symbols/breakpad_symbols/`
- **detect-version.ps1** — 从 dump 文件的 Crashpad annotation 中自动检测 Electron 版本，方法1 匹配 `Electron...ver...版本号`，方法2 扫描语义化版本号过滤候选；输出版本号供其它脚本使用
- **analyze.ps1** — 调用 `minidump-stackwalk --symbols-path` 分析 dump；`-ElectronVersion` 必传；本地无符号时自动调用 install-tools.ps1 下载；符号路径组合本地 `symbols/` + Electron symbol server `https://symbols.electronjs.org`
- **download-symbols.ps1** — 从 `https://github.com/electron/electron/releases` 下载指定版本的 `electron-vX.Y.Z-win32-x64-symbols.zip` 并解压到 `symbols/breakpad_symbols/`

符号系统两层：本地预下载的 breakpad `.sym` 文件（`symbols/breakpad_symbols/`）+ minidump-stackwalk 运行时从 Electron symbol server 自动拉取的符号（缓存到 `symbols/`）。

## Symbol Server URLs

- Electron: `https://symbols.electronjs.org`
- Microsoft: `https://msdl.microsoft.com/download/symbols`

WinDbg 符号路径格式：`SRV*C:\workspace\electron-crash\symbols*https://msdl.microsoft.com/download/symbols;SRV*C:\workspace\electron-crash\symbols*https://symbols.electronjs.org`

## .gitignore

`dumps/*.dmp`、`symbols/*`、`reports/*.txt`、`reports/*.json`、`tools/*`、`test-electron/` 均被忽略——这些是大文件或可再生的输出，不纳入版本控制。

## Analysis Guide

详细分析流程和常见崩溃模式（变长结构体越界、V8 ABI 不兼容、Native DLL 加载失败）见 `ANALYSIS-GUIDE.md`。

## Knowledge System

项目维护崩溃分析知识库 `knowledge/`，跨会话积累分析经验。一条知识一个文件，通过索引按需读取。

### 分析流程
1. 先调用 analyze.ps1 生成报告（知识库不影响脚本执行）
2. 读取 `knowledge/README.md` 索引
3. 根据报告中的崩溃类型、关键模块、偏移量等，按需读取对应知识文件（不要全量加载）
4. 结合知识库分析报告，输出诊断结果

### 总结流程
分析完成后评估是否产生新知识（新崩溃模式、新模块识别、新偏移含义、新版本兼容问题）：
- 有新知识 → 检查 `knowledge/README.md` 索引中是否已有相同去重键
  - 已有 → 打开对应文件补充信息（追加来源、修正描述），更新索引摘要如有变化
  - 没有 → 在对应类别目录下创建新文件（文件名用去重键的 kebab-case），在索引中新增一行
- 无新知识 → 不写入

### 去重键规则
| 知识类型 | 去重键 | 文件名示例 |
|---------|--------|-----------|
| 崩溃模式 | 崩溃类型 + 关键模块 | `STATUS_HEAP_CORRUPTION-SogouTSF.md` |
| 模块识别 | 模块文件名 | `tmp-node.md` |
| 偏移量含义 | 模块名 + 偏移量 | `ntdll-0xff489.md` |
| 版本兼容 | Electron版本 + 问题模块 | `electron-39.4.0-koffi.md` |

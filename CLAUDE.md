# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Windows 下分析 Electron `.dmp` crash dump 文件的工具链环境。不是应用代码，而是分析工具集——提供命令行快速分析（minidump-stackwalk）和交互式深度调试（WinDbg Preview）两种能力。

## Key Commands

```powershell
# 安装工具（下载 minidump-stackwalk，可选预下载 Electron 符号）
.\scripts\install-tools.ps1 [-ElectronVersion "39.4.0"] [-Proxy "http://127.0.0.1:7897"]

# 分析 crash dump（核心命令）
.\scripts\analyze.ps1 .\dumps\crash.dmp [-ElectronVersion "39.4.0"] [-Proxy "..."] [-Json]

# 单独下载符号文件
.\scripts\download-symbols.ps1 -ElectronVersion "39.4.0" [-Proxy "..."]
```

分析报告输出到 `reports/` 目录：`<dump-name>.txt`（人类可读堆栈）+ `<dump-name>-modules.json`（模块列表）。

## Architecture

三个 PowerShell 脚本构成工具链，全部使用 `$ProjectRoot = Split-Path $PSScriptRoot -Parent` 定位项目根目录：

- **install-tools.ps1** — 从 GitHub releases 下载 rust-minidump 的 `minidump-stackwalk` 到 `tools/`；可选从 Electron releases 下载 breakpad `.sym` 符号到 `symbols/breakpad_symbols/`
- **analyze.ps1** — 调用 `minidump-stackwalk --symbols-path` 分析 dump，符号路径组合本地 `symbols/` + Electron symbol server `https://symbols.electronjs.org`；若指定 `-ElectronVersion` 且本地无符号会自动调用 install-tools.ps1 下载
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

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Windows 下分析 Electron `.dmp` crash dump 文件的工具链环境。不是应用代码，而是分析工具集——提供命令行快速分析（minidump-stackwalk）和交互式深度调试（WinDbg Preview）两种能力。

## Key Commands

```powershell
# 分析 crash dump（核心命令，一键完成：检测版本 → 安装工具/符号 → 生成报告）
.\scripts\analyze.ps1 .\dumps\crash.dmp [-Proxy "http://127.0.0.1:7897"] [-Json]

# 单独安装工具 + 下载符号
.\scripts\install-tools.ps1 -ElectronVersion "39.4.0" [-Proxy "http://127.0.0.1:7897"]

# 单独下载符号文件
.\scripts\download-symbols.ps1 -ElectronVersion "39.4.0" [-Proxy "http://127.0.0.1:7897"]
```

`analyze.ps1` 是唯一需要直接调用的脚本，它会自动：1) 调用 `detect-version.ps1` 从 dump 检测 Electron 版本；2) 检查 `minidump-stackwalk` 和符号是否存在且版本匹配，缺失时自动调用 `install-tools.ps1`；3) 生成分析报告。

分析报告输出到 `reports/` 目录：`<dump-name>.txt`（人类可读堆栈）+ `<dump-name>-modules.json`（模块列表）。

## Architecture

四个 PowerShell 脚本构成工具链，全部使用 `$ProjectRoot = Split-Path $PSScriptRoot -Parent` 定位项目根目录：

- **install-tools.ps1** — 从 GitHub releases 下载 rust-minidump 的 `minidump-stackwalk` 到 `tools/`；可选从 Electron releases 下载 breakpad `.sym` 符号到 `symbols/breakpad_symbols/`
- **detect-version.ps1** — 从 dump 文件的 Crashpad annotation 中自动检测 Electron 版本，方法1 匹配 `Electron...ver...版本号`，方法2 扫描语义化版本号过滤候选；输出版本号供其它脚本使用
- **analyze.ps1** — 一键分析入口：自动调用 detect-version.ps1 检测版本，检查工具和符号是否就绪（版本匹配），缺失时自动调用 install-tools.ps1，最后调用 `minidump-stackwalk --symbols-path` 生成报告；符号路径组合本地 `symbols/` + Electron symbol server `https://symbols.electronjs.org`
- **download-symbols.ps1** — 从 `https://github.com/electron/electron/releases` 下载指定版本的 `electron-vX.Y.Z-win32-x64-symbols.zip` 并解压到 `symbols/breakpad_symbols/`

符号系统两层：本地预下载的 breakpad `.sym` 文件（`symbols/breakpad_symbols/`）+ minidump-stackwalk 运行时从 Electron symbol server 自动拉取的符号（缓存到 `symbols/`）。

## Symbol Server URLs

- Electron: `https://symbols.electronjs.org`
- Microsoft: `https://msdl.microsoft.com/download/symbols`

WinDbg 符号路径格式：`SRV*C:\workspace\electron-crash\symbols*https://msdl.microsoft.com/download/symbols;SRV*C:\workspace\electron-crash\symbols*https://symbols.electronjs.org`

## .gitignore

`dumps/*.dmp`、`symbols/*`、`reports/*.txt`、`reports/*.json`、`tools/*`、`test-electron/` 均被忽略——这些是大文件或可再生的输出，不纳入版本控制。

## Analysis Guide

常见崩溃模式（变长结构体越界、V8 ABI 不兼容、Native DLL 加载失败）和调用模式识别见知识库 `knowledge/crash-patterns/` 和 `knowledge/module-registry/napi-call-patterns.md`。

## Dump 分析 SOP（标准操作流程）

当用户要求分析 crash dump 时，**必须严格按以下步骤执行**，不得跳过或省略任何步骤。

### 步骤 1：一键生成报告

```powershell
.\scripts\analyze.ps1 .\dumps\<dump-file>
```

该脚本会自动检测 Electron 版本、安装缺失工具和符号、生成分析报告。等待脚本执行完成，确认 `reports/` 下生成了 `<dump-id>.txt` 和 `<dump-id>-modules.json`。

### 步骤 2：解读报告

读取生成的 `<dump-id>.txt` 报告，逐项提取并解读以下关键信息：

**1. 崩溃基本信息（报告头部）**

- **Crash reason** — 崩溃类型
  - `EXCEPTION_ACCESS_VIOLATION_READ/WRITE` → 内存访问违规，通常是越界或 UAF
  - `STATUS_HEAP_CORRUPTION` → 堆损坏
- **Crash address** — 崩溃地址
  - 落在 `guard page` → 读/写了已释放的堆内存
- **Crashing instruction** — 崩溃指令（如 `mov eax, dword [r10]`）
- **Process uptime** — 进程运行时间
  - `< 10s` → 初始化阶段崩溃，大概率是确定性的
  - `> 60s` → 运行时崩溃，可能与特定操作触发有关

**2. 崩溃堆栈（crashed 线程）**

逐帧读取崩溃线程的调用栈，解读方法：
- 帧 #0 是崩溃点，识别它属于哪个模块
- 帧 #1~#N 是调用链，**从下往上读**：哪个函数 → 调用了什么 → 最终崩溃
- 未符号化的帧（只有 `module + offset`，无函数名）→ 记录模块名和偏移量，待步骤 3 查知识库识别
- 堆栈中出现 `napi_*` 函数 → Node.js native addon 调用
- 堆栈中出现 V8 内部函数（如 `JSObject::AddDataElement`、`Object::SetProperty`）→ V8 ABI 层面的问题
- 堆栈中出现 `LoadLibrary` / `dlopen` → DLL 加载问题

**3. 关键模块**

从堆栈和 JSON 模块列表中提取非常规模块（非 ntdll/kernel32 等系统模块），重点关注：
- `.tmp.node` / `.node` 文件 → native addon
- 业务 DLL（如 `liblibpass.dll`）→ 应用自有模块
- 第三方 IME（如 `SogouTSF.ime`）→ 输入法等外部干扰

**4. 调用链模式识别**

根据堆栈中的函数组合，推断可能的原生模块来源：

| 堆栈中的函数组合 | 可能的库/模块 |
|-----------------|-------------|
| `napi_create_object` + FFI 库 + `.tmp.node` | koffi, ffi-napi, node-ffi |
| `napi_create_object` + 业务 DLL | 自定义原生模块 |
| `WlanOpenHandle` / `WlanEnumInterfaces` | wlanapi.dll 调用者（WiFi 扫描） |
| `JSObject::AddDataElement` + guard page | V8 内存布局不匹配（变长结构体越界或 ABI 不兼容） |
| `LoadLibrary` / `dlopen` | DLL 动态加载失败 |

### 步骤 3：查询知识库

读取 `knowledge/README.md` 索引，根据步骤 2 解读出的关键信息，按需读取相关知识文件：

- 崩溃类型 + 关键模块匹配 → 读取 `crash-patterns/` 下对应条目
- 堆栈中出现无名/陌生模块 → 读取 `module-registry/` 下对应条目
- 堆栈中有未符号化的模块偏移 → 读取 `offset-database/` 下对应条目
- 涉及特定 Electron 版本 → 读取 `version-compatibility/` 下对应条目

**不要全量加载知识文件**，只读取与当前报告相关的条目。

### 步骤 4：综合分析并定位源码

结合步骤 2 的解读和步骤 3 的知识库经验，进行综合诊断。分析输出必须包含以下部分：

**1. 崩溃概述**（一段话总结）
- 崩溃类型 + 崩溃地址 + 崩溃线程 + 进程运行时间

**2. 根因分析**（核心部分）
- 从崩溃堆栈的帧 #0 开始，从下往上读调用链
- 识别崩溃点（帧 #0）属于哪个模块，该模块的作用是什么
- 如果帧 #0 是未符号化的模块，引用知识库 module-registry 中的识别结果
- 如果匹配到知识库中的已知崩溃模式，引用该模式的根因分析

**3. 源码定位**
- 从堆栈帧 #0 的模块名，在 JSON 模块列表中搜索 `debug_name`
- 对照项目 `package.json` 中的 native addon 依赖，确定是哪个包引入的
- 如果是 FFI 库调用，追踪到具体的 FFI 调用代码（如 `koffi.load()`、`koffi.decode()`）

**4. 崩溃模式匹配**
- 将当前崩溃特征与知识库 `crash-patterns/` 中的已知模式对比
- 如果匹配到已知模式，引用该模式并给出对应修复建议
- 如果未匹配到已知模式，标注为"新崩溃模式"

**5. 修复建议**（可操作的步骤）
- 给出具体的修复方案，而非笼统的建议
- 如果需要重新编译模块，给出具体的 `electron-rebuild` 命令
- 如果需要修改代码，指出具体文件和修改方向

### 步骤 5：总结并写入知识库

**这是必须执行的步骤，不得跳过。** 分析完成后，评估本次分析是否产生了新知识：

评估以下 4 类知识，对每类给出"有新知识"或"无新知识"的判定：

1. **新崩溃模式** — 当前崩溃的特征组合（崩溃类型 + 关键模块）是否在 `knowledge/crash-patterns/` 中无对应条目？
2. **新模块识别** — 堆栈中是否有无名/陌生模块被成功识别，且该模块在 `knowledge/module-registry/` 中无对应条目？
3. **新偏移量含义** — 是否有未符号化的模块偏移被成功解析出函数名，且该偏移在 `knowledge/offset-database/` 中无对应条目？
4. **新版本兼容问题** — 是否发现了与特定 Electron 版本相关的新兼容问题，且该版本+模块组合在 `knowledge/version-compatibility/` 中无对应条目？

**如果全部为"无新知识"** → 不写入任何内容，结束。

**如果任意一项为"有新知识"** → 执行写入：

1. 读取 `knowledge/README.md` 索引，确认去重键是否已存在
2. 去重键已存在 → 打开对应文件，补充新信息（追加来源、修正描述），如果摘要信息变化则更新索引
3. 去重键不存在 → 在对应类别目录下创建新 Markdown 文件（文件名 = 去重键的 kebab-case），在 `knowledge/README.md` 索引中新增一行链接

写入后，确认索引与文件一一对应。

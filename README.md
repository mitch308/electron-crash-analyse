# Electron Crash Dump 分析环境

Windows 下分析 Electron `.dmp` crash dump 文件的完整工具链。

## 快速开始

### 1. 安装工具

```powershell
# 基础安装（minidump-stackwalk）
.\scripts\install-tools.ps1

# 预下载 Electron 符号文件（加速后续分析）
.\scripts\install-tools.ps1 -ElectronVersion "39.4.0"

# 使用代理（如网络受限）
.\scripts\install-tools.ps1 -ElectronVersion "39.4.0" -Proxy "http://127.0.0.1:7897"
```

### 2. 分析 crash dump

```powershell
# 快速分析（自动下载缺失符号）
.\scripts\analyze.ps1 .\dumps\crash.dmp

# 指定 Electron 版本（自动下载对应符号）
.\scripts\analyze.ps1 .\dumps\crash.dmp -ElectronVersion "39.4.0"

# 输出 JSON 模块信息
.\scripts\analyze.ps1 .\dumps\crash.dmp -Json
```

报告输出到 `reports/` 目录。

## 两种分析方式

### 方式 A：命令行快速分析（minidump-stackwalk）

```powershell
.\scripts\analyze.ps1 .\dumps\crash.dmp
```

自动从 Electron 和 Microsoft 符号服务器下载符号，输出人类可读的堆栈报告 + JSON 模块列表。

### 方式 B：交互式深度分析（WinDbg Preview）

1. 安装 [WinDbg Preview](https://apps.microsoft.com/detail/9PGJGD53TN86)
2. 打开 → File → Open Dump File → 选择 `.dmp` 文件
3. 设置符号路径（File → Symbol File Path）：

```
SRV*C:\workspace\electron-crash\symbols*https://msdl.microsoft.com/download/symbols;SRV*C:\workspace\electron-crash\symbols*https://symbols.electronjs.org
```

4. 运行 `.reload` 加载符号
5. 常用命令：`!analyze -v`, `kv`, `r`, `!peb`

## 目录结构

```
├── dumps/          # 放置 .dmp 文件
├── symbols/        # 符号文件缓存
│   └── breakpad_symbols/   # 预下载的 Electron 符号 (.sym 文件)
├── reports/        # 分析报告（.txt + .json）
├── tools/          # minidump-stackwalk 二进制
├── scripts/        # 工具脚本
│   ├── install-tools.ps1      # 安装 minidump-stackwalk + Electron 符号
│   ├── analyze.ps1            # 一键分析 dump
│   └── download-symbols.ps1   # 单独下载符号
└── README.md
```

## 分析指南

详细分析流程和常见崩溃模式见 [ANALYSIS-GUIDE.md](ANALYSIS-GUIDE.md)。

## 常见问题

### Q: 符号下载很慢？

首次分析需要下载大量符号文件（几十到几百 MB），请耐心等待。后续运行会使用本地缓存，速度会快很多。建议先用 `install-tools.ps1 -ElectronVersion` 预下载。

### Q: 提示找不到符号？

1. 确保 `symbols/breakpad_symbols/` 目录中有对应 `.sym` 文件
2. 确认符号路径中的 `debug_id` 与 dump 中的模块匹配
3. 尝试 `download-symbols.ps1 -ElectronVersion "版本号"` 重新下载

### Q: 如何查看 Electron 版本？

从 `reports/*-modules.json` 中的主进程 exe 文件名和版本号可以找到。或者查看 `package.json` 中 `electron` 依赖版本。

### Q: WinDbg 加载符号失败？

1. 确认符号路径格式正确（`SRV*缓存路径*服务器URL`）
2. 确认网络连接正常
3. 尝试清除 `symbols/` 目录后重试

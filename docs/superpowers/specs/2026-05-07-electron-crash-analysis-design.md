# Electron Crash Dump 分析环境设计

## 目标

在 Windows 环境下搭建分析 Electron `.dmp` crash dump 文件的工具链，包含快速命令行分析和深度交互式调试两种能力。

## 架构

```
electron-crash/
├── dumps/              # 放置 .dmp 文件
├── symbols/            # Electron + Windows 符号文件缓存
├── reports/            # stackwalk 分析报告输出
├── tools/              # 工具二进制文件
│   └── minidump-stackwalk.exe
├── scripts/
│   ├── analyze.ps1     # 一键分析脚本
│   └── download-symbols.ps1 # 手动下载符号
└── README.md           # 使用说明
```

## 组件

### 1. minidump-stackwalk（快速分析）

- 使用 Mozilla 预编译的 `minidump-stackwalk` Windows 版本
- 配置 Electron symbol server：`https://symbols.electronjs.org/`
- 一键脚本自动拉取符号并生成可读堆栈报告

### 2. WinDbg Preview（深度分析）

- 从 Microsoft Store 安装
- 符号路径配置：Microsoft 符号服务器 + Electron 符号服务器
- 支持交互式调试：查看内存、寄存器、变量、源码

### 3. 辅助脚本 analyze.ps1

- 接受 `.dmp` 文件路径作为参数
- 调用 minidump-stackwalk 自动下载符号
- 生成人类可读报告到 `reports/` 目录
- 报告包含：崩溃线程、完整堆栈、寄存器状态、模块列表

## 使用流程

1. 将 `.dmp` 文件放到 `dumps/` 目录
2. 快速分析：`.\scripts\analyze.ps1 .\dumps\your-crash.dmp`
3. 深度分析：`WinDbg` 打开 dump 文件，命令行：`windbg -z .\dumps\your-crash.dmp`

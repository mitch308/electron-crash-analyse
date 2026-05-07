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

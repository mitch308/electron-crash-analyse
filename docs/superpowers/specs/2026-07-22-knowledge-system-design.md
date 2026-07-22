# 崩溃分析知识库设计

## 目标

为 Electron crash dump 分析工具链增加知识库系统，使 Claude Code 在分析崩溃时能跨会话积累经验，实现"越分析越准"的自我进化能力。

## 核心理念

- **AI 是大脑，脚本是工具** — 智能诊断由 Claude Code 完成，脚本只负责机械分析
- **按需读取** — 先读索引，再按需加载具体知识条目，避免上下文膨胀
- **一条知识一个文件** — 精准读取、Git 历史清晰、去重通过索引完成
- **只增不减** — 新知识追加/补充，旧知识可标记过时但不删除

## 架构

```
用户请求分析 dump
       ↓
Claude Code 调用 analyze.ps1 生成报告（纯脚本，无需知识库）
       ↓
Claude Code 读取 knowledge/README.md 索引
       ↓
根据报告关键信息（崩溃类型、模块、偏移量）按需读取相关知识文件
       ↓
结合知识库分析报告，输出诊断结果
       ↓
评估是否产生新知识
  ├── 有 → 写入知识库 + 更新索引
  └── 无 → 结束
```

## 知识库结构

```
knowledge/
├── README.md                                    # 索引（每条知识一行摘要）
├── crash-patterns/                              # 崩溃模式
│   ├── STATUS_HEAP_CORRUPTION-SogouTSF.md
│   └── ACCESS_VIOLATION-koffi-tmp-node.md
├── module-registry/                             # 模块识别映射
│   ├── tmp-node.md
│   └── liblibpass-dll.md
├── offset-database/                             # 偏移量含义
│   └── ntdll-0xff489.md
└── version-compatibility/                       # 版本兼容问题
    └── electron-39.4.0-koffi.md
```

### 文件命名规则

用去重键生成 kebab-case 文件名，确保唯一且可从索引直接定位：

| 知识类型 | 去重键 | 文件名示例 |
|---------|--------|-----------|
| 崩溃模式 | 崩溃类型 + 关键模块 | `STATUS_HEAP_CORRUPTION-SogouTSF.md` |
| 模块识别 | 模块文件名 | `tmp-node.md` |
| 偏移量含义 | 模块名 + 偏移量 | `ntdll-0xff489.md` |
| 版本兼容 | Electron版本 + 问题模块 | `electron-39.4.0-koffi.md` |

## 知识条目格式

每条知识是一个独立 Markdown 文件，格式统一：

### crash-patterns/ 条目

```markdown
# STATUS_HEAP_CORRUPTION + SogouTSF.ime

- **崩溃类型**: STATUS_HEAP_CORRUPTION
- **关键模块**: SogouTSF.ime, ntdll.dll
- **特征**: 崩溃线程名含 ThreadPoolSingleThreadCOMSTA，uptime 25-38s
- **根因**: 搜狗输入法 TSF 实现触发堆损坏，与 Electron 的 COM 线程池交互时出问题
- **修复建议**: 排查搜狗输入法版本，考虑切换输入法或升级搜狗
- **来源**: 36a2aa34/9910f104/cc37fea4 三份 dump 分析
- **日期**: 2026-07-22
```

### module-registry/ 条目

```markdown
# .tmp.node

- **实际身份**: koffi/FFI 库的临时解压模块
- **识别方法**: 模块名匹配 `.tmp.node`，通常在 koffi.load() 调用链中出现
- **常见关联**: napi_create_object, JSObject::AddDataElement
- **来源**: ANALYSIS-GUIDE.md 已修复案例
- **日期**: 2026-05-07
```

### offset-database/ 条目

```markdown
# ntdll.dll + 0xff489

- **函数**: RtlReportFatalHeapCorruption
- **含义**: 堆损坏被检测到后的致命报告入口
- **常见崩溃类型**: STATUS_HEAP_CORRUPTION
- **来源**: 36a2aa34 dump 分析
- **日期**: 2026-07-22
```

### version-compatibility/ 条目

```markdown
# Electron 39.4.0 + koffi

- **问题**: koffi.decode() 读取变长结构体（如 WLAN_INTERFACE_INFO_LIST）时越界
- **触发条件**: WiFi 扫描调用 WlanEnumInterfaces
- **修复**: 用 koffi.view() 读取实际大小 + koffi.decode() 切片解析
- **来源**: ANALYSIS-GUIDE.md 已修复案例
- **日期**: 2026-05-07
```

## 索引格式

`knowledge/README.md` 每条知识一行摘要，按类别分组：

```markdown
# 崩溃分析知识库索引

## crash-patterns/
- [STATUS_HEAP_CORRUPTION + SogouTSF](crash-patterns/STATUS_HEAP_CORRUPTION-SogouTSF.md) — 搜狗输入法触发堆损坏
- [ACCESS_VIOLATION + koffi .tmp.node](crash-patterns/ACCESS_VIOLATION-koffi-tmp-node.md) — koffi FFI 变长结构体越界

## module-registry/
- [.tmp.node](module-registry/tmp-node.md) — koffi/FFI 临时解压模块
- [liblibpass.dll](module-registry/liblibpass-dll.md) — 国信智会加密库

## offset-database/
- [ntdll.dll + 0xff489](offset-database/ntdll-0xff489.md) — RtlReportFatalHeapCorruption

## version-compatibility/
- [Electron 39.4.0 + koffi](version-compatibility/electron-39.4.0-koffi.md) — 变长结构体越界问题
```

## 去重与更新策略

### 去重判定

写入前通过索引检查去重键是否已存在：

| 知识类型 | 去重键 | 重复时行为 |
|---------|--------|-----------|
| 崩溃模式 | 崩溃类型 + 关键模块 | 补充来源/修正描述 |
| 模块识别 | 模块文件名 | 补充识别方法/常见关联 |
| 偏移量含义 | 模块名 + 偏移量 | 跳过（已有则不覆盖） |
| 版本兼容 | Electron版本 + 问题模块 | 补充触发条件/修复方案 |

### 更新方式

- **补充**：同一去重键下发现新信息（新来源 dump、更精确根因、新修复方案），在现有条目中追加，不覆盖
- **修正**：发现原有描述有误，直接修正错误部分，保留来源记录
- **新增**：去重键不存在，创建新文件 + 在索引中新增一行

### 索引同步

每次写入知识条目后，必须同步更新 `knowledge/README.md` 索引。

## CLAUDE.md 指令

在 CLAUDE.md 中新增 Knowledge System 章节：

```markdown
## Knowledge System

项目维护崩溃分析知识库 `knowledge/`，跨会话积累分析经验。

### 分析流程
1. 先调用 analyze.ps1 生成报告
2. 读取 `knowledge/README.md` 索引
3. 根据报告中的崩溃类型、关键模块、偏移量等，按需读取对应知识文件
4. 结合知识库分析报告，输出诊断结果

### 总结流程
分析完成后评估是否产生新知识（新崩溃模式、新模块识别、新偏移含义、新版本兼容问题）：
- 有新知识 → 检查索引中是否已有相同去重键，补充或新增条目，同步更新索引
- 无新知识 → 不写入
```

## 文件变更清单

### 新增

| 文件 | 说明 |
|------|------|
| `knowledge/README.md` | 知识库索引 |
| `knowledge/crash-patterns/STATUS_HEAP_CORRUPTION-SogouTSF.md` | 初始知识：搜狗输入法堆损坏 |
| `knowledge/crash-patterns/ACCESS_VIOLATION-koffi-tmp-node.md` | 初始知识：koffi 变长结构体越界 |
| `knowledge/crash-patterns/V8-ABI-incompatibility.md` | 初始知识：V8 ABI 不兼容 |
| `knowledge/crash-patterns/DLL-load-failure.md` | 初始知识：Native DLL 加载失败 |
| `knowledge/module-registry/tmp-node.md` | 初始知识：.tmp.node 模块识别 |
| `knowledge/offset-database/ntdll-0xff489.md` | 初始知识：ntdll 偏移含义 |
| `knowledge/version-compatibility/electron-39.4.0-koffi.md` | 初始知识：Electron 39.4.0 koffi 兼容问题 |

### 修改

| 文件 | 变更 |
|------|------|
| `CLAUDE.md` | 新增 Knowledge System 章节 |

### 不变更

- `scripts/analyze.ps1` — 纯脚本分析流程不受影响
- `scripts/install-tools.ps1` — 不变
- `scripts/download-symbols.ps1` — 不变
- `ANALYSIS-GUIDE.md` — 保留，仍作为人类阅读的分析指南

### .gitignore

`knowledge/` 目录**不加入 .gitignore** — 知识库是项目核心资产，纳入版本控制。

## 初始知识来源

从 `ANALYSIS-GUIDE.md` 中提取已有经验作为初始知识库内容，包括：
- 3 种已知崩溃模式（变长结构体越界、V8 ABI 不兼容、Native DLL 加载失败）
- 模块识别映射（.tmp.node → koffi）
- 已有 dump 分析中发现的偏移量含义

# Knowledge System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建崩溃分析知识库，使 Claude Code 能跨会话积累分析经验，越分析越准。

**Architecture:** 纯文件型知识库，一条知识一个 Markdown 文件，按类型分目录存放。README.md 作为索引用于按需定位，不修改任何现有脚本，通过 CLAUDE.md 指令驱动 Claude Code 的读写行为。

**Tech Stack:** Markdown 文件 + Claude Code 的 Read/Write/Edit 工具

## Global Constraints

- 知识库目录 `knowledge/` 不加入 .gitignore，纳入版本控制
- 每条知识一个独立 Markdown 文件，文件名由去重键生成 kebab-case
- 索引文件 `knowledge/README.md` 每条知识一行摘要，按类别分组
- 不修改任何现有 PowerShell 脚本
- 初始知识从 `ANALYSIS-GUIDE.md` 和已有 dump 分析中提取

---

### Task 1: 创建知识库目录结构和索引

**Files:**
- Create: `knowledge/README.md`
- Create: `knowledge/crash-patterns/.gitkeep`
- Create: `knowledge/module-registry/.gitkeep`
- Create: `knowledge/offset-database/.gitkeep`
- Create: `knowledge/version-compatibility/.gitkeep`

**Interfaces:**
- Produces: `knowledge/README.md` 索引文件，后续 Task 的知识条目需要在此文件中注册

- [ ] **Step 1: 创建知识库目录结构**

```powershell
New-Item -ItemType Directory -Path "knowledge\crash-patterns" -Force
New-Item -ItemType Directory -Path "knowledge\module-registry" -Force
New-Item -ItemType Directory -Path "knowledge\offset-database" -Force
New-Item -ItemType Directory -Path "knowledge\version-compatibility" -Force
New-Item -ItemType File -Path "knowledge\crash-patterns\.gitkeep" -Force
New-Item -ItemType File -Path "knowledge\module-registry\.gitkeep" -Force
New-Item -ItemType File -Path "knowledge\offset-database\.gitkeep" -Force
New-Item -ItemType File -Path "knowledge\version-compatibility\.gitkeep" -Force
```

- [ ] **Step 2: 创建索引文件 `knowledge/README.md`**

```markdown
# 崩溃分析知识库索引

读取方式：先读本索引定位相关知识，再按需读取具体文件，避免上下文膨胀。

## crash-patterns/

（暂无条目）

## module-registry/

（暂无条目）

## offset-database/

（暂无条目）

## version-compatibility/

（暂无条目）
```

- [ ] **Step 3: 验证目录结构**

Run: `Get-ChildItem -Path knowledge -Recurse | Select-Object FullName`
Expected: README.md + 4 个子目录各含 .gitkeep

- [ ] **Step 4: 提交**

```bash
git add knowledge/
git commit -m "feat: create knowledge base directory structure and index"
```

---

### Task 2: 写入初始崩溃模式知识

**Files:**
- Create: `knowledge/crash-patterns/STATUS_HEAP_CORRUPTION-SogouTSF.md`
- Create: `knowledge/crash-patterns/ACCESS_VIOLATION-koffi-tmp-node.md`
- Create: `knowledge/crash-patterns/V8-ABI-incompatibility.md`
- Create: `knowledge/crash-patterns/DLL-load-failure.md`
- Modify: `knowledge/README.md` — 更新 crash-patterns 索引

**Interfaces:**
- Consumes: `knowledge/README.md`（来自 Task 1）
- Produces: 4 个崩溃模式知识文件 + 更新的索引

- [ ] **Step 1: 创建 STATUS_HEAP_CORRUPTION + SogouTSF 知识文件**

Write `knowledge/crash-patterns/STATUS_HEAP_CORRUPTION-SogouTSF.md`:

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

- [ ] **Step 2: 创建 ACCESS_VIOLATION + koffi .tmp.node 知识文件**

Write `knowledge/crash-patterns/ACCESS_VIOLATION-koffi-tmp-node.md`:

```markdown
# EXCEPTION_ACCESS_VIOLATION + .tmp.node (koffi)

- **崩溃类型**: EXCEPTION_ACCESS_VIOLATION_READ / EXCEPTION_ACCESS_VIOLATION_WRITE
- **关键模块**: .tmp.node, electron.exe (V8 internals)
- **特征**: 崩溃地址落在 guard page；调用链含 koffi.decode() → napi_create_object → JSObject::AddDataElement；uptime 通常 < 10s（初始化阶段）
- **根因**: koffi.decode() 读取变长结构体时按固定大小分配的内存读取，超出实际分配命中 guard page。典型场景：WLAN_INTERFACE_INFO_LIST 定义了固定长度 64 元素数组，实际数据远小于此
- **修复建议**: 用 koffi.view() 读取实际大小的内存 + koffi.decode() 切片解析
- **来源**: ANALYSIS-GUIDE.md 已修复案例；源码参考 C:\workspace\node-wifi\src\windows\wlan-scan.js
- **日期**: 2026-05-07
```

- [ ] **Step 3: 创建 V8 ABI 不兼容知识文件**

Write `knowledge/crash-patterns/V8-ABI-incompatibility.md`:

```markdown
# V8 ABI 不兼容

- **崩溃类型**: EXCEPTION_ACCESS_VIOLATION（V8 内部函数中）
- **关键模块**: 原生 .node 文件, electron.exe (V8 internals)
- **特征**: 崩溃在 napi_create_object 等 N-API 函数内部；调用链进入 V8 内部函数（如 JSObject::AddDataElement、Object::SetProperty）；Electron 升级后新出现
- **根因**: 原生模块不是针对当前 Electron 的 V8 版本编译的，napi_create_object 内部访问错误的内存偏移
- **修复建议**: 用 electron-rebuild 重新编译原生模块：`npx electron-rebuild -v <electron-version> -f`
- **来源**: ANALYSIS-GUIDE.md
- **日期**: 2026-05-07
```

- [ ] **Step 4: 创建 Native DLL 加载失败知识文件**

Write `knowledge/crash-patterns/DLL-load-failure.md`:

```markdown
# Native DLL 加载失败

- **崩溃类型**: 多种（取决于调用方式，可能在 LoadLibrary/dlopen 处崩溃）
- **关键模块**: 目标 DLL（如 xxx.dll）
- **特征**: 崩溃在 koffi.load('xxx.dll') 或类似调用；堆栈中能看到 LoadLibrary 或 dlopen
- **根因**: DLL 不存在、架构不匹配（x64 vs arm64）、或缺少依赖 DLL
- **修复建议**: 用 Dependency Walker 或 Process Monitor 检查 DLL 加载链；确认 DLL 存在且架构匹配；检查依赖 DLL 是否完整
- **来源**: ANALYSIS-GUIDE.md
- **日期**: 2026-05-07
```

- [ ] **Step 5: 更新索引 README.md 的 crash-patterns 部分**

将 `knowledge/README.md` 中的 crash-patterns 部分替换为：

```markdown
## crash-patterns/
- [STATUS_HEAP_CORRUPTION + SogouTSF](crash-patterns/STATUS_HEAP_CORRUPTION-SogouTSF.md) — 搜狗输入法触发堆损坏
- [ACCESS_VIOLATION + koffi .tmp.node](crash-patterns/ACCESS_VIOLATION-koffi-tmp-node.md) — koffi FFI 变长结构体越界
- [V8 ABI 不兼容](crash-patterns/V8-ABI-incompatibility.md) — 原生模块与 Electron V8 版本不匹配
- [DLL 加载失败](crash-patterns/DLL-load-failure.md) — Native DLL 不存在或架构不匹配
```

- [ ] **Step 6: 提交**

```bash
git add knowledge/
git commit -m "feat: add initial crash pattern knowledge entries"
```

---

### Task 3: 写入初始模块识别知识

**Files:**
- Create: `knowledge/module-registry/tmp-node.md`
- Modify: `knowledge/README.md` — 更新 module-registry 索引

**Interfaces:**
- Consumes: `knowledge/README.md`（来自 Task 2）
- Produces: 模块识别知识文件 + 更新的索引

- [ ] **Step 1: 创建 .tmp.node 模块识别知识文件**

Write `knowledge/module-registry/tmp-node.md`:

```markdown
# .tmp.node

- **实际身份**: koffi/FFI 库的临时解压模块
- **识别方法**: 模块名匹配 `.tmp.node`，通常在 koffi.load() 调用链中出现
- **常见关联**: napi_create_object, JSObject::AddDataElement, koffi.decode()
- **来源**: ANALYSIS-GUIDE.md 已修复案例
- **日期**: 2026-05-07
```

- [ ] **Step 2: 更新索引 README.md 的 module-registry 部分**

将 `knowledge/README.md` 中的 module-registry 部分替换为：

```markdown
## module-registry/
- [.tmp.node](module-registry/tmp-node.md) — koffi/FFI 临时解压模块
```

- [ ] **Step 3: 提交**

```bash
git add knowledge/
git commit -m "feat: add initial module registry knowledge entry"
```

---

### Task 4: 写入初始偏移量含义知识

**Files:**
- Create: `knowledge/offset-database/ntdll-0xff489.md`
- Modify: `knowledge/README.md` — 更新 offset-database 索引

**Interfaces:**
- Consumes: `knowledge/README.md`（来自 Task 3）
- Produces: 偏移量知识文件 + 更新的索引

- [ ] **Step 1: 创建 ntdll.dll + 0xff489 偏移量知识文件**

Write `knowledge/offset-database/ntdll-0xff489.md`:

```markdown
# ntdll.dll + 0xff489

- **函数**: RtlReportFatalHeapCorruption
- **含义**: 堆损坏被检测到后的致命报告入口，触发 STATUS_HEAP_CORRUPTION 异常
- **常见崩溃类型**: STATUS_HEAP_CORRUPTION
- **注意**: 此偏移对应 Windows 10.0.19045 版本的 ntdll.dll，不同系统版本偏移可能不同
- **来源**: 36a2aa34/9910f104/cc37fea4 三份 dump 分析
- **日期**: 2026-07-22
```

- [ ] **Step 2: 更新索引 README.md 的 offset-database 部分**

将 `knowledge/README.md` 中的 offset-database 部分替换为：

```markdown
## offset-database/
- [ntdll.dll + 0xff489](offset-database/ntdll-0xff489.md) — RtlReportFatalHeapCorruption
```

- [ ] **Step 3: 提交**

```bash
git add knowledge/
git commit -m "feat: add initial offset database knowledge entry"
```

---

### Task 5: 写入初始版本兼容知识

**Files:**
- Create: `knowledge/version-compatibility/electron-39.4.0-koffi.md`
- Modify: `knowledge/README.md` — 更新 version-compatibility 索引

**Interfaces:**
- Consumes: `knowledge/README.md`（来自 Task 4）
- Produces: 版本兼容知识文件 + 更新的索引

- [ ] **Step 1: 创建 Electron 39.4.0 + koffi 版本兼容知识文件**

Write `knowledge/version-compatibility/electron-39.4.0-koffi.md`:

```markdown
# Electron 39.4.0 + koffi

- **问题**: koffi.decode() 读取变长结构体（如 WLAN_INTERFACE_INFO_LIST）时越界
- **触发条件**: WiFi 扫描调用 WlanEnumInterfaces
- **修复**: 用 koffi.view() 读取实际大小 + koffi.decode() 切片解析
- **源码参考**: C:\workspace\node-wifi\src\windows\wlan-scan.js
- **来源**: ANALYSIS-GUIDE.md 已修复案例
- **日期**: 2026-05-07
```

- [ ] **Step 2: 更新索引 README.md 的 version-compatibility 部分**

将 `knowledge/README.md` 中的 version-compatibility 部分替换为：

```markdown
## version-compatibility/
- [Electron 39.4.0 + koffi](version-compatibility/electron-39.4.0-koffi.md) — 变长结构体越界问题
```

- [ ] **Step 3: 提交**

```bash
git add knowledge/
git commit -m "feat: add initial version compatibility knowledge entry"
```

---

### Task 6: 更新 CLAUDE.md 添加 Knowledge System 指令

**Files:**
- Modify: `CLAUDE.md` — 新增 Knowledge System 章节

**Interfaces:**
- Consumes: `knowledge/README.md` 索引格式（来自 Task 5）
- Produces: CLAUDE.md 中的 Knowledge System 行为指令，驱动 Claude Code 读写知识库

- [ ] **Step 1: 在 CLAUDE.md 末尾追加 Knowledge System 章节**

在 `CLAUDE.md` 的 `## Analysis Guide` 章节之后追加：

```markdown

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
```

- [ ] **Step 2: 验证 CLAUDE.md 格式正确**

Run: `Get-Content CLAUDE.md | Select-String "Knowledge System"`
Expected: 输出包含 "## Knowledge System" 行

- [ ] **Step 3: 提交**

```bash
git add CLAUDE.md
git commit -m "feat: add Knowledge System instructions to CLAUDE.md"
```

---

### Task 7: 清理 .gitkeep 文件并最终验证

**Files:**
- Delete: `knowledge/crash-patterns/.gitkeep`
- Delete: `knowledge/module-registry/.gitkeep`
- Delete: `knowledge/offset-database/.gitkeep`
- Delete: `knowledge/version-compatibility/.gitkeep`
- Modify: `knowledge/README.md` — 删除索引中"暂无条目"占位文本（已在前面 Task 中替换）

**Interfaces:**
- Consumes: 所有前序 Task 的产出

- [ ] **Step 1: 删除 .gitkeep 文件（目录已有实际知识文件，不再需要占位）**

```powershell
Remove-Item "knowledge\crash-patterns\.gitkeep" -Force
Remove-Item "knowledge\module-registry\.gitkeep" -Force
Remove-Item "knowledge\offset-database\.gitkeep" -Force
Remove-Item "knowledge\version-compatibility\.gitkeep" -Force
```

- [ ] **Step 2: 验证知识库完整性**

Run: `Get-ChildItem -Path knowledge -Recurse -File | Select-Object FullName`
Expected 输出：
```
knowledge\README.md
knowledge\crash-patterns\STATUS_HEAP_CORRUPTION-SogouTSF.md
knowledge\crash-patterns\ACCESS_VIOLATION-koffi-tmp-node.md
knowledge\crash-patterns\V8-ABI-incompatibility.md
knowledge\crash-patterns\DLL-load-failure.md
knowledge\module-registry\tmp-node.md
knowledge\offset-database\ntdll-0xff489.md
knowledge\version-compatibility\electron-39.4.0-koffi.md
```

- [ ] **Step 3: 验证索引与文件一一对应**

读取 `knowledge/README.md`，确认每个链接指向的文件都存在，确认每个知识文件都在索引中有对应条目。

- [ ] **Step 4: 验证 CLAUDE.md 包含 Knowledge System 指令**

Run: `Select-String -Path CLAUDE.md -Pattern "Knowledge System"`
Expected: 匹配到 `## Knowledge System`

- [ ] **Step 5: 提交**

```bash
git add -A knowledge/
git commit -m "chore: clean up .gitkeep files, knowledge base fully initialized"
```

# Electron Crash Dump 分析指南

## 标准分析流程

### 第一步：检测 Electron 版本

```powershell
# 从 dump 文件自动检测 Electron 版本
$ver = .\scripts\detect-version.ps1 .\dumps\crash.dmp
```

### 第二步：安装工具与符号

```powershell
# 首次使用或本地缺少符号时，安装 minidump-stackwalk + Electron 符号
.\scripts\install-tools.ps1 -ElectronVersion $ver

# 如需代理
.\scripts\install-tools.ps1 -ElectronVersion $ver -Proxy "http://127.0.0.1:7897"
```

### 第三步：分析 crash dump

```powershell
.\scripts\analyze.ps1 .\dumps\crash.dmp -ElectronVersion $ver
```

这会生成两个文件：
- `reports/<dump-id>.txt` — 人类可读的堆栈报告
- `reports/<dump-id>-modules.json` — JSON 格式的模块列表

> **提示**: `analyze.ps1` 会在本地缺少符号时自动调用 `install-tools.ps1` 下载，
> 所以第二步也可以跳过，直接运行第三步。

### 第四步：解读报告

关注以下关键信息：

#### 1. 崩溃基本信息（报告头部）

```
Crash reason:  EXCEPTION_ACCESS_VIOLATION_READ
Crash address:  0x000003d0209cf19c
Crashing instruction: `mov eax, dword [r10]`
Process uptime: 7 seconds
```

- `EXCEPTION_ACCESS_VIOLATION_READ/WRITE` — 内存访问违规，通常是越界或 UAF
- `Crash address` 落在 `guard page` — 读/写了已释放的堆内存
- `uptime < 10s` — 初始化阶段崩溃，大概率是确定性的

#### 2. 崩溃堆栈（Thread 0 CrBrowserMain）

```
 0  <crash-module>.tmp.node + 0x24484
 1  electron.exe!v8::internal::JSObject::AddDataElement ...
 2  electron.exe!v8::internal::Object::SetProperty ...
 3  electron.exe!v8::Object::New ...
 4  electron.exe!napi_create_object ...
 5  <crash-module>.tmp.node + 0x497e
```

**解读方法**：
- 帧 #0 是崩溃点，通常是未符号化的 `.tmp.node` 模块
- 帧 #1~#N 是调用链，从下往上读：**哪个函数 → 调用了什么 → 最终崩溃**
- 帧 #4 `napi_create_object` 表明原生模块在创建 V8 对象
- 帧 #1 `JSObject::AddDataElement` 访问 guard page = 内存布局不匹配

#### 3. 模块列表（JSON 报告）

```powershell
# 提取关键模块信息
python -c "
import json
with open('reports/<dump-id>-modules.json', encoding='utf-8') as f:
    data = json.load(f)
crash = data['crashes'][0]
for m in crash['modules']:
    name = m.get('debug_name', '')
    if any(kw in name.lower() for kw in ['.node', 'koffi', 'electron', 'your-app']):
        print(name, m.get('version', 'N/A'))
"
```

### 第五步：定位源码

#### 通过模块名称定位

1. 从堆栈帧 #0 的 `.tmp.node` 文件名无法直接判断来源
2. 在 JSON 模块列表中搜索对应模块的 `debug_name`
3. 对照项目 `package.json` 中的 native addon 依赖

#### 通过调用链定位

如果堆栈中有 `napi_*` 或 V8 调用，说明是 Node.js native addon：

| 调用模式 | 可能的库 |
|-----------|---------|
| `napi_create_object` + FFI 库 | koffi, ffi-napi, node-ffi |
| `napi_create_object` + 业务 DLL | 自定义原生模块 |
| `WlanOpenHandle` / `WlanEnumInterfaces` | wlanapi.dll 调用者 |

## 常见崩溃模式

### 模式 1：变长结构体越界读取（已修复案例）

**症状**：
- 崩溃模块：`.tmp.node`（koffi/FFI 库）
- 调用链：`koffi.decode() → napi_create_object → JSObject::AddDataElement → guard page`
- 触发时机：WiFi 扫描时调用 `WlanEnumInterfaces`

**根因**：`WLAN_INTERFACE_INFO_LIST` 是 Windows 变长结构体，代码定义了固定长度 64 个元素的数组，`koffi.decode()` 读取超出实际分配内存的 34KB 数据，命中 guard page。

**修复**：用 `koffi.view()` 读取实际大小的内存 + `koffi.decode()` 切片解析。

**源码参考**：`C:\workspace\node-wifi\src\windows\wlan-scan.js`

### 模式 2：V8 ABI 不兼容

**症状**：
- 崩溃模块：原生 `.node` 文件
- 调用链进入 V8 内部函数
- Electron 升级后新出现

**原因**：原生模块不是针对当前 Electron 的 V8 版本编译的，`napi_create_object` 内部访问错误的内存偏移。

**修复**：用 `electron-rebuild` 重新编译原生模块。

```bash
npx electron-rebuild -v <electron-version> -f
```

### 模式 3：Native DLL 加载失败

**症状**：
- 崩溃在 `koffi.load('xxx.dll')` 或类似调用
- 堆栈中能看到 `LoadLibrary` 或 `dlopen`

**原因**：DLL 不存在、架构不匹配（x64 vs arm64）、或缺少依赖 DLL。

**排查**：用 Dependency Walker 或 Process Monitor 检查 DLL 加载链。

## 工具速查

| 工具 | 用途 | 命令 |
|------|------|------|
| detect-version | 从 dump 检测 Electron 版本 | `.\scripts\detect-version.ps1 <dump>` |
| install-tools | 安装工具 + 下载符号 | `.\scripts\install-tools.ps1 -ElectronVersion $ver` |
| analyze | 分析 dump 生成报告 | `.\scripts\analyze.ps1 <dump> -ElectronVersion $ver` |
| download-symbols | 单独下载符号 | `.\scripts\download-symbols.ps1 -ElectronVersion $ver` |
| WinDbg Preview | 交互式深度调试 | 打开 dump → `.reload` → `!analyze -v` |

## 符号下载

```powershell
# 从 dump 检测版本
$ver = .\scripts\detect-version.ps1 .\dumps\crash.dmp

# 方式 1：analyze.ps1 自动拉取（本地无符号时自动下载，推荐）
.\scripts\analyze.ps1 .\dumps\crash.dmp -ElectronVersion $ver

# 方式 2：通过 install-tools 预下载
.\scripts\install-tools.ps1 -ElectronVersion $ver

# 方式 3：单独下载符号
.\scripts\download-symbols.ps1 -ElectronVersion $ver
```

## 代理配置

如果网络受限，所有脚本都支持 `-Proxy` 参数：

```powershell
$proxy = "http://127.0.0.1:7897"
$ver = .\scripts\detect-version.ps1 .\dumps\crash.dmp
.\scripts\install-tools.ps1 -ElectronVersion $ver -Proxy $proxy
.\scripts\analyze.ps1 .\dumps\crash.dmp -ElectronVersion $ver -Proxy $proxy
```

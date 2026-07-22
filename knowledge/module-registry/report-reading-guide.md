# 报告解读方法

- **实际身份**: minidump-stackwalk 输出报告的解读方法论
- **识别方法**: 分析 dump 报告时参照本文件
- **解读规则**:

## 崩溃基本信息（报告头部）

```
Crash reason:  EXCEPTION_ACCESS_VIOLATION_READ
Crash address:  0x000003d0209cf19c
Crashing instruction: `mov eax, dword [r10]`
Process uptime: 7 seconds
```

- `EXCEPTION_ACCESS_VIOLATION_READ/WRITE` — 内存访问违规，通常是越界或 UAF
- `Crash address` 落在 `guard page` — 读/写了已释放的堆内存
- `uptime < 10s` — 初始化阶段崩溃，大概率是确定性的

## 崩溃堆栈解读

```
 0  <crash-module>.tmp.node + 0x24484
 1  electron.exe!v8::internal::JSObject::AddDataElement ...
 2  electron.exe!v8::internal::Object::SetProperty ...
 3  electron.exe!v8::Object::New ...
 4  electron.exe!napi_create_object ...
 5  <crash-module>.tmp.node + 0x497e
```

- 帧 #0 是崩溃点，通常是未符号化的 `.tmp.node` 模块
- 帧 #1~#N 是调用链，从下往上读：**哪个函数 → 调用了什么 → 最终崩溃**
- 帧 #4 `napi_create_object` 表明原生模块在创建 V8 对象
- 帧 #1 `JSObject::AddDataElement` 访问 guard page = 内存布局不匹配

## 模块列表提取（JSON 报告）

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

## 定位源码

### 通过模块名称定位

1. 从堆栈帧 #0 的 `.tmp.node` 文件名无法直接判断来源
2. 在 JSON 模块列表中搜索对应模块的 `debug_name`
3. 对照项目 `package.json` 中的 native addon 依赖

### 通过调用链定位

如果堆栈中有 `napi_*` 或 V8 调用，说明是 Node.js native addon：

| 调用模式 | 可能的库 |
|-----------|---------|
| `napi_create_object` + FFI 库 | koffi, ffi-napi, node-ffi |
| `napi_create_object` + 业务 DLL | 自定义原生模块 |
| `WlanOpenHandle` / `WlanEnumInterfaces` | wlanapi.dll 调用者 |

- **来源**: 项目历史分析经验
- **日期**: 2026-05-07

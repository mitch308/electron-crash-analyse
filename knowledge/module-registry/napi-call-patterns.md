# N-API 调用模式识别

- **实际身份**: 堆栈中 N-API / V8 函数调用模式与可能库的对照表
- **识别方法**: 在崩溃堆栈中查找以下函数组合，推断可能的原生模块来源
- **调用模式对照**:

| 堆栈中的函数组合 | 可能的库/模块 |
|-----------------|-------------|
| `napi_create_object` + FFI 库 + `.tmp.node` | koffi, ffi-napi, node-ffi |
| `napi_create_object` + 业务 DLL | 自定义原生模块 |
| `WlanOpenHandle` / `WlanEnumInterfaces` | wlanapi.dll 调用者（WiFi 扫描） |
| `JSObject::AddDataElement` + guard page | V8 内存布局不匹配（变长结构体越界或 ABI 不兼容） |
| `LoadLibrary` / `dlopen` | DLL 动态加载失败 |

- **来源**: 项目历史分析经验
- **日期**: 2026-05-07

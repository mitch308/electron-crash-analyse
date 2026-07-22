# V8 ABI 不兼容

- **崩溃类型**: EXCEPTION_ACCESS_VIOLATION（V8 内部函数中）
- **关键模块**: 原生 .node 文件, electron.exe (V8 internals)
- **特征**: 崩溃在 napi_create_object 等 N-API 函数内部；调用链进入 V8 内部函数（如 JSObject::AddDataElement、Object::SetProperty）；Electron 升级后新出现
- **根因**: 原生模块不是针对当前 Electron 的 V8 版本编译的，napi_create_object 内部访问错误的内存偏移
- **修复建议**: 用 electron-rebuild 重新编译原生模块：`npx electron-rebuild -v <electron-version> -f`
- **来源**: 项目历史分析经验
- **日期**: 2026-05-07
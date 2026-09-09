# libwifi-ffi.dylib

- **实际身份**: 应用自带的 WiFi 原生 FFI 模块
- **识别依据**: 崩溃线程位于 `libwifi-ffi.dylib + 0x6490`，其上层调用来自应用主模块；本次运行环境为 macOS arm64
- **常见关联**: WiFi 扫描或网络接口枚举；当前报告未提供函数级符号，不能进一步确认具体 API
- **来源**: `reports/9ade91f9-a315-43e7-8d9f-a03507958ee8.txt`
- **日期**: 2026-09-09

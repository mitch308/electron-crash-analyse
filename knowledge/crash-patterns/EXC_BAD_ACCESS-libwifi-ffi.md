# EXC_BAD_ACCESS + libwifi-ffi.dylib

- **崩溃类型**: `EXC_BAD_ACCESS / KERN_INVALID_ADDRESS`
- **关键模块**: 应用主模块、`libwifi-ffi.dylib`
- **特征**: macOS arm64；进程启动约 6 秒；崩溃线程的调用链为应用模块 `+0x3216c` → 应用模块 `+0x801c` → `libwifi-ffi.dylib +0x6490` → `libdispatch`；崩溃地址为 `0x298`
- **初步根因**: 原生 WiFi FFI 路径发生空指针或接近空指针的结构体成员访问。`x0=0` 且故障地址为 `0x298` 支持“基址为空、访问成员偏移 `0x298`”这一判断；由于缺少 `libwifi-ffi.dylib` 符号，尚不能确认具体源码行或 API
- **修复建议**: 为 `libwifi-ffi.dylib` 保留 dSYM 并对 `0x6490` 做符号化；检查 WiFi 接口枚举返回值、对象生命周期和异步 dispatch 回调中的指针有效性；在 FFI 边界校验返回指针/长度后再读取结构体，避免将空结果当作有效接口对象
- **来源**: `reports/9ade91f9-a315-43e7-8d9f-a03507958ee8.txt`
- **日期**: 2026-09-09

# EXCEPTION_ACCESS_VIOLATION + .tmp.node (koffi)

- **崩溃类型**: EXCEPTION_ACCESS_VIOLATION_READ / EXCEPTION_ACCESS_VIOLATION_WRITE
- **关键模块**: .tmp.node, electron.exe (V8 internals)
- **特征**: 崩溃地址落在 guard page；调用链含 koffi.decode() → napi_create_object → JSObject::AddDataElement；uptime 通常 < 10s（初始化阶段）
- **根因**: koffi.decode() 读取变长结构体时按固定大小分配的内存读取，超出实际分配命中 guard page。典型场景：WLAN_INTERFACE_INFO_LIST 定义了固定长度 64 元素数组，实际数据远小于此
- **修复建议**: 用 koffi.view() 读取实际大小的内存 + koffi.decode() 切片解析
- **来源**: 项目历史分析经验；源码参考 C:\workspace\node-wifi\src\windows\wlan-scan.js
- **日期**: 2026-05-07
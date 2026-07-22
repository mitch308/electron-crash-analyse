# Electron 39.4.0 + koffi

- **问题**: koffi.decode() 读取变长结构体（如 WLAN_INTERFACE_INFO_LIST）时越界
- **触发条件**: WiFi 扫描调用 WlanEnumInterfaces
- **修复**: 用 koffi.view() 读取实际大小 + koffi.decode() 切片解析
- **源码参考**: C:\workspace\node-wifi\src\windows\wlan-scan.js
- **来源**: 项目历史分析经验
- **日期**: 2026-05-07
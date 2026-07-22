# .tmp.node

- **实际身份**: koffi/FFI 库的临时解压模块
- **识别方法**: 模块名匹配 `.tmp.node`，通常在 koffi.load() 调用链中出现
- **常见关联**: napi_create_object, JSObject::AddDataElement, koffi.decode()
- **来源**: ANALYSIS-GUIDE.md 已修复案例
- **日期**: 2026-05-07
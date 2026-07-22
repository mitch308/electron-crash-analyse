# Native DLL 加载失败

- **崩溃类型**: 多种（取决于调用方式，可能在 LoadLibrary/dlopen 处崩溃）
- **关键模块**: 目标 DLL（如 xxx.dll）
- **特征**: 崩溃在 koffi.load('xxx.dll') 或类似调用；堆栈中能看到 LoadLibrary 或 dlopen
- **根因**: DLL 不存在、架构不匹配（x64 vs arm64）、或缺少依赖 DLL
- **修复建议**: 用 Dependency Walker 或 Process Monitor 检查 DLL 加载链；确认 DLL 存在且架构匹配；检查依赖 DLL 是否完整
- **来源**: ANALYSIS-GUIDE.md
- **日期**: 2026-05-07
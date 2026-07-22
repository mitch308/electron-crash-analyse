# STATUS_HEAP_CORRUPTION + SogouTSF.ime

- **崩溃类型**: STATUS_HEAP_CORRUPTION
- **关键模块**: SogouTSF.ime, ntdll.dll
- **特征**: 崩溃线程名含 ThreadPoolSingleThreadCOMSTA，uptime 25-38s
- **根因**: 搜狗输入法 TSF 实现触发堆损坏，与 Electron 的 COM 线程池交互时出问题
- **修复建议**: 排查搜狗输入法版本，考虑切换输入法或升级搜狗
- **来源**: 36a2aa34/9910f104/cc37fea4 三份 dump 分析
- **日期**: 2026-07-22
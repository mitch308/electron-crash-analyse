# ntdll.dll + 0xff489

- **函数**: RtlReportFatalHeapCorruption
- **含义**: 堆损坏被检测到后的致命报告入口，触发 STATUS_HEAP_CORRUPTION 异常
- **常见崩溃类型**: STATUS_HEAP_CORRUPTION
- **注意**: 此偏移对应 Windows 10.0.19045 版本的 ntdll.dll，不同系统版本偏移可能不同
- **来源**: 36a2aa34/9910f104/cc37fea4 三份 dump 分析
- **日期**: 2026-07-22
# 崩溃分析知识库索引

读取方式：先读本索引定位相关知识，再按需读取具体文件，避免上下文膨胀。

## crash-patterns/
- [STATUS_HEAP_CORRUPTION + SogouTSF](crash-patterns/STATUS_HEAP_CORRUPTION-SogouTSF.md) — 搜狗输入法触发堆损坏
- [ACCESS_VIOLATION + koffi .tmp.node](crash-patterns/ACCESS_VIOLATION-koffi-tmp-node.md) — koffi FFI 变长结构体越界
- [V8 ABI 不兼容](crash-patterns/V8-ABI-incompatibility.md) — 原生模块与 Electron V8 版本不匹配
- [DLL 加载失败](crash-patterns/DLL-load-failure.md) — Native DLL 不存在或架构不匹配

## module-registry/

（暂无条目）

## offset-database/

（暂无条目）

## version-compatibility/

（暂无条目）
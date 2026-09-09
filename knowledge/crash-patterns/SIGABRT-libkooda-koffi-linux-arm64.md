# SIGABRT + libkooda.so + koffi.node（Linux arm64）

- **崩溃类型**: SIGABRT / SI_TKILL
- **关键模块**: libkooda.so, koffi.node, libstdc++.so.6
- **特征**: Linux arm64，进程启动后约 2～3 秒崩溃；崩溃线程首先位于 libc，随后重复出现 libstdc++ 异常处理帧，调用链进入 libkooda.so，再经动态加载器和 koffi.node 返回应用代码
- **高可信判断**: 不是 libc 自身空指针访问，而是 libkooda.so 初始化或加载阶段触发了未处理的 C++ 异常、显式 abort，或依赖加载失败后的终止路径；当前堆栈不足以区分这三种具体情况
- **排查重点**: 在同一 arm64 环境检查 libkooda.so 及其依赖的架构、动态依赖和运行时版本；记录 koffi.load() 的目标库及 dlerror；在 libkooda.so 初始化入口增加日志，并使用 `LD_DEBUG=libs` 或 `strace -f -e trace=openat,access,stat,execve` 检查依赖加载
- **修复方向**: 确保 libkooda.so、liblibpass.so 及全部依赖均为 arm64 且 ABI/运行时匹配；不要在 native 初始化异常时直接 terminate，改为向 JS 层返回可诊断错误；若 native addon 是按其他 Electron 版本构建，执行 `npx electron-rebuild -v 33.3.0 -f`
- **来源**: `reports/0a200485-f7ee-4eaf-9897-138f21cfbbcd.txt`, `reports/0ab2d4be-6d4f-46f2-82c5-152aa33c4275.txt`, `reports/0aa35633-6607-43c3-bbdb-9bdbe2f4518e.txt`
- **日期**: 2026-09-09

Type: research
Status: resolved

---

## Question

Qt 6 Quick (QML) + C++ 应用的**跨平台打包与分发策略**怎么定 —— 目标是 Linux/Windows/macOS 都能跑, 不能只锁死 `.deb`(而且不用 DTK)。

- 应用是纯 Qt Quick + C++(无 DTK), 统一 CMake; 分平台定打包:
  - Linux(deepin/UOS 首版): `.deb`(desktop 文件 + 图标)。
  - Windows: 安装器(windeployqt + NSIS 或 Qt Installer Framework)。
  - macOS: `.dmg` / `.app`(macdeployqt; 公证视发布需要)。
- 首版落地: 至少 Linux 可装; Windows/macOS 给出可沿用路径即可, 不必本机实测(当前机是 Linux/AMD)。
- 旧结论注意: 方向改前针对「Qt6 Widgets + DTK6」的 `.deb` 研究 `docs/resources/05-deb-packaging.md` **已不适配**(它有 DTK 依赖), 仅作 Linux 打包的参考, 不再按其久远实现。

## Answer

**结论(read：完整策略见 `docs/resources/05-cross-platform-packaging.md`，本机环境只读查证见该文档 §6)。**

- **组织**：单一跨平台 CMake target，用 `qt_add_qml_module` 管理 QML(资源内建 + qmldir/qmltypes + imports 解析)，不做按平台分裂构建；`engine.loadModule(uri, name)`(Qt 6.5+)避免安装后相对路径失效。
- **Linux(首版必达)**: desktop 文件 `Icon=omp-config`(只写 basename) + hicolor 图标 + `Categories=Qt;Utility;`(无 DTK，不加 `X-Deepin-*`)。**首版最简用 CPack(`cpack -G DEB` + `CPACK_DEBIAN_PACKAGE_SHLIBDEPS=ON`)**, 不锁死 debhelper；debhelper 骨架(§2.4)作为需要精细控制时的备选。
- **Windows**：`windeployqt --release --qmldir <qml> omp-config.exe` 收集 Qt DLL + QML 运行时 → NSIS/QIF 或在 CMake 里 `cpack -G NSIS`。依赖清单见 §3.2(Core/Gui/Widgets/Quick/Qml/QuickControls2/Network 等)。
- **macOS**：`macdeployqt omp-config.app` 打自包含 `.app` → `hdiutil` 出 `.dmg`；签名/公证首版跳过(在发布说明注明)。
- **本机环境**：qt6-declarative-dev 6.8.0、debhelper 13.24.2、cmake 3.31.4、dpkg-dev 均就绪；windeployqt/macdeployqt 非 Linux 主机无(预期)。
- 旧 `docs/resources/05-deb-packaging.md`(Qt6 Widgets + DTK6)**已不适配**，仅作 Linux 打包参考，不代表新结论。
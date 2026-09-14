# Qt6 Quick(QML) + C++ 跨平台打包与分发策略

> 研究对象：纯 Qt Quick(QML) + C++ 后端、**无 DTK**、统一 CMake 的桌面应用 `omp-config`。
> 目标平台：Linux(deepin/UOS 首版) / Windows / macOS。
> 依据：官方 Qt 6 部署流程(windeployqt / macdeployqt / qt_add_qml_module)+ 本机 dpkg 实测(见 §5)。
> 说明：本仓库旧文档 `docs/resources/05-deb-packaging.md` 是针对「Qt6 Widgets + DTK6」的 `.deb` 研究，含 DTK 依赖，**仅作 Linux 打包参考，不代表本应用结论**。方向已改为纯 Qt Quick + 无 DTK，本文件为新的唯一权威结论。

---

## 0. 结论速览

| 事项 | 结论 |
|------|------|
| 组织方式 | **单一跨平台 CMake target**，用 `qt_add_qml_module` 管理 QML(资源内建 + qmltypes/qmldir + imports 解析)，不做按平台分裂的构建 |
| Linux(首版必达) | `.deb`：`install()` 装可执行 + desktop + hicolor 图标；**首版最简用 CPack(`cpack -G DEB`)**，不锁死 debhelper；需要精细依赖/架构时再上 debhelper |
| Windows | `windeployqt` 收集 Qt DLL + QML 运行时 → NSIS / Qt Installer Framework(或 CPack 出 NSIS)出安装器 |
| macOS | `macdeployqt` 打成自包含 `.app` → `hdiutil` 出 `.dmg`；签名/公证首版可跳过(注明) |
| 本机打包环境 | ✅ 就绪(qt6-declarative-dev 6.8.0、debhelper 13.24.2、cmake 3.31.4、dpkg-dev)——本会话只读/查，不实际构建 |

---

## 1. 跨平台 CMake 组织(共识)

### 1.1 基本思想：一个 target，平台各自出安装器

不要为每平台写三份构建逻辑。核心是一个 `qt_add_executable` 目标，其中：

- **QML 资源经 `qt_add_qml_module` 内建编译**，而不是散落 `.qrc` 手工 `add_executable(... .qrc)`。
- 平台差异只在「**发布/打包**」阶段体现：Linux 出 deb，Windows 出安装器，macOS 出 `.app/.dmg`。

### 1.2 `qt_add_qml_module` 要点(QML 的"标准路径")

官方推荐结构(来自 Qt 6 的 qml module 约定)：

```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Widgets Network QuickControls2)

qt_add_executable(omp-config
    main.cpp
)
qt_add_qml_module(omp-config
    URI ompplugin/ompconfig          # 模块 URI，决定 import 名
    VERSION 1.0
    QML_FILES
        main.qml
        MainWindow.qml
        ...
    RESOURCES
        resources/                   # 图片、字体等非 QML 资源,内建进二进制
    OUTPUT_DIRECTORY
        qml
)
```

- **qmlmodules / qytypes(类型声明)**：`qt_add_qml_module` 会自动为 C++ 侧注册的类型生成 QML 模块元数据(`qmldir` + 类型声明)，补足 `QML_IMPORTS` 不再需要手写 `qmldir`。
- **imports 路径解析**：模块的 `URI` + 资源统一内建(resource prefix)，运行时 `import` 按 Qt 标准资源路径解析，**无需在代码里 tail `addImportPath`**。
- **资源 `.qrc`**：首选 `RESOURCES` 参数，文件进入内嵌资源；若真用 `.qrc` 文件也可(`qt_add_resources`)，但 `RESOURCES` 更贴近 QML 模块。

### 1.3 `main.cpp` 要点(QML 能发现模块)

```cpp
#include <QGuiApplication>   // 纯 QML 用 QGuiApplication; 若混用 Widgets(如 QuickWidgets 宿主)用 QApplication
#include <QQmlApplicationEngine>

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);   // 工程含 Widgets 依赖时用 QApplication
    QQmlApplicationEngine engine;
    engine.loadFromModule("omp.ompconfig", "Main"); // 6.5+ 推荐; 与 qt_add_qml_module 的 URI 一致
    return app.exec();
}
```

- `engine.loadFromModule(uri, name)`(Qt 6.5+)读取内建 QML 模块，不再依赖外部 `main.qml` 文件路径，避免相对路径在安装后失效的坑。

### 1.4 清晰依赖清单(本应用建议)

| 模块 | 用途 | 命令 |
|------|------|------|
| `Qt6::Core` | 基础 | `find_package(Qt6 COMPONENTS Core)` |
| `Qt6::Gui` | 绘制/事件(QML 必需) | `Qt6 COMPONENTS Gui` |
| `Qt6::Widgets` | 含 C++ Widgets 宿主或系统集成(如托盘 ADT 场景) | `Qt6 COMPONENTS Widgets` |
| `Qt6::Quick` / `Qt6::QuickWidgets` | QML 渲染核心(QML UI 用 Quick; 嵌 Widgets 用 QuickWidgets) | `qt_add_qml_module` 已隐含 |
| `Qt6::Network` | 若后端走网络(HTTP) | `Qt6 COMPONENTS Network` |

> 参考：本机 CMake 配置 `/usr/lib/x86_64-linux-gnu/cmake/Qt6*` 齐全(见 §5)，`find_package`/`qt_add_qml_module` 均可用。

---

## 2. Linux：`.deb`

### 2.1 共识要点

- **desktop 文件**：`.desktop` 中标 `Icon=omp-config`(**只写 basename，不带路径与扩展名**)；`Categories=Qt;Utility;`。
- **图标**：装到 hicolor 主题 `/usr/share/icons/hicolor/{size}/apps/`，desktop 的 `Icon` 与图标 basename 对应。
- **deb 依赖**：运行时 Qt 库由包管理器解析；本应用纯 Qt(无 DTK)，`Depends` 可交给 dpkg-shlibdeps 自动推导。

### 2.2 desktop 文件模板

```ini
[Desktop Entry]
Type=Application
Name=OMP Config
Name[zh_CN]=OMP 配置
GenericName=OMP Configuration
Comment=omp (Oh My Pi) 配置工具
Categories=Qt;Utility;
Exec=/usr/bin/omp-config
Icon=omp-config
Terminal=false
StartupNotify=true
```

> 注意：本应用**不用** `X-Deepin-Vendor=deepin`/`X-Deepin-AppID`(那是 DTK/Deepin 桌面生态深度集成场景用的；本应用是通用 Qt 应用，用标准 `Categories` 即可，`Categories=Qt;Utility;` 已经让 deepin 桌面识别)。

### 2.3 首版最简 = CPack 出 DEB(不锁死 debhelper)

**最可维护、首版就够**路径：CPack `DEB` 生成器，无需手写 `debian/` 全套骨架。

CMakeLists.txt 尾部追加：

```cmake
include(CPack)
set(CPACK_PACKAGE_NAME        omp-config)
set(CPACK_PACKAGE_VENDOR      "ut000427")
set(CPACK_PACKAGE_VERSION     ${PROJECT_VERSION})
set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")   # 按目标架构
set(CPACK_PACKAGING_INSTALL_PREFIX "/usr")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "omp (Oh My Pi) configuration GUI")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)            # 自动收集基于 Qt 的运行时依赖
```

构建出包命令：

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
cmake --install build --prefix build/staging
( cd build && cpack -G DEB )
```

`CPACK_DEBIAN_PACKAGE_SHLIBDEPS=ON` 会用 `dpkg-shlibdeps` 依据程序链接到的库自动生成 `Depends`，纯 Qt 运行时依赖(如 `qt6-qmltooling`、`qt6-qml` 的 QML 库)会一并收集。

### 2.4 需要更精细控制时的 debhelper 骨架(备选)

本机已装 `debhelper 13.24.2`、`dpkg-dev 1.22.6deepin10`(§5)，可走标准 Debian 流程；但**首版没必要一开始就锁 debhelper**，CPack 足够。若后续需要(多架构、多包拆分、lintian 合规)再切：

```
debian/
├── control        # Depends: ${shlibs:Depends}, ${misc:Depends}
├── rules          # dh $@
├── changelog
└── compat         # 13
```

`debian/control` 骨架：

```control
Source: omp-config
Section: utils
Priority: optional
Maintainer: ut000427 <ut000427@uos>
Build-Depends:
 cmake,
 debhelper-compat (= 13),
 qt6-base-dev,
 qt6-declarative-dev,
 pkg-config,
 dpkg-dev,

Package: omp-config
Architecture: any
Depends:
 ${shlibs:Depends},
 ${misc:Depends},
Description: omp (Oh My Pi) configuration GUI
 ```

`debian/rules`：

```make
#!/usr/bin/make -f
%:
	dh $@
```

依赖由 `dh_shlibdeps` 自动推导，纯 Qt6 无需手写运行库。

---

## 3. Windows

### 3.1 流程

1. 构建 Release 产物。
2. **`windeployqt`** 把可执行文件需要的 Qt DLL、QML/plugin 运行时拷进输出目录(把 `.qrc` 内嵌资源无关紧要，关键是 QML 模块的 `.dll`/qml 目录)。

```bat
cd build
windeployqt.exe --release --qmldir ../qml --no-translations omp-config.exe
```

3. 将 `windeployqt` 输出的整个目录(可执行 + DLL + qml 子目录 + 资源)打进安装器：
   - **CPack 最简单**：`cmake --build . --config Release && cpack -G NSIS`(或 `-G "ZIP" 先给免安装压缩包)。
   - 或 **Qt Installer Framework(QIF)**：做个性化/在线安装、多语言向导时用。

### 3.2 依赖清单(windeployqt 会自动收集，这里列出应出现的运行库)

| 类别 | 实际拷贝依据 |
|------|------|
| Qt 核心 | `Qt6Core.dll Qt6Gui.dll Qt6Widgets.dll Qtz.dll`(按链接模块) |
| Qt Quick/QML | `Qt6Qml.dll`、`Qt6Quick.dll`、`Qt6QuickControls2.dll`、`Qt6QtQml*`、`Qt6Network.dll`(若用) |
| 平台插件 | `platforms/qwindows.dll` |
| QML 内置模块 | `qml/QtQuick/`、`qml/QtQml/`、`qml/QtQml/...`(windeployqt 自动导出导入模块) |
| 额外 | `Concrt`/`msvcp` 视编译运行时(MSVC 时 multiarch)；用 `/opt` 交叉或多工具链注意 |

`--qmldir` 指向 QML 源目录帮助 windeployqt 额外打包自定义模块；若 QML 已用 `qt_add_qml_module` 内嵌，`--qmldir` 可指向构建输出的 qml 目录。

---

## 4. macOS

### 4.1 流程

1. 构建 `.app`：CMake 里 `macOS` 下 `install()`，可执行放在 `omp-config.app/Contents/MacOS/`。
2. **`macdeployqt`** 将 Qt 框架与插件打进 `.app`(自包含)：
   ```bash
   macdeployqt omp-config.app -verbose=2
   ```
   (若用 `qt_add_qml_module` 内嵌 QML，`macdeployqt` 默认已知 QML 模块，无需额外参数；必要时 `-qmldir=...`。)

3. 制作 `.dmg`：
   ```bash
   hdiutil create -volname "omp-config" -srcfolder omp-config.app -ov -format UDZO omp-config.dmg
   ```

### 4.2 签名 / 公证(首版可跳过，但要注明)

- **开发阶段/内部分发**：可跳过签名，直接 `.dmg`(Gatekeeper 首次运行会提示「无法验证开发者」)。
- **公开发布(非 Mac App Store)**：需要 Apple Developer ID 签名 `codesign` + `--options runtime`，并用 `notarytool submit` 公证。
- **首版建议**：跳过签名/公证，在 `README`/发布说明中注明「需在系统设置→隐私与安全中允许打开」。

---

## 5. 集成建议：CMake + QML 模块化(参照本机 Qt 技能)

- 本机 `qt-cmake-project` 技能**不存在**(`ls /home/ut000427@uos/.agents/skills/ | grep qt` 只有单元测试/兼容/翻译技能，见 §6 依据)。工程项目惯例直接遵循官方 Qt 6 的 `qt_add_qml_module` 组织(§1.2)，不再引入额外封装。
- 参考本机实际可用技能：`qt-unittest-build`(autotests 骨架)、`qt-compatibility-build`(Qt5/Qt6 双依赖若需兼)、`qt-translation-assistant`(TS 翻译)均可叠加到本应用，不影响打包流程。

模块化约定：

```
omp-config/
├─ CMakeLists.txt          # 单一 target + CPack 段
├─ src/
│   ├─ main.cpp            # QApplication + engine.loadModule
│   └─ (C++ 后端类, 注册进 QML / QML_NAMED_ELEMENT)
├─ qml/                    # qt_add_qml_module 引入的文件
│   └─ main.qml, MainWindow.qml, ...
├─ resources/              # 图标/字体, 走 RESOURCES
└─ packaging/
    ├─ omp-config.desktop
    └─ icons/hicolor/.../omp-config.svg
```

C++ 类型注册需要 QML 可见，在 `qt_add_qml_module` 下一同声明(例如 `QML_NAMED_ELEMENT`)+ 链接 `Qt6::Quick` 模块即可被 QML 解析。

---

## 6. 本机环境证据(只读查证)

| 检查项 | 本机状态(证据) |
|--------|------|
| CMake | `cmake 3.31.4-2deepin1`(`dpkg -s cmake`) |
| Qt6 QML 开发 | `qt6-declarative-dev 6.8.0`、`qml6-module-qtquick 6.8.0`(`dpkg -s`) |
| Qt6 Quick CMake | `/usr/lib/x86_64-linux-gnu/cmake/Qt6Quick|Qt6QuickControls2` 存在 |
| Qt6 Quick import | `/usr/lib/x86_64-linux-gnu/cmake/Qt6/QtInitProject.cmake` 含 `qt_add_qml_module` |
| deb 工具 | `debhelper 13.24.2`、`dpkg-dev 1.22.6deepin10` |
| windeployqt/macdeployqt | 本机 Linux/AMD **无**(预期：仅 win/mac 主机有) |
| 参考资料 | 官方 `qt_add_qml_module` / `windeployqt` / `macdeployqt`，均可用 (见 §1/§3/§4) |

---

## 7. 【首版最少迭代】可选验收清单

- [ ] Linux 本地 Run：`cmake --build build && ./build/omp-config` 可跑(依赖本地 Qt runtime)。
- [ ] Linux 可装：首版用 `cpack -G DEB` 产出 `.deb`，在 deepin/UOS `apt install`(或 `dpkg -i`)装上；desktop 文件、图标正确，启动器可见 `OMP Config`。
- [ ] CMake 单一 target + `qt_add_qml_module` 就绪，QML 全内嵌。
- [ ] Windows / macOS 给出可沿路径(§3/§4)即可，本机(Linux/AMD)不必实测。

> 超出首版(后续)再考虑：多平台 CI(如 GitHub Actions 矩阵 `os: [ubuntu-latest, windows-latest, macos-latest]`)、签名公证、Windows QIF 自定义向导。
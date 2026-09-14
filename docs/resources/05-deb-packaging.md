# Qt6 Widgets + DTK6 桌面应用 .deb 打包路径

> 研究对象：普通 Qt Widgets C++ 桌面程序（非 DDE 控制中心插件），依赖 `libdtk6widget` 等 DTK6 运行时，交付 `.deb`。
> 依据：`dtk-development` 技能（`references/app-dev-with-dtk.md`）+ 本机 `dpkg -l` / `/usr/lib/x86_64-linux-gnu/cmake` / desktop 样例实测。
> 本机环境已探明，无需额外安装开发包。

---

## 1. 结论速览

| 事项 | 结论 |
|------|------|
| CMake `find_package` 写法 | `find_package(Dtk6Widget REQUIRED)`（模块级）或 `find_package(Dtk6 REQUIRED COMPONENTS Core Gui Widget)`（元包简写） |
| 链接 target 名 | `Dtk6::Core` `Dtk6::Gui` `Dtk6::Widget`（注意：文件名 `Dtk6Widget`，target 名 `Dtk6::Widget`，命名不对称是 DTK 常态） |
| 依赖包（编译期 `Build-Depends`） | `libdtk6core-dev libdtk6gui-dev libdtk6widget-dev`, `qt6-base-dev`, `qt6-tools-dev`, `cmake`, `debhelper-compat(=13)`, `pkg-config`, `dpkg-dev` |
| 依赖包（运行期 `Depends`） | 由 `${shlibs:Depends}` 自动推导；仅 QML 模块需手动列出。本应用为纯 Widgets，无需手写运行时库 |
| 本机开发环境 | ✅ 全部就绪（见 §5） |
| desktop 文件 | `[Desktop Entry] Type=Application` + `Categories=Qt;Utility;System;` + `X-Deepin-Vendor=deepin` + `X-Deepin-AppID` |
| 图标路径 | `/usr/share/icons/hicolor/{size}/apps/<app>.svg/.png`，desktop 的 `Icon=` 只写 basename |

---

## 2. CMake 骨架（`CMakeLists.txt`）

权威模板来自技能 `dtk-development/references/app-dev-with-dtk.md` §1.1/§1.3，已与本机安装的 CMake config 文件核对一致。

```cmake
cmake_minimum_required(VERSION 3.13)
project(omp-config-gui VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Qt6
find_package(Qt6 REQUIRED COMPONENTS Core Widgets)

# DTK6 —— 两种等价写法：
# 方案 A（模块级，推荐，与 target 一一对应）
find_package(Dtk6Core   REQUIRED)
find_package(Dtk6Gui    REQUIRED)
find_package(Dtk6Widget REQUIRED)
# 方案 B（元包简写，需 dtkcommon 提供 Dtk6Config.cmake）
# find_package(Dtk6 REQUIRED COMPONENTS Core Gui Widget)

add_executable(omp-config-gui
    main.cpp
    mainwindow.cpp
)

target_link_libraries(omp-config-gui PRIVATE
    Qt6::Core
    Qt6::Widgets
    Dtk6::Core
    Dtk6::Gui
    Dtk6::Widget
)

# 安装产物：可执行文件 + desktop + 图标
install(TARGETS omp-config-gui
        RUNTIME DESTINATION bin)
install(FILES packaging/omp-config-gui.desktop
        DESTINATION share/applications)
install(FILES packaging/icons/omp-config-gui.svg
        DESTINATION share/icons/hicolor/scalable/apps)
```

**证据**：
- `/usr/lib/x86_64-linux-gnu/cmake/Dtk6Widget/Dtk6WidgetConfig.cmake`、`Dtk6Gui/Dtk6GuiConfig.cmake`、`Dtk6Core/Dtk6CoreConfig.cmake` 均存在 → 模块级 `find_package` 可用。
- `/usr/lib/x86_64-linux-gnu/cmake/Dtk6/Dtk6Config.cmake` 存在 → 元包 `find_package(Dtk6 COMPONENTS …)` 写法可用。
- `/usr/lib/x86_64-linux-gnu/pkgconfig/dtk6widget.pc`、`dtk6gui.pc`、`dtk6core.pc` 存在，提供 pkg-config 备选路径。

---

## 3. 本机开发环境状态（已 dpkg 实测，全就绪）

取自 `dpkg -l`，所有包已安装（`ii`）：

| 用途 | 包 | 版本 |
|------|----|------|
| DTK6 编译依赖 | `libdtk6core-dev` | 6.7.47.1 |
| DTK6 编译依赖 | `libdtk6gui-dev` | 6.7.47 |
| DTK6 编译依赖 | `libdtk6widget-dev` | 6.7.47.1 |
| DTK6 附加 | `libdtk6log-dev` | 6.7.47 |
| Qt6 编译依赖 | `qt6-base-dev` / `qt6-base-dev-tools` | 6.8.0+dfsg |
| Qt6 编译依赖 | `qt6-tools-dev` / `qt6-tools-dev-tools` | 6.8.0 |
| Qt6 运行时 | `libqt6widgets6` | 6.8.0 |
| 构建工具 | `cmake` | 3.31.4 |
| 构建工具 | `debhelper` / `debhelper-compat` | 13.24.2 |
| 构建工具 | `pkg-config` | 2.5.1 |
| 打包 | `dpkg-dev` | 1.22.6 |

**结论：本机缺无任何 DTK6 dev 包；无需额外安装即可构建 + 打包。**

---

## 4. debian 目录骨架

### 4.1 `debian/control`

写作要点（依据技能 §4）：
- **编译期 `-dev` 包放 `Build-Depends`**，仅编译需要。
- **运行时共享库（`libdtk6widget`、`libdtk6core`、`libdtk6gui` 等）由 `Depends: ${shlibs:Depends}` 自动推导**，不手动写。
- **仅 QML 模块**（如 `qml6-module-qtquick-*`）需手动列 `Depends`，因为 shlibs 不会自动推导 QML 模块；本应用为纯 Widgets，不涉及。

```control
Source: omp-config
Section: utils
Priority: optional
Maintainer: ut000427 <ut000427@uos>
Build-Depends:
 cmake,
 debhelper-compat (= 13),
 pkg-config,
 dpkg-dev,
 qt6-base-dev,
 qt6-tools-dev,
 libdtk6core-dev,
 libdtk6gui-dev,
 libdtk6widget-dev,

Package: omp-config
Architecture: any
Depends:
 ${misc:Depends},
 ${shlibs:Depends},
Description: omp 配置 GUI 工具
 基于 Qt6 + DTK6 的 omp（Oh My Pi）配置图形化工具。
```

### 4.2 `debian/rules`

```make
#!/usr/bin/make -f
%:
	dh $@
```

运行时依赖会由 `dh_shlibdeps` 根据链接到的库自动求最小版本。

### 4.3 `debian/changelog`

```text
omp-config-gui (0.1.0-1) unstable; urgency=medium

  * 初始打包：Qt6 Widgets + DTK6 桌面应用。

 -- ut000427 <ut000427@uos>  Mon, 14 Sep 2026 00:00:00 +0800
```

### 4.4 `debian/compat`

`debhelper` 13 已经默认 compat 13（本机 `debhelper 13.24.2`），可用 `debhelper-compat (= 13)` 在 `Build-Depends` 中声明，无需 `debian/compat` 文件。

### 4.5 `debian/source/format`
```
3.0 (quilt)
```

---

## 5. desktop 文件模板

依据系统已装 deepin 应用样例（如 `/usr/share/applications/deepin-app-store.desktop`、`deepin-boot-maker.desktop`）规范：

```ini
[Desktop Entry]
Type=Application
Name=OMP Config
Name[zh_CN]=OMP 配置
GenericName=OMP Configuration
Comment=omp (Oh My Pi) 配置工具
Categories=Qt;Utility;System;
Exec=/usr/bin/omp-config-gui
Icon=omp-config-gui
Terminal=false
StartupNotify=true
X-Deepin-Vendor=deepin
X-Deepin-AppID=omp-config-gui
```

字段要点（对照系统样例）：
- `Categories`：桌面应用样例用 `Qt;System;` / `Qt;Utility;`，配置工具建议 `Qt;Utility;System;`。
- `Exec`：写二进制 basename（`/usr/bin/<app>`），不带 `/home/...` 路径。
- `Name[zh_CN]`：中文界面的本地化名，放同一文件 `Name[zh_CN]=...`，或放到独立翻译文件由 gettext 处理。
- `X-Deepin-Vendor=deepin` 与 `X-Deepin-AppID`：deepin 桌面样例标准字段，用于启动器识别与应用 ID。

---

## 6. 图标路径约定

按 hicolor 主题标准（本机 `/usr/share/icons/hicolor/` 含 `16x16…1024x1024` 与 `scalable` 子目录，均含 `apps/`）：

```
/usr/share/icons/hicolor/scalable/apps/omp-config-gui.svg   # 矢量，推荐
/usr/share/icons/hicolor/256x256/apps/omp-config-gui.png    # 位图备选
```

- 「desktop 的 `Icon=omp-config-gui` 只写 basename，不带路径与扩展名。」
- 「CMake `install()` 中把图标装到 `share/icons/hicolor/scalable/apps/`。」
- 若使用 DTK DCI 图标体系，可放 `/usr/share/icons/deepin/apps/`。本机未装 `deepin` 独立图标主题（`ls /usr/share/icons/deepin` 为空），通用应用图标统一走 hicolor 更稳妥。

---

## 7. 打包命令（供后续实施，本次不执行）

```bash
# 构建完整 .deb（需要 debhelper / dpkg-buildpackage）
dpkg-buildpackage -b -us -uc
# 或 cmake 产物的 dh 流程
debuild -us -uc
```

---

## 8. 待办/风险

| 事项 | 说明 |
|------|------|
| 可执行文件命名 | `Exec=` 与 `applicationName`（`DApplication`）建议保持一致，便于单实例/翻译加载 |
| 运行时库版本 | `${shlibs:Depends}` 会自动最小化版本；本机 DTK6 为 6.7.47、Qt6 为 6.8.0 |
| 纯 Widgets → 无需 QML 运行时包 | 若要依赖 `dtkdeclarative`，才需在 `Depends` 手动加 `libdtk6declarative` 与 `qml-module-…chameleon` 等 |
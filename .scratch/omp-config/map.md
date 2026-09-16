# omp-config · wayfinder 地图

> 本地 markdown tracker。票券: `.scratch/omp-config/issues/NN-<slug>.md`(打开时不分列,按 Type/Status 查询)。

## Destination

可运行的 **Qt 6 Quick (QML)** 跨平台桌面应用「omp 配置工具」: 管理 `~/.omp/agent/models.yml` 的 provider/model 两级 CRUD 与 modelRoles 角色绑定, 编辑 `~/.omp/agent/config.yml` 的主题/显示常用设置, 保存前自动备份 + 写入校验。面向 Linux(deepin/UOS, 首版验证)/ Windows / macOS。

## Notes

- 技术栈: C++/Qt 6 **Quick (QML 界面 + C++ 后端)**, 不依赖 DTK; CMake。跨平台: Linux(deepin/UOS 首版)/ Windows / macOS。中文界面。
- 配置事实(已探明, 勿重查):
  - 模型/provider → `~/.omp/agent/models.yml`(唯一权威源, 用户可编辑)。
  - 常用设置 → `~/.omp/agent/config.yml`(`/settings` 唯一落盘, Argument utf8 YAML)。
  - `models.db` 只是在线 discovery 的运行时缓存(`model_cache` 表), 非配置源, **绝不写它**。
  - 变更后重启 omp 生效。
  - schema 参考: `node_modules/@oh-my-pi/pi-coding-agent/src/config/{settings-schema.ts, settings.ts, models-config.ts, models-config-schema-bundle.ts, model-registry.ts}`; 路径 `pi-utils/src/dirs.ts`。
- 多 profile(`--profile`) 不做, 默认单 profile。
- UI 事实(已探明, 勿重查; 本机 deepin 深色主题, Qt Quick Controls 解析到 `org.deepin.dtk` 样式):
  - 该样式的 `SpinBox` 键不进去: `editable: true` 时 contentItem(`text: control.displayText`)被外部回写 `value` 触发 binding loop;`editable: false` 时 contentItem 为 readOnly TextInput。数字栏一律用 `TextField + IntValidator`。
  - 控件默认取系统主题调色板, 而卡片底是硬编码浅色(`#fafbfb`): 深色主题下 `TextField`/`ComboBox`/`SpinBox` 白字白底不可见(`Switch`/`CheckBox` 不受影响)。浅色底上的输入控件必须显式给浅色 `palette`——模型卡里 4 个输入控件(id ComboBox、name TextField、两个 token 栏)已用根属性 `cardInputBase`/`cardInputText` 统一覆写;ComboBox 的弹窗另见下一条。
  - 该样式的 ComboBox **弹窗面板**是 `FloatingPanel`(`D.InWindowBlur` 毛玻璃), 本机 blur 不生效 → 面板近乎全透明, 背后文字透上来;其自带 delegate(MenuItem)配色又取 DTK 主题色, 与硬编码浅色卡片各走一套(深色主题下会出现看不见的组合)。(早期曾把"下拉只显示一项"记成 delegateModel 的问题——真因是下一条的 `textAt` 一次性求值。)
  - 结论: 全项目 ComboBox 统一走 `AppComboBox`(`src/qml/Main.qml` 内联组件)——自绘不透明浅色面板 + 自绘行(弹窗高度 = 条数 × 行高), **不用 delegateModel**。鼠标点选发自定义 `itemChosen(index)`, 键盘 Up/Down/Enter 仍由 ComboBox 自身处理(Enter 发 `activated`)。
  - 弹窗行的文本**不能用 `textAt(index)` 直接写在 delegate 里**: 它是方法调用、没有依赖跟踪, 而第一个 delegate 常在 model 就绪前就建好 → 求值成空串后再不更新(所有下拉"首项空白"的真因)。现用 `AppComboBox.rowTexts`(随 count/model 变化的绑定数组)喂 ListView, 行文本取 `modelData`。
  - 可编辑 ComboBox 要显式 `currentIndex: -1`: 否则 model 变化时它会按当前项重置 `editText`, 把回填的绑定值冲掉(角色绑定行就踩过);model 会重建的行, 还得整行重建让新行在自己的 `Component.onCompleted` 里回填(同模型卡 `applyModelId` 的做法)。
  - 角色绑定的候选项 = 全部 provider 的全部模型, 取值 `provider/modelId`(与 `modelRoles` 一致);`rebuildRoleOptions()` 在启动与每次 provider 保存后重建。角色**名单**仍是硬编码 9 个(smol/plan/task/slow/default/vision/commit/tiny/advisor), 配置里多出的角色(如 `designer`)**在 UI 里改不到** —— 待办。
  - 该样式的可编辑 ComboBox **手输文本无效**: 它的 contentItem 是 `RowLayout`(内含 TextField), 而 `QQuickComboBoxPrivate::contentItemChange` 只认 `QQuickTextInput*` → `editText`/`accepted` 都不通, 键进去的文字只停在样式内部那个 TextField 里。id 栏因此只能从弹窗候选里选。
  - `activated(index)` 的参数名会遮蔽 delegate 的 `index` —— 回写模型必须用卡片自己的 `modelCard.index`, 否则会写到第 N 个卡片或越界 TypeError。
  - 设置页(config.yml)的写入是「字段级改写」: 路径不存在的键**不会新增**(`updateSettingPaths` 里 "路径不存在,不写"), 所以 config.yml 不存在时点保存只会提示"无变化"。
- 交付: 跨平台可安装包 —— Linux `.deb`(deepin/UOS, 首版)先行; Windows/macOS 的分发由票券 05 定夺。

## Decisions so far

<!-- 索引: 每 closed 票券一行: 名称(答案要点) + 链接 -->

- [模型配置契约 `models.yml`](.scratch/omp-config/issues/01-model-contract.md) — 精确可写 schema 契约已定:provider 13 字段(baseUrl/api/auth/apiKey/models[])、model 19 字段(id/name/reasoning/input/contextWindow/maxTokens…)、校验集 12 条、YAML 序列化要点(2 空格、裸布尔/数字、引号策略、键序、原子写)。含后端 C++ 数据模型建议。详情: `docs/research/01-model-contract.md`。
- [外观配置契约 `config.yml`](.scratch/omp-config/issues/02-appearance-contract.md) — 主题/显示可暴露字段与枚举已定:theme 运行时枚举(~100 内置主题名)、statusLine(preset/separator/24 段)、display 布尔开关、symbolPreset=unicode|nerd|ascii、defaultThinkingLevel=minimal..max|auto 等;GUI 外观页推荐暴露 22 项。详情: `docs/resources/02-appearance-contract.md`。
- [跨平台打包策略](.scratch/omp-config/issues/05-deb-packaging.md) — 单一跨平台 CMake target + `qt_add_qml_module`;Linux 首版 CPack 出 `.deb`(desktop `Icon=` 只写 basename),Win `windeployqt`+NSIS,macOS `macdeployqt`→`.dmg`(公证跳过)。不再用 DTK 专属 deb 方案。详情: `docs/resources/05-cross-platform-packaging.md`。

## Not yet specified

- 主窗口导航形态(左侧栏 vs 顶层 tab)——由票券「UI 信息架构」厘清。
- 判断 provider 差异化(可 discovery 的 ollama/litellm 等)是否需要 UI——可能出例外, 待前端契约决定。
- apiKey 录入/落盘方式(明文写 models.yml vs 提示不入库)——后续安全决策。
- i18n: 暂定仅中文, 不做多语言。

## Out of scope

- `models.db` 直接读写(那是发现缓存)——本工具菜单由票券 01 流程约定。
- 配置文件 `.db` 与 runtime 会话管理——本地图 ends 于「可写配置」。
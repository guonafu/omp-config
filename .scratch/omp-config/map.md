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
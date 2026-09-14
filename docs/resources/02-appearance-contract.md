# 02 · config.yml 外观字段契约(Appearance Contract)

> 来源:只读源码 `node_modules/@oh-my-pi/pi-coding-agent/src/config/settings-schema.ts`(单一同源 schema,字段枚举与默认值以下均为照抄)、`settings.ts`(读写/持久化入口)。
> 本文档供 omp 配置 GUI(Qt6 + DTK6)外观页构建下拉框/开关使用。行号均指向上述 schema 文件。

## 0. 读取与写入要点

- **单一事实源**:所有设置键、类型、枚举、默认值均由 `SETTINGS_SCHEMA`(settings-schema.ts)声明;`settings.ts` 通过 `getByPath`/`setByPath` 读写 config.yml 里的嵌套键。
- **落盘**:config.yml 顶层键即 schema 路径(见 `getDefault`/`SETTING_PATH_SEGMENTS`),`setByPath` 按 `.` 分段生成嵌套对象。写 `"statusLine.preset"` → YAML `statusLine:\n  preset: ...`。
- 以下每个字段的默认值均为 schema 内 `default`。

---

## 1. theme —— 主题预设名

| 键 | YAML 类型 | 允许枚举值 | 默认值 | 备注 |
|---|---|---|---|---|
| `theme.dark` | string | 见下方「内置主题名」;`options: "runtime"`(动态) | `"titanium"` | 终端深色背景时使用(schema:574-584) |
| `theme.light` | string | 同上;`options: "runtime"` | `"light"` | 终端浅色背景时使用(schema:586-596) |

**内置主题名(枚举,来自 `src/modes/theme/defaults/index.ts:100-199` 的 `defaultThemes` 键 + `dark`/`light` 内置):**

- 深色/通用: `dark`、`alabaster`、`amethyst`、`anthracite`、`basalt`、`birch`、`dark-abyss`、`dark-arctic`、`dark-aurora`、`dark-catppuccin`、`dark-cavern`、`dark-copper`、`dark-cosmos`、`dark-cyberpunk`、`dark-dracula`、`dark-eclipse`、`dark-ember`、`dark-equinox`、`dark-forest`、`dark-github`、`dark-gruvbox`、`dark-lavender`、`dark-lunar`、`dark-midnight`、`dark-monochrome`、`dark-monokai`、`dark-nebula`、`dark-nord`、`dark-ocean`、`dark-one`、`dark-poimandres`、`dark-rainforest`、`dark-reef`、`dark-retro`、`dark-rose-pine`、`dark-sakura`、`dark-slate`、`dark-solarized`、`dark-solstice`、`dark-starfall`、`dark-sunset`、`dark-swamp`、`dark-synthwave`、`dark-taiga`、`dark-terminal`、`dark-tokyo-night`、`dark-tundra`、`dark-twilight`、`dark-volcanic`、`graphite`、`limestone`

- 浅色: `light`、`light-arctic`、`light-aurora-day`、`light-canyon`、`light-catppuccin`、`light-cirrus`、`light-coral`、`light-cyberpunk`、`light-dawn`、`light-dunes`、`light-eucalyptus`、`light-forest`、`light-frost`、`light-github`、`light-glacier`、`light-gruvbox`、`light-haze`、`light-honeycomb`、`light-lagoon`、`light-lavender`、`light-meadow`、`light-mint`、`light-monochrome`、`light-ocean`、`light-one`、`light-opal`、`light-orchard`、`light-paper`、`light-poimandres`、`light-prism`、`light-retro`、`light-sand`、`light-savanna`、`light-solarized`、`light-soleil`、`light-sunset`、`light-synthwave`、`light-tokyo-night`、`light-wetland`、`light-zenith`

- 通用皮肤系(不标注深浅,依内容): `mahogany`、`marble`、`obsidian`、`onyx`、`pearl`、`porcelain`、`quartz`、`sandstone`、`titanium`、`limestone`

> **运行时可扩展**:`getAvailableThemes()`(loader.ts:27)会追加自定义主题目录里 `*.json` 文件名。GUI 应视为「下拉中文档内置列表 + 运行时刷新」,勿硬编码死列表。

**推荐暴露**:外观页提供一个主题预设下拉(编辑 `theme.dark`/`theme.light`),并可选择「亮/暗自动跟随(OSC 11 检测)」;下拉项建议运行时从 `getAvailableThemes()` 拉取,静态列表仅作兜底。

---

## 2. statusLine —— 状态栏

### 2.1 枚举类

| 键 | YAML 类型 | 允许枚举值(schema 原文) | 默认 | 说明 |
|---|---|---|---|---|
| `statusLine.preset` | enum | `["default","minimal","compact","full","nerd","ascii","custom"]` | `"default"` | 预设状态栏配置(schema:629) |
| `statusLine.separator` | enum | `["powerline","powerline-thin","slash","pipe","block","none","ascii"]` | `"powerline-thin"` | 分段分隔符样式(schema:650) |

UI label(供中文界面映射):
- preset 选项描述: default=模型/路径/git/上下文/token/成本; minimal=仅路径+git; compact=模型/git/成本/上下文; full=全部含时间; nerd=最丰富(Nerd Font 图标); ascii=无特殊字符; custom=自定义分段(schema:635-645)。
- separator 选项: powerline=实心箭头; powerline-thin=细箭头; slash=正斜杠; pipe=竖线; block=实心块; none=仅空格; ascii=大于号。

### 2.2 布尔开关(statusLine.)

| 键 | YAML 类型 | 默认 | 说明 |
|---|---|---|---|
| `statusLine.sessionAccent` | boolean | `true` | 用会话名颜色渲染编辑器边框与状态栏间隙 |
| `statusLine.transparent` | boolean | `false` | 状态栏用终端默认背景而非主题 `statusLineBg`(会丢弃 powerline 端帽) |
| `statusLine.compactThinkingLevel` | boolean | `false` | 思考级别以单图标呈现在模型名上,而非 ` · <level>` 后缀 |
| `statusLine.showHookStatus` | boolean | `true` | 在状态栏下方显示 hook 状态消息 |

### 2.3 自定义分段(与 `preset: custom`/`leftSegments` 配合)

| 键 | YAML 类型 | 默认 |
|---|---|---|
| `statusLine.leftSegments` | array(元素为 StatusLineSegmentId 字符串) | `[]` |
| `statusLine.rightSegments` | array(同上) | `[]` |
| `statusLine.segmentOptions` | record(自由 key->unknown) | `{}` |

**可用 segment id(`StatusLineSegmentId` 类型,schema 里枚举):**
`pi` `model` `mode` `path` `git` `pr` `subagents` `token_in` `token_out` `token_total` `token_rate` `cost` `context_pct` `context_total` `time_spent` `time` `session` `hostname` `cache_read` `cache_write` `cache_hit` `session_name` `usage` `collab`

> 注:`leftSegments`/`rightSegments` 需配合 `statusLine.preset: "custom"` 才会以用户自定义段生效(而非预设覆盖)。GUI 可在「自定义」预设下给出段的多选(左/右两组)。

---

## 3. display —— 显示开关

| 键 | YAML 类型 | 允许枚举值 | 默认 | 说明 |
|---|---|---|---|---|
| `display.shimmer` | enum | `["classic","kitt","disabled"]` | `"classic"` | 工作/加载动画样式:classic=柔和余弦波; kitt=KITT 左右扫光; disabled=关闭 |
| `display.smoothStreaming` | boolean | — | `true` | 增量平滑揭示助手文本与流式工具输入 |
| `display.hideToolActivity` | boolean | — | `false` | 隐藏模型发起的工具调用及结果 |
| `display.showTokenUsage` | boolean | — | `false` | 在助手消息上显示每轮 token 用量 |
| `display.cacheMissMarker` | boolean | — | `false` | 在命中失败(缓存未命中)的助手轮上方显示分隔条 |
| `display.collapseCompacted` | boolean | — | `true` | 压缩历史收拢到摘要分隔条后;false=保留全量内联 |
| `showHardwareCursor`(顶层) | boolean | — | `true`(平台计算) | 显示终端光标(IME 支持) |
| `tui.imeSafeCursor` | boolean | — | `false` | macOS IME 提示边框移到单独一行(护版式提示布局) |
| `tui.tight` | boolean | — | `false` | 移除终端输出左右 1 字符水平内边距(紧凑布局) |
| `tui.titleState` | boolean | — | `true` | 终端标题分隔符显示运行态(工作=spinner,你的回合=`,等待=`) |
| `tui.textSizing` | boolean | — | `false` | Kitty 终端把 H1 标题放大 2 倍;仅 Kitty 生效 |
| `tui.renderMermaid` | boolean | — | `true` | 将 Mermaid 代码块渲染为 ASCII 图 |
| `tui.scrollbackRebuild` | boolean | — | `false` | 块最终形态重放 /* replay scrollback */ |
| `tui.hyperlinks` | enum | `["off","auto","always"]` | `"auto"` | OSC 8 超链接:关/自动检测/始终 |
| `tui.codexResetFireworks` | boolean | — | `false` | Codex 每周重置的烟花庆祝 |
| `terminal.showProgress` | boolean | — | `false` | 运行期间发 OSC 9;4 进度(原生终端进度条) |

> `display.*` 高频推荐暴露:`showTokenUsage`、`cacheMissMarker`、`smoothStreaming`、`hideToolActivity`、`collapseCompacted`、`shimmer`;`tui.tight`、`tui.renderMermaid`、`tui.hyperlinks` 亦属外观页推荐项。

---

## 4. symbolPreset / colorBlindMode

| 键 | YAML 类型 | 允许枚举值 | 默认 | 说明 |
|---|---|---|---|---|
| `symbolPreset` | enum | `["unicode","nerd","ascii"]` | `"unicode"` | 图标/符号字形集:默认(unicode)、需 Nerd Font(nerd)、最大兼容(ascii) |
| `colorBlindMode` | boolean | — | `false` | 色盲模式:diff 新增用蓝色替代绿色 |

---

## 5. Thinking 相关(外观页常见开关)

| 键 | YAML 类型 | 允许枚举值 | 默认 | 说明 |
|---|---|---|---|---|
| `defaultThinkingLevel` | enum | `["minimal","low","medium","high","xhigh","max","auto"]` | `"high"` | 默认思考级别(由 `THINKING_EFFORTS` + `auto` 构成,schema:1085-1099) |
| `hideThinkingBlock` | boolean | — | `false` | 隐藏助手回复中的思考块 |
| `proseOnlyThinking` | boolean | — | `true` | (外观相关,下方 schema 邻近)仅对进阶思考展示为段落 |

> `defaultThinkingLevel` 虽在 `tab: "model"` 分组,但常与「思考块显示」一起列入外观/交互页;是否纳入外观页由 GUI 布局决策。

---

## 6. 其它可识别外观项(tab 归属 `appearance`)

| 键 | YAML 类型 | 默认 | 说明 |
|---|---|---|---|
| `terminal.showImages` | boolean | `true` | 终端内联渲染图片(需 `hasImageProtocol`) |
| `images.autoResize` | boolean | `true` | 大图自动缩到 2000x2000 |
| `images.blockImages` | boolean | `false` | 阻止图片发送给 LLM provider |
| `tui.maxInlineImageColumns` | number | `100` | 内联图片最大宽度列数(0=不限) |
| `tui.maxInlineImageRows` | number | `20` | 内联图片最大行数(0=仅 viewport 60%) |
| `tui.maxInlineImages` | number | `8` | 保持为活动终端图形的内联图片上限 |

> 图片相关在 UI 分组「Images」;若 GUI 外观页要涵盖图片协议/内联渲染,可将 `terminal.showImages` 等纳入。

---

## 7. GUI 外观页推荐暴露字段清单(建议)

**主题区(Theme)**
1. `theme.dark` —— 下拉(深色预设;运行时 `getAvailableThemes()` 刷新;默认 `titanium`)
2. `theme.light` —— 下拉(浅色预设;默认 `light`)
3. `symbolPreset` —— 下拉 `unicode|nerd|ascii`(默认 `unicode`)
4. `colorBlindMode` —— 开关(默认 `false`)

**状态栏区(Status Line)**
5. `statusLine.preset` —— 下拉 7 值(默认 `default`)
6. `statusLine.separator` —— 下拉 7 值(默认 `powerline-thin`)
7. `statusLine.sessionAccent` —— 开关(默认 `true`)
8. `statusLine.transparent` —— 开关(默认 `false`)
9. `statusLine.compactThinkingLevel` —— 开关(默认 `false`)
10. `statusLine.showHookStatus` —— 开关(默认 `true`)
11. `statusLine.leftSegments` / `statusLine.rightSegments` —— 「自定义」多选(段 id 见 2.3;默认 `[]`);选择时同步 `statusLine.preset` 为 `custom`

**显示区(Display)**
12. `display.shimmer` —— 单选(默认 `classic`)
13. `display.smoothStreaming` —— 开关(默认 `true`)
14. `display.showTokenUsage` —— 开关(默认 `false`)
15. `display.cacheMissMarker` —— 开关(默认 `false`)
16. `display.collapseCompacted` —— 开关(默认 `true`)
17. `display.hideToolActivity` —— 开关(默认 `false`)
18. `tui.tight` —— 开关(默认 `false`)
19. `tui.renderMermaid` —— 开关(默认 `true`)
20. `tui.hyperlinks` —— 下拉 `off|auto|always`(默认 `auto`)

**思考显示区(Thinking, 可选)**
21. `hideThinkingBlock` —— 开关(默认 `false`)
22. `defaultThinkingLevel` —— 下拉(默认 `high`): `minimal|low|medium|high|xhigh|max|auto`

> 解释:以上主要选取 `tab:"appearance"` 分组内的字段;`defaultThinkingLevel`/`proseOnlyThinking` 属 `tab:"model"` 但思考层默认层面,是否置外观页由产品定。所有默认值均直接取自 `SETTINGS_SCHEMA`。

---

## 变更记录
- 2026-09-14 首次归档(研究子代理 02)。
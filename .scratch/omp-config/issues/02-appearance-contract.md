Type: research
Status: resolved

## Question

从 omp 源码提取 `~/.omp/agent/config.yml` 中「主题 + 显示」相关字段的**可用枚举、可写键与默认值**,产出外观编辑契约,供 GUI 外观页构建下拉/开关。

- 只读源码: `node_modules/@oh-my-pi/pi-coding-agent/src/config/{settings-schema.ts, settings.ts}`。
- 重点字段: `theme`(dark/light 预设名枚举)、`statusLine`(preset/separator/rightSegments/leftSegments/segmentOptions 可选值)、`display`(showTokenUsage/cacheMissMarker 等开关)、`symbolPreset`、`colorBlindMode`、`hideThinkingBlock`、`defaultThinkingLevel` 等「看得出」的项。
- 每个输出字段: 键、YAML 类型、允许枚举值(从 schema 抄)、默认值。

产物: 一份 `docs/resources/02-appearance-contract.md`(外观字段表)。据此列出外观页拟暴露字段的推荐清单。

## Answer

**结论要点**(细节见产物 `docs/resources/02-appearance-contract.md`):

- config.yml 外观字段全部由 `SETTINGS_SCHEMA`(settings-schema.ts)单一同源声明;`settings.ts` 按 `.` 分段的嵌套路径读写落盘。
- theme: `theme.dark` 默认 `titanium`、`theme.light` 默认 `light`,值为 string(运行时枚举 ~100 内置主题名,`getAvailableThemes()` 可加自定义),非硬编码下拉。
- statusLine: `preset` 7 值(default 默认)、`separator` 7 值(powerline-thin 默认)、`leftSegments`/`rightSegments` 元素为 `StatusLineSegmentId`(24 个 id,含 pi/model/path/git/token_in/token_out/cost/context_pct/cache_read 等)、`segmentOptions` 为自由 record。
- display: `showTokenUsage`(默认 false)、`cacheMissMarker`(默认 false)、`smoothStreaming`(true)、`hideToolActivity`(false)、`collapseCompacted`(true)、`shimmer`(`classic|kitt|disabled`)等。
- symbolPreset=`unicode|nerd|ascii`(默认 unicode);colorBlindMode 布尔(默认 false)。
- 思考: `defaultThinkingLevel`=`minimal|low|medium|high|xhigh|max|auto`(默认 high);`hideThinkingBlock`(默认 false)。
- GUI 外观页推荐暴露清单(主题/状态栏/显示/思考显示 22 项)已列于产物第 7 节。

产物: `docs/resources/02-appearance-contract.md`
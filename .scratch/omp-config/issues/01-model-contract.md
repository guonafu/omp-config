Type: research
Status: resolved

## Question

从 omp 源码中提取 `~/.omp/agent/models.yml` 的**精确可写 schema 与校验规则**,产出后端读写契约,供 UI 表单与写回逻辑参考。

- 参考源码: `node_modules/@oh-my-pi/pi-coding-agent/src/config/{models-config.ts, models-config-schema.ts, models-config-schema-bundle.ts, model-registry.ts, config-file.ts}`。
- 覆盖: `providers.<name>` 的字段 `baseUrl/api/auth/apiKey/models[]` 及每个 `models[]` 条目的 `id/name/reasoning/input/contextWindow/maxTokens` 等,逐字段标必需/可选/枚举/默认;写回时的校验规则与类型。
- 顺带确认 ConfigFile 的 YAML 写回格式(缩进、引号、键序),避免 GUI 写坏 omp 可读性。

产物: 一份 `docs/research/01-model-contract.md`(字段表 + 校验集 + 写回序列化要点),并据此给出后端 C++ 数据模型的字段清单建议。

## Answer

研究完成,产物: `docs/research/01-model-contract.md`。

**结论要点**:
- 顶层结构仅 `providers`(可选),provider 键任意非空字符串。
- `providers.<name>` 可写字段: `baseUrl?` / `apiKey?` / `api?`(9 值枚举) / `auth?`(`apiKey|none|oauth`) / `authHeader?` / `headers?` / `compat?` / `remoteCompaction?` / `discovery?` / `models?` / `modelOverrides?` / `disableStrictTools?` / `transport?`(`"pi-native"`)。
- 业务校验(models-config.ts:44-80): 有 `models[]` 时 provider 必填 `baseUrl` 且(`apiKey` 或 `auth: none`);无 `models` 时给任一字段即可;provider 级无 `api` 时每个 model 须有 model 级 `api`;`discovery` 非 proxy 且无 `api` 报错。
- `models[]` 每项: `id`(必填非空) / `name` / `api` / `baseUrl` / `reasoning` / `thinking` / `input`(`["text"|"image"]`) / `imageInputDecoder`(`"stb"`) / `supportsTools` / `cost`(4 键) / `premiumMultiplier` / `contextWindow` / `maxTokens`(设了须 >0) / `omitMaxOutputTokens` / `headers` / `compat` / `contextPromotionTarget` / `compactionModel` / `remoteCompaction`。
- `thinking` 关键:narrow 要求 `efforts`/`levels`/`minLevel+maxLevel` 至少其一,否则整文件校验失败。
- 运行期数字拒绝:`contextWindow<=0`、`maxTokens<=0` 报错。
- YAML 写回: 2 空格缩进、裸布尔/数字、字符串按需双引号、数组 `[text, image]`、键序固定、写入前跑 §9 校验集、原子写临时文件后 rename。GUI 建议 merge 保留未知键与用户注释。
- 后端 C++ 数据模型字段清单建议见产物 §11。
# 01 | `~/.omp/agent/models.yml` 可写 schema 契约

> 研究范围: omp 源码 `src/config/{models-config.ts, models-config-schema.ts, models-config-schema-bundle.ts, model-registry.ts, config-file.ts}`
> 用途: 为 omp 配置 GUI(Qt6 + DTK6)的表单、写回逻辑与后端 C++ 数据模型提供权威契约。
> 结论基于源码静态阅读,证据以 `file:line` 标注。

---

## 1. 文件定位与加载机制

- 权威路径:`~/.omp/agent/models.yml`(`getAgentDir() + "models.yml"`),见 `config-file.ts:107`(`new ConfigFile<ModelsConfig>("models", …)`)、`config-file.ts:86`(路径拼接)。
- 读取用 **Bun 内置 YAML** 解析(`config-file.ts:#parseContent`, `YAML.parse(content)`),非 JSONC。
- `.yml` 之外的兼容:框架自动回退 `.yaml`,并支持从旧的 `.json` 自动迁移(`config-file.ts:37-60`, `#ensureMigrated`)。但**写回只保证 `.yml` 主路径**。
- 解析失败(类型错、枚举错、必填缺失、`narrow` 校验失败)整文件拒绝 → `status: "error"`(`config-file.ts:#parseContent`);缺失则 `not-found`。写入必须保证整文件可解析。

顶层结构(schema,`models-config-schema-bundle.ts:ModelsConfigSchema`):

```ts
type ModelsConfig = {
  providers?: { [providerName: string]: ProviderConfig };   // 键 = provider 名称,任意非空字符串
};
```

顶层只有 `providers` 一个键,且可选;其它任何顶层键均为非法(整文件校验失败)。

---

## 2. `providers.<name>` 字段表(ProviderConfigSchema)

证据:`models-config-schema-bundle.ts:ProviderConfigSchema`(约 268-302 行)。

| 字段 | 必需 | 类型 | 默认/枚举 | 附加规则(非空校验) |
|---|---|---|---|---|
| `baseUrl` | 条件必需* | `string` | 无 | 非空(`narrow`) |
| `apiKey` | 条件必需* | `string` | 无 | 非空(`narrow`) |
| `api` | 条件必需** | 枚举 | 无 | 见下方 `api` 枚举 |
| `auth` | 可选 | `"apiKey" \| "none" \| "oauth"` | 取 `apiKey`(代码中 `config.auth ?? "apiKey"`) | — |
| `authHeader` | 可选 | `boolean` | `false` | — |
| `headers` | 可选 | `{ [k: string]: string }` | 无 | 值必须 string |
| `compat` | 可选 | `ApiCompatSchema`(见 §5) | 无 | — |
| `remoteCompaction` | 可选 | `RemoteCompactionSchema`(见 §4) | 无 | — |
| `discovery` | 可选 | `ProviderDiscoverySchema`(见 §3) | 无 | — |
| `models` | 可选(数组) | `ModelDefinition[]` | `[]` | 元素逐项 `narrow` |
| `modelOverrides` | 可选 | `{ [modelId: string]: ModelOverride }` | 无 | 每项 `narrow` |
| `disableStrictTools` | 可选 | `boolean` | `false` | — |
| `transport` | 可选 | `"pi-native"` | `undefined` | 唯一合法枚举值 `"pi-native"` |

> **条件必需规则**(`models-config.ts:validateProviderConfiguration`, `models-config.ts:44-80`):
>
> 1. **`models` 为空数组**时:provider 只要给出 `baseUrl`/`headers`/`apiKey`/`auth: none`/`compat`/`disableStrictTools`/`remoteCompaction`/`modelOverrides`/`discovery` 中**任意一个**,即合法(用于仅改写或禁用内置模型的场景)。
> 2. **`models` 非空**时:
>    - `baseUrl` 必填(否则抛 "`baseUrl` is required when defining custom models.")。
>    - `apiKey` 必填,**除非** `auth === "none"`(`requiresAuth = !apiKey && (auth ?? "apiKey") !== "none"`)。
> 3. 若设置了 `discovery` 且 `api` 缺失,仅当 `discovery.type === "proxy"` 允许;否则要求 `api`(`models-config.ts:66-67`)。
> 4. **每个 model 必须有 api 来源**:provider 级 `api` 与 model 级 `api` 至少一个存在,否则抛 "no 'api' specified"(`models-config.ts:60-69`)。

### 顶层 `api` 枚举(ApiSchema)

来源:`models-config-schema-bundle.ts:ApiSchema`。**GUI 需下拉框提供**:

```
"openai-completions" | "openai-responses" | "openai-codex-responses" |
"azure-openai-responses" | "anthropic-messages" | "bedrock-converse-stream" |
"google-generative-ai" | "google-gemini-cli" | "google-vertex"
```

### 顶层 `auth` 枚举

`"apiKey" | "none" | "oauth"`(`ProviderAuthSchema`)。三者互斥单选;`auth: none` 时省略 `apiKey` 往往是有意为之(匿名端点)。

---

## 3. `provider.discovery` 子结构

来源:`models-config-schema-bundle.ts:ProviderDiscoverySchema`。

| 字段 | 必需 | 类型 / 枚举 | 校验 |
|---|---|---|---|
| `type` | **必需** | `"ollama" \| "llama.cpp" \| "lm-studio" \| "openai-models-list" \| "proxy" \| "litellm"` | — |
| `timeoutMs` | 可选 | `number` | 必须正有限数(`> 0 && isFinite`,`narrow`) |

---

## 4. `provider.remoteCompaction` 子

来源:`models-config-schema-bundle.ts:RemoteCompactionSchema`。

| 字段 | 必需 | 类型 |
|---|---|---|
| `enabled` | 可选 | `boolean` |
| `api` | 可选 | `ApiSchema`(同上枚举) |
| `endpoint` | 可选 | `string`(非空校验) |
| `model` | 可选 | `string`(非空校验) |
| `v2StreamingEnabled` | 可选 | `boolean` |
| `v2Endpoint` | 可选 | `string`(非空校验) |
| `streamingEndpoint` | 可选 | `string`(非空校验) |

---

## 5. `compat` 子 Schema(ApiCompatSchema)

`OpenAICompatSchema` ∩ `BedrockCompatSchema`(`models-config-schema-bundle.ts:ApiCompatSchema`)。

**`api` = openai 系时可用**(`OpenAICompatFields` + `whenThinking` 嵌套,`12-45`):

```
supportsStore / supportsDeveloperRole / supportsMultipleSystemMessages /
supportsReasoningEffort / supportsUsageInStreaming / supportsStrictMode /
supportsLongPromptCacheRetention / supportsReasoningParams / alwaysSendMaxTokens /
strictResponsesPairing / supportsImageDetailOriginal / supportsEagerToolInputStreaming /
allowAnthropicHeaderOverrides / supportsToolChoice / supportsForcedToolChoice /
disableReasoningOnForcedToolChoice / disableReasoningOnToolChoice /
requiresToolResultName / requiresMistralToolIds / requiresAssistantAfterToolResult /
requiresThinkingAsText / requiresToolResultId / replayUnsignedThinking
      → boolean?                           (可选)
reasoningEffortMap / openRouterRouting / vercelGatewayRouting
      → 对象?(可空)
maxTokensField  → "max_completion_tokens" | "max_tokens"?
reasoningContentField → "reasoning_content" | "reasoning" | "reasoning_text"?
thinkingFormat → "openai" | "openrouter" | "zai" | "qwen" | "qwen-chat-template"?
cacheControlFormat → "anthropic"?
toolStrictMode → "all_strict" | "none"?
streamIdleTimeoutMs → number >= 0?
extraBody → { [string]: unknown }?
whenThinking → (上述同款字段全集)?
```

**`api` = bedrock 时可用**(`BedrockCompatSchema`):

```
promptCacheMode → "none" | "automatic" | "explicit"?
supportsLongPromptCacheRetention → boolean?
promptCacheMinimumTokens / promptCacheMaximumCheckpoints → number >= 0?
```

> GUI 建议:`compat` 为高级字段,默认折叠;提供了各 api 的 related 枚举/布尔开关即可,不必展示全部(面板密不过)。

---

## 6. `models[]` 每项字段表(ModelDefinitionSchema)

来源:`models-config-schema-bundle.ts:ModelDefinitionSchema`(约 149-198 行)。

| 字段 | 必需 | 类型 / 枚举 | 默认 | 校验(narrow / 运行期) |
|---|---|---|---|---|
| `id` | **必需** | `string` | — | 非空(narrow);运行期:provider 内**每个模型必需 id**、禁止缺(`models-config.ts:62-66`) |
| `name` | 可选 | string | 无 | 非空(narrow) |
| `api` | 条件必需 | `Api`(同 §2 枚举) | 无 | provider 级无 `api` 时模型级必填 |
| `baseUrl` | 可选 | string | 继承 provider | 非空(narrow) |
| `reasoning` | 可选 | boolean | `false` | 布尔开关 |
| `thinking` | 可选 | `ModelThinkingSchema`(见 §7) | 无 | 见 §7 |
| `input` | 可选 | `("text" \| "image")[]` | 无 | 元素仅 `text`/`image` |
| `imageInputDecoder` | 可选 | `"stb"` | 无 | 唯一合法值 `"stb"` |
| `supportsTools` | 可选 | boolean | 无 | 布尔 |
| `cost` | 可选 | 对象:textM | 无 | 见下 |
| `premiumMultiplier` | 可选 | number | 无 | number |
| `contextWindow` | 可选 | number | 无 | **运行期必须 > 0**(`models-config.ts:69-72`,`invalid contextWindow`) |
| `maxTokens` | 可选 | number | 无 | **运行期必须 > 0**(`models-config.ts:72-75`) |
| `omitMaxOutputTokens` | 可选 | boolean | `false` | 布尔 |
| `headers` | 可选 | `{ [k: string]: string }` | 无 | 值为 string |
| `compat` | 可选 | `ApiCompat` | 无 | 同 §5 |
| `contextPromotionTarget` | 可选 | string | 无 | 非空(narrow) |
| `compactionModel` | 可选 | string | 无 | 非空(narrow) |
| `remoteCompaction` | 可选 | `RemoteCompaction` | 无 | 同 §4 |

`cost` 子对象(必填 4 键,键名固定):

```yaml
cost:
  input: number
  output: number
  cacheRead: number
  cacheWrite: number
```

> **运行期拒绝**两种非法数字:`contextWindow <= 0`、`maxTokens <= 0` 直接抛错(`models-config.ts:69-75`)。GUI 写回前必须做 `> 0` 校验。

---

## 7. `thinking` 子 Schema(ModelThinkingSchema)

来源:`models-config-schema-bundle.ts:ModelThinkingSchema`(约 60-100 行)。

| 字段 | 必需 | 类型/枚举 | 备注 |
|---|---|---|---|
| `mode` | **必需** | `"effort" \| "budget" \| "google-level" \| "anthropic-adaptive" \| "anthropic-budget-effort"` | 单选 |
| `efforts` | 条件 | `Effort[]` | 现代词汇,优先 |
| `defaultLevel` | 可选 | Effort | — |
| `effortMap` | 可选 | `{ minimal/low/medium/high/xhigh/max?: string }` | 键为 §8 枚举 |
| `supportsDisplay` | 可选 | boolean | — |
| `minLevel` | *legacy* | Effort | 旧版下限 |
| `maxLevel` | *legacy* | Effort | 旧版上限 |
| `levels` | *legacy* | Effort[] | 旧版范围 |

Effort 枚举(`EffortSchema`):`"minimal" | "low" | "medium" | "high" | "xhigh" | "max"`。

**校验(narrow,重要)**:`thinking` 对象至少要给出其一,否则整文件校验失败:
`value.efforts !== undefined || value.levels !== undefined || (minLevel !== undefined && maxLevel !== undefined)`。
写入时必须满足三选一。

---

## 8. `modelOverrides`(可选,松耦合改写内置模型)

来源:`models-config-schema-bundle.ts:ModelOverrideSchema`。与 §6 `ModelDefinition` **几乎同构但更松开**:
- 无 `id`(以 map key 为模型 id)、无 `api`、无 `baseUrl`。
- 仅含:`name? / reasoning? / thinking? / input? / imageInputDecoder? / supportsTools? / cost? / premiumMultiplier? / contextWindow? / maxTokens? / omitMaxOutputTokens? / headers? / compat? / contextPromotionTarget? / compactionModel? / remoteCompaction?`,全部可选。
- 运行期对 `contextWindow`/`maxTokens` 不要求 > 0(此处无该校验);但 schema 内仍做非空窄检查(名称类字段)。

---

## 9. 写回校验规则汇总(GUI 写回前逐条检查)

1. 顶层只允许 `providers`。
2. provider 名任意;**键唯一**。
3. 有 `models[]` 时:provider 必须 `baseUrl` +(`apiKey` 或 `auth: "none"`),否则报错。
4. 无 `models[]` 时:至少给出一个有效字段,避免空 provider 报空错。
5. provider 无 `api` 时,每个 model 必须有 model 级 `api`。
6. `discovery` 非 `proxy` 且无 `api` → 报错。
7. 每个 model 必须有 `id`,且非空。
8. `contextWindow`、`maxTokens` 若给出必须 `> 0`。
9. `input[]` 元素仅 `text|image`。
10. `auth` 仅 `apiKey/none/oauth`;`api` 仅 §2 枚举。
11. `thinking` 至少给 `efforts`/`levels`/`minLevel+maxLevel` 其一。
12. 数字字段:必须是 JSON/YAML number(`type` 校验),不要用字符串,否则读回校验失败。

---

## 10. YAML 写回序列化要点(与 omp 兼容)

读侧严格,写侧宽松:只要 GUI 系列成的 YAML 满足上述 `type`/`narrow`,**并在写后能被 omp 的 JSON-to-YAML 逻辑读回即算兼容**。要点:

- **缩进**:2 空格(标准 YAML;真实 `~/.omp/agent/models.yml` 即为 2 空格块缩进)。拒绝 Tab。
- **键序**:顶层 `providers` → 每个 provider 固定顺序 `baseUrl / api / auth / apiKey / models`;每个 model 固定顺序 `id / name / reasoning / input / contextWindow / maxTokens`(真实相符合;保持固定让 diff 友好)。
- **引号策略**:字符串若无歧义不必要引号(YAML 标量),但含特殊字符(`: `、`#`、`:`,`/`,`@`、ASCII 非打印、以引号/换行开头等)时用双引号包裹。**建议 GUI 统一:普通标识符/URL 不引号;含任何特殊字符或含前导/尾随空格者用双引号**。真实文件把 `apiKey` 用双引号包裹字符串(如 `"sk-..."`)—带 `-`/`/` 的 token 宜加引号保险。
- **布尔**:`true`/`false`(小写,不带引号)。**不用 `yes/no`** 以免解析歧义。
- **数字**:**裸数字**,不带引号。
- **数组**:
  - `input`:流量风格区间 `[text, image]` 或块 `- text\n- image` 均可;**元素是裸枚举标识,不带引号**(`input: [text, image]`真实文件用例)。
  - YAML 1.2(bun/js-yaml)`input: [text,image]`(无法逗号后空格缺失)也能解析,但建议按真实惯例 `[text, image]`。
- **空 provider/models**:省略字段比写 null 清洁;框架会用默认值。
- **文件 end**:单一 `\n` 结尾,无 BOM;ctor UTF-8。
- **注释**:保留用户手写注释(写回时最好保留已有注释区块,或所有自成文件基于读入对象重构;若重构会丢注释,建议只改字段级差异)。

### 建议 GUI 写回策略

- 读入 → 模态对象 → 编辑 → **以作者保留(merge 时保留用户注释与未知键,只覆盖编辑过的字段)**。
- 输出前对全文件跑一遍 §9 校验集,失败则阻止保存并高亮字段。
- 原子写:先写临时文件再 rename,避免中途崩溃留下半截 YAML(o以 omp 读侧 `status:"error"` 处理)。

---

## 11. 后端 C++ 数据模型字段清单建议

基于 §2/§3/§4/§6/§7,建议 Qt6 + DTK6 后端定义 `models.yml` 一一对应的 POD/模型(带 QVariant 友好的 setter + 校验):

```cpp
// provider 级
struct ProviderConfig {
    QString name;                     // map key
    QString baseUrl;                  // 非空
    QString apiKey;                   // 非空(除非 auth==none)
    QString api;                      // 枚举 → Api enum
    QString auth = "apiKey";          // "apiKey"|"none"|"oauth"
    bool authHeader = false;
    QHash<QString,QString> headers;
    QVariantMap compat;               // 见 §5(稀疏,按 api 解释)
    QHash<QString,QVariantMap> modelOverrides;  // map id → override对象
    bool disableStrictTools = false;
    QString transport;                // "pi-native"(可选)
    // rules
    bool hasDiscovery=false; ProviderDiscovery discovery;
    bool hasRemoteCompaction=false; RemoteCompaction remoteCompaction;
    QVector<ModelDefinition> models;
};

struct ProviderDiscovery {
    enum Type { Ollama, LlamaCpp, LmStudio, OpenaiModelsList, Proxy, LiteLLM };
    Type type;
    qint32 timeoutMs = 0;             // 0=未设;设置须>0
};

struct RemoteCompaction {
    bool enabled = false;
    QString api;
    QString endpoint, model, v2Endpoint, streamingEndpoint;
    bool v2StreamingEnabled = false;
};

// model 级
struct ModelDefinition {
    QString id;                       // 必填非空
    QString name;
    QString api;                      // api enum
    QString baseUrl;
    bool hasReasoning=false; bool reasoning=false;
    QVector<QString> input;           // 枚举 "text"/"image"
    QString imageInputDecoder;        // "stb"
    bool hasSupportsTools=false; bool supportsTools=false;
    double premiumMultiplier=0;       // 0=未设
    bool hasContextWindow=false; quint64 contextWindow=0;   // if has → >0 校验
    bool hasMaxTokens=false; quint64 maxTokens=0;          // if has → >0 校验
    bool omitMaxOutputTokens=false;
    QHash<QString,QString> headers;
    QVariantMap compat;              // §5
    QString contextPromotionTarget, compactionModel;
    bool hasRemoteCompaction=false; RemoteCompaction remoteCompaction;
    std::optional<QVector<quint64>> cost;   // input/output/cacheRead/cacheWrite
    std::optional<Thinking> thinking;       // §7
};

struct Thinking {
    QString mode;                    // enum effort/budget/google-level/anthropic-adaptive/anthropic-budget-effort
    QVector<QString> efforts;        // enum
    QString defaultLevel;
    QHash<QString,QString> effortMap;   // minimal..max
    bool supportsDisplay = false;
};
```

**序列化(C++ → YAML)**:
- 手写 block 序列化 or 引第三方 YAML 库(yaml-cpp / QtYaml);键序按本节序(provider → baseUrl, api, auth, apiKey, models;model → id, name, reasoning, input, contextWindow, maxTokens)。
- 数字用 `QString::number`;布尔 `QStringLiteral("true")`/`"false"`;枚举映射到 §2/§7 字符串。
- `QStringList` input 转 `[text, image]`。

**反序列化**:
- 字段缺失时用上表 `hasXxx` 标记区分“未设”与“设了默认”,这样写回时能保留原始未设置状态(不擅自补齐默认值)。
- 遇到未知键必须**保留**(`modelOverrides`/`compat` 本就接受未知子键; 顶层/provider 未知键读入时暂存,避免 GUI 写回丢字段)。

---

## 12. 参考证据索引

| 结论 | 证据(file:line) |
|---|---|
| 顶层仅 `providers?` | models-config-schema-bundle.ts:`ModelsConfigSchema` |
| provider 字段表 | 同文件:`ProviderConfigSchema` |
| provider 级业务校验 | models-config.ts:44-77(`validateProviderConfiguration`) + 100-130(ModelsConfigFile aux) |
| model 字段表 | bundle:`ModelDefinitionSchema` |
| cost 结构 | bundle:`ModelDefinitionSchema` 内 `cost` |
| thinking | bundle:`ModelThinkingSchema` + narrow |bundle:EffortSchema |
| input 枚举 | bundle:`"(\"text\" | \"image\")[]"` |
| discovery | bundle:`ProviderDiscoverySchema` |
| api 枚举 | bundle:`ApiSchema` |
| auth 枚举 | bundle:`ProviderAuthSchema` |
| modelOverrides | bundle:`ModelOverrideSchema` |
| YAML 解析/YAML 文件判定 | config-file.ts:`#parseContent`(YAML.parse / JSON fallback) |
| 加载失败处理 | config-file.ts:`tryLoad`/`#parseContent` |

_注: models.xml 与 discovery缓存(models.db)无关;本文件不讨论 models.db。_
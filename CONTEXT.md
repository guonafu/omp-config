# omp 配置工具

维护 omp（Oh My Pi）本地配置的桌面应用：`~/.omp/agent/models.yml` 里的 provider/model，以及 `~/.omp/agent/config.yml` 里的角色绑定与外观设置。

## Language

**Provider**：
`models.yml` 里的一个服务提供方条目，键名就是它的名字，带 baseUrl/apiKey/api 与一组 Model。
_避免_: 服务商、渠道

**Model**：
某个 Provider 下的一个模型条目，在该 Provider 内由 `id` 唯一标识；离开 Provider 它不唯一。
_避免_: 引擎、模型项

**模型选择器**：
引用一个 Model 的字符串。omp 接受多种写法：`provider/modelId`（在第一个 `/` 处切分）、裸 model id、角色别名（`@role`、`pi/role`、`*`），并可带 `:<thinkingLevel>` 或 `@<upstreamSlug>` 后缀；provider 与 model id 都按不区分大小写匹配。
_避免_: 模型全名、模型路径、模型标识

**角色绑定**：
`config.yml` 里「工作角色 → 选择器」的映射（如 `task`、`plan`、`smol`）。一个角色只有一条值，这条值可以是一串逗号分隔的选择器。
_避免_: 角色配置、模型分配、角色映射

**候选项**：
某个下拉当场可选的值的集合。角色绑定下拉的候选项是每个 Provider × 每个 Model 的朴素引用 `provider/modelId`（裸 id、别名等其它合法写法不作为候选项，但可手输）；id 栏的候选项是 discovery 拉回的候选 id。
_避免_: 备选、列表项、选项池

**绑定值**：
已经选中、要写回配置的那条值。它不一定出现在候选项里（历史遗留、别的写法，或逗号链）。
_避免_: 当前值、选中项、已选值

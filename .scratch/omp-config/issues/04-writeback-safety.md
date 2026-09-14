Type: prototype
Blocked by: 01

---

## Question

写回 `~/.omp/agent/{models.yml, config.yml}` 前的备份与校验策略怎么定 —— 防止把 omp 真实配置设坏。

- 至少覆盖: ① 保存前按时间戳备份副本的命名与目录(.bak 还是 `~/.omp/agent/*.bak`, 保留几份); ② 写入后校验 YAML 可解析且通过 schema(02 / 01 契约),失败则拒绝并回滚; ③ 原子写(临时文件 + rename),避免中途崩溃留下半文件。
- 与契约(01)校验规则对接。

产物: 一份原型/方案(备份命名、校验流程、原子写步骤), 拍板后在实现中使用。

## Answer

(待 HITL 会话)
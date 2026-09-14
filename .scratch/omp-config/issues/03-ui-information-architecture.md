Type: prototype
Blocked by: 01, 02

---

## Question

主窗口的信息架构与单页控件线该怎么排 —— 依赖模型契约(01)与外观契约(02)的字段集才能把表单控件定形。

- **Qt 6 Qt Quick (QML)**, 不依赖 DTK, 跨平台(Linux/Windows/macOS)。用 Qt Quick Controls 2 组件(`StackView`/`SwipeView`/`ListView` 导航、`Dialog`/`TextField`/`ComboBox` 表单)。
- 需厘清: 主导航形态(堆栈式 StackView vs SideBar+Page)、「模型」页的 provider→model 两级列表与增删改表单、「角色绑定」区(角色 → 下拉选 provider/model)、「外观」页的组织。
- 用一个粗糙 UI 原型(QML 线框/控件 stub)来对齐, 产出页面结构与控件清单。

## Answer

(待 HITL 会话)
# 下拉弹窗里的搜索框：过滤语义、焦点与键盘归属

状态：proposed

下拉候选项一多（角色绑定是"全部 Provider × 全部 Model"，id 栏是 discovery 拉回的候选）就需要过滤。决定：`AppComboBox` 的弹窗顶部是一个**真的 `TextField` 搜索框**，**打开即聚焦**（`Popup.focus: true` + `onOpened: 搜索框.forceActiveFocus()`）并清空；它持有焦点时处理 ↑/↓（移动高亮）、回车（确认，与鼠标点选等价）、Esc（关闭）；**匹配**是不区分大小写的子串，只对行内显示的那串文本（`provider/modelId` / 裸 id），不匹配 Model 的 `name`；**高亮**只有一条规则：打开且未过滤时落在绑定值那一行（不在候选项里就落第一行），一旦过滤就跳首个匹配行；无匹配（含候选项为空）时显示一行不可选的「无匹配」。

## 兜底：ComboBox 上的同语义 Keys

`QQuickComboBox` 在弹窗打开时自己也可能持有焦点，而它的 `keyPressEvent` 会把 ↑/↓/回车按自己的语义处理（非可编辑下拉还会把键入当 `keySearch`，直接改选中值）。所以 `AppComboBox` 上另挂一套同语义的 `Keys`（`priority: Keys.BeforeItem`）作为兜底：搜索框持有焦点时它不会触发；万一焦点落在 ComboBox 上，行为与搜索框一致，不会漏成"键入即选值"。

两个实现陷阱，留作后人指路：

1. **搜索框要显式抢焦点**。只写 `focus: true` 不够——必须在弹窗 `onOpened` 里 `forceActiveFocus()`，否则焦点不会落到它身上。
2. **共享内联组件的 id 不能用来做探针**。`AppComboBox` 是内联组件，先前用"把 `searchField` 存到 root 的一个属性"来观察焦点，读到的是**另一个实例**，于是得出了"焦点 1 秒内被清掉"的错误结论。实例级验证必须让探针与实例成对绑定（实测：`activeFocus=true`、`Window.activeFocusItem` 就是该搜索框，且打字进入、列表随之过滤）。

高亮因此不能依赖 `ComboBox.highlightedIndex`（只读，且此刻没人更新它）——弹窗自持 `activeIndex`（记录原始候选项下标），鼠标路径不变（自绘行发 `itemChosen(index)`）。

## Considered Options

- **不做输入框，只在 ComboBox 上拦截按键**（曾经实现过）：契约能达到，但搜索框没有光标/选区，也不能用输入法——被否掉。
- **定位/type-ahead 而非过滤**（非可编辑下拉本来就有 `keySearch` 的 type-ahead）：候选项上百时列表不缩短，解决不了"难找"。
- **按 Model 的 `name` 一起匹配**：行里只显示引用、不显示 name，会出现"匹配了却看不出为什么"，除非同时改行的显示。

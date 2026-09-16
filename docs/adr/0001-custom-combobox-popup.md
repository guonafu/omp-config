# 自绘 ComboBox 弹窗，不用样式自带的弹窗

Qt Quick Controls 在本机（deepin/UOS）解析到 `org.deepin.dtk` 样式，该样式 ComboBox 的弹窗面板是 `FloatingPanel` → `D.InWindowBlur`（毛玻璃，`hideSource: false`），本机 blur 不生效导致面板近乎全透明、背后文字直接透上来；它自带 delegate（MenuItem）的配色又取自 DTK 主题色，与本应用硬编码的浅色面（卡片 `#fafbfb`）互不匹配，深色主题下会出现看不见的组合。

因此全项目 ComboBox 统一改走 `src/qml/Main.qml` 里的内联组件 `AppComboBox`：自绘不透明浅色面板、自绘行（直接吃 `comboBox.model`，行高固定 32，弹窗高度 = 条数 × 行高），鼠标点选通过自定义 `itemChosen(index)` 通知外部。

代价是键盘与高亮要自己维护：Qt 只在 ComboBox 自己持有焦点时把键交给它，弹窗内的控件一旦拿到 `activeFocus`，按键只在 popupItem→Overlay 链上冒泡，ComboBox 的 ↑/↓/Home/End/Enter 全部失效（Esc 仍由弹窗的 `CloseOnEscape` 关掉）；`ComboBox.highlightedIndex` 只读且不再被更新，所以弹窗必须自持当前高亮项。相对地，样式弹窗的 `delegateModel` 通路在本机渲染不全（弹窗只画出部分行），自绘行反而更可控。

## Considered Options

- **改 `popup.background` / `FloatingPanel.backgroundColor`**：DTK 的 `backgroundColor` 是 `D.Palette`，赋值需要 `import org.deepin.dtk`，与「不依赖 DTK、跨平台」的目标冲突。
- **强制 `QQuickStyle::setStyle("Basic")`**：能修好弹窗，但会把整个应用的控件外观一起换掉，代价太大。

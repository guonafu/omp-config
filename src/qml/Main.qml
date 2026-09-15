import QtQuick
import QtQml.Models
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1020
    height: 660
    visible: true
    title: "omp 配置工具（原型）"

    property int currentPage: 0

    // 模型卡片是硬编码浅色底(#fafbfb), 而控件默认取系统主题调色板(本机深色主题 → 白字白底
    // 不可见)。落在卡片上的输入控件统一显式给浅色值, 深浅主题下都保持可读。
    readonly property color cardInputBase: "#ffffff"
    readonly property color cardInputText: "#1a1a1a"

    // ---- 模型配置页状态 ----
    property string formProviderBaseUrl: ""
    property string formProviderApiKey: ""
    property string formProviderApi: "openai-completions"
    property string currentProviderName: ""
    property bool showKey: false
    property var cfg: ({})
    property var cfgPending: ({})
    property var roleVals: ({})
    ListModel { id: candidatesModel }
    function loadCfg() { cfg = ompBackend.loadSettings() }
    function touch(p, v) { cfgPending[p] = v; cfg[p] = v }
    function saveCfg() { ompBackend.saveSettings(cfgPending); cfgPending = ({}) }
    function saveRoles() {
        var patch = {}
        for (var k in roleVals) patch["modelRoles." + k] = roleVals[k]
        ompBackend.saveSettings(patch)
    }

    function fillProviders() {
        providersModel.clear()
        var list = ompBackend.loadProviders()
        for (var i = 0; i < list.length; ++i)
            providersModel.append({
                name: list[i].name,
                baseUrl: list[i].baseUrl || "",
                api: list[i].api || "openai-completions",
                apiKey: list[i].apiKey || ""
            })
    }

    function selectProvider(i) {
        if (i < 0) return
        var p = providersModel.get(i)
        formProviderBaseUrl = p.baseUrl
        formProviderApiKey = p.apiKey
        formProviderApi = p.api
        currentProviderName = p.name
        apiCombo.currentIndex = Math.max(0, apiCombo.model.indexOf(p.api))
        // 候选 = 本 provider 最近一次「获取模型列表」的结果。必须放在重建 modelsModel 之前:
        // 清空 candidatesModel 会重置各模型卡里可编辑 ComboBox 的 editText(已配置 id 显示被抹掉),
        // 而 modelsModel 重建之后新建的卡片会在 Component.onCompleted 里自己回填 id。
        candidatesModel.clear()
        modelsModel.clear()
        var list = ompBackend.loadProviderModels(p.name)
        for (var k = 0; k < list.length; ++k) {
            modelsModel.append({
                id: list[k].id,
                name: list[k].name,
                reasoning: (list[k].reasoning === true),
                input: root.inputToStr(list[k].input),
                contextWindow: list[k].contextWindow || 0,
                maxTokens: list[k].maxTokens || 0,
                expanded: false
            })
        }
        statusText.text = "已选择 provider：" + p.name + "（" + list.length + " 个模型）"
    }

    function saveCurrent() {
        if (currentProviderName === "") return
        var list = []
        for (var i = 0; i < modelsModel.count; ++i) {
            var mm = modelsModel.get(i)
            list.push({
                id: mm.id, name: mm.name, reasoning: mm.reasoning,
                input: (mm.input && mm.input.length ? String(mm.input).split(",") : []),
                contextWindow: mm.contextWindow, maxTokens: mm.maxTokens
            })
        }
        ompBackend.saveProvider(currentProviderName, formProviderBaseUrl,
                                formProviderApiKey, formProviderApi, "apiKey", list)
    }

    function beginFetch() {
        statusText.text = "正在获取模型…"
        ompBackend.fetchModels(formProviderBaseUrl, formProviderApiKey, formProviderApi)
    }

    function getReasoning(i) { return i >= 0 && modelsModel.get(i).reasoning === true }
    function addModelCard() {
        modelsModel.append({
            id: "", name: "", reasoning: false, input: "text",
            contextWindow: 1000000, maxTokens: 384000, expanded: true
        })
    }
    function toggleModel(i) {
        if (i < 0) return
        var m = modelsModel.get(i)
        m.expanded = !m.expanded
        modelsModel.set(i, m)
    }
    // 候选列表(candidatesModel)一变, Qt 会清空所有可编辑 ComboBox 的 editText,
    // 下面已配置模型的 id 显示会被抹掉。刷新候选后递增该令牌, 由各卡片自己回填 id。
    property int candidatesVersion: 0
    function updateModel(i, patch) {
        if (i < 0) return
        var m = modelsModel.get(i)
        for (var k in patch) m[k] = patch[k]
        modelsModel.set(i, m)
    }
    // 选中候选后回写该卡片的 model id: 名字为空的一并补上。
    function applyModelId(i, text) {
        var m = modelsModel.get(i)
        if (!m) return
        updateModel(i, { id: text, name: (m.name === "" ? text : m.name) })
    }
    function inputToStr(v) {
        if (v == null) return ""
        if (typeof v === "string") return v
        var out = []
        var s = JSON.stringify(v)
        if (s) { var p = JSON.parse(s); if (Array.isArray(p)) out = p }
        return out.join(",")
    }
    function hasInput(i, which) {
        if (i < 0 || which == null) return false
        var t = modelsModel.get(i).input || ""
        return ("," + t + ",").indexOf("," + which + ",") >= 0
    }
    function toggleInput(i, which, on) {
        if (i < 0) return
        var m = modelsModel.get(i)
        var arr = (m.input || "").length ? String(m.input).split(",") : []
        var ix = arr.indexOf(which)
        if (on && ix < 0) arr.push(which)
        else if (!on && ix >= 0) arr.splice(ix, 1)
        m.input = arr.join(",")
        modelsModel.set(i, m)
    }

    // 全项目的 ComboBox 都用它。
    // 原生弹窗面板是 DTK 的 FloatingPanel → D.InWindowBlur(毛玻璃), 本机 blur 不生效, 面板近乎
    // 全透明, 背后文字直接透上来; 它自带的 delegate(MenuItem) 配色又取自 DTK 主题色, 与本 app
    // 硬编码的浅色面(卡片 #fafbfb)各走一套, 深色主题下会出现看不见的组合。
    // 这里统一换成自绘弹窗: 不透明浅色面板 + 自绘行(配色跟卡片一致) + 直接吃 ComboBox.model。
    // 不走 ComboBox.delegateModel —— 实测(Qt 6.8 + DTK 样式)走它时弹窗里只会渲染出一项;
    // 鼠标点选经 itemChosen 通知外部, 键盘 Up/Down/Enter 仍由 ComboBox 自己处理(Enter 会发
    // activated)。selection 后 currentIndex/currentText/editText 仍由 ComboBox 更新。
    component AppComboBox: ComboBox {
        id: comboBox
        readonly property int rowHeight: 32
        signal itemChosen(int index)
        popup: Popup {
            y: comboBox.height
            width: comboBox.width
            // 高度由条数 × 行高直接算(最多 10 行): 不能依赖 contentItem.implicitHeight,
            // 那样弹窗先以 2px 打开, 内层 ListView 首轮视口为 0, 之后就不再补建 delegate。
            implicitHeight: Math.min(comboBox.count * comboBox.rowHeight + 2, 320)
            padding: 1
            contentItem: ListView {
                id: popupList
                clip: true
                implicitHeight: contentHeight
                model: comboBox.model
                currentIndex: -1
                delegate: Rectangle {
                    id: popupRow
                    required property int index
                    readonly property bool isOn: comboBox.highlightedIndex === index
                    width: ListView.view.width
                    height: comboBox.rowHeight
                    color: (hoverArea.containsMouse || popupRow.isOn) ? "#2c6fed" : root.cardInputBase
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: comboBox.textAt(index)
                        color: (hoverArea.containsMouse || popupRow.isOn) ? "#ffffff" : root.cardInputText
                    }
                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            comboBox.currentIndex = index
                            comboBox.popup.close()
                            comboBox.itemChosen(index)
                        }
                    }
                }
            }
            background: Rectangle {
                color: root.cardInputBase
                border.color: "#c0c4cc"
                border.width: 1
                radius: 4
            }
        }
    }

    // Token 限制数字框: 直接键入整数(0..10M), 回车/失焦提交。
    // 不用 SpinBox: 本机 Qt Quick Controls 解析到 org.deepin.dtk 样式, 其 SpinBox 的
    // contentItem 在 editable 时对外部 value 回写触发 text 绑定环, 非 editable 时内部
    // TextInput readOnly——两种情况都键不进去。TextField + IntValidator 是本页
    // baseUrl/apiKey/name 已验证可行的通路。
    component TokenField: TextField {
        Layout.preferredWidth: 120
        palette.base: root.cardInputBase
        palette.text: root.cardInputText
        validator: IntValidator { bottom: 0; top: 10000000 }
    }

    // ================= 侧边导航 =================
    Rectangle {
        id: sidebar
        width: 180
        color: palette.window
        border.color: "#ddd"
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Column {
            width: parent.width
            spacing: 2
            padding: 8

            Text {
                text: "omp 配置"
                font.bold: true
                font.pixelSize: 16
                padding: 8
            }
            Repeater {
                model: ["模型配置", "角色绑定", "主题与外观"]
                Rectangle {
                    required property int index
                    required property string modelData
                    width: parent.width
                    height: 36
                    radius: 6
                    color: index === root.currentPage ? "#2c6fed" : "transparent"
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: index === root.currentPage ? "white" : "#333"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.currentPage = index
                    }
                }
            }
        }
    }

    // ================= 内容区 =================
    StackLayout {
        id: pages
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        currentIndex: root.currentPage

        // ---------- 第0页：模型配置 ----------
        ColumnLayout {
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                height: 64
                color: "#fafafa"
                border.color: "#eee"
                Text {
                    text: "模型配置  /  Provider · Model 两级管理（写回 ~/.omp/agent/models.yml）"
                    font.pixelSize: 15
                    font.bold: true
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 12
                spacing: 12

                // ---- 左：Provider 列表 ----
                Rectangle {
                    Layout.preferredWidth: 320
                    Layout.fillHeight: true
                    color: palette.base
                    border.color: "#ddd"
                    radius: 6
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6
                        Text { text: "Providers"; font.bold: true }
                        ListView {
                            id: providerList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            highlightFollowsCurrentItem: true
                            highlight: Rectangle { color: "#e3ecff"; radius: 4 }
                            model: ListModel {
                                id: providersModel
                            }
                            delegate: Rectangle {
                                required property int index
                                required property string name
                                width: parent.width
                                height: 32
                                color: "transparent"
                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    verticalAlignment: Text.AlignVCenter
                                    text: name
                                    elide: Text.ElideMiddle
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: providerList.currentIndex = index
                                }
                            }
                            onCurrentIndexChanged: root.selectProvider(currentIndex)
                            Component.onCompleted: selectProvider(0)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Button { text: "＋ 新增 Provider"; Layout.fillWidth: true; onClicked: addProviderDialog.open() }
                            Button { text: "删除"; enabled: providersModel.count > 0; onClicked: confirmDeleteDialog.open() }
                        }
                    }
                }

                // ---- 右：Provider 详情 + models ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: palette.base
                    border.color: "#ddd"
                    radius: 6
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text { text: "Provider 详情（可改后再获取）"; font.bold: true }

                        GridLayout {
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 6
                            Text { text: "baseUrl" }
                            TextField {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 320
                                text: root.formProviderBaseUrl
                                onTextChanged: root.formProviderBaseUrl = text
                            }
                            Text { text: "apiKey" }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                TextField {
                                    Layout.fillWidth: true
                                    text: root.formProviderApiKey
                                    echoMode: root.showKey ? TextInput.Normal : TextInput.Password
                                    onTextChanged: root.formProviderApiKey = text
                                }
                                Text {
                                    text: "👁"
                                    font.pixelSize: 15
                                    Layout.preferredWidth: 22
                                    color: root.showKey ? "#2c6fed" : "#888"
                                    MouseArea { anchors.fill: parent; onClicked: root.showKey = !root.showKey }
                                }
                            }
                            Text { text: "api" }
                            AppComboBox {
                                id: apiCombo
                                Layout.fillWidth: true
                                model: ["openai-completions","openai-responses","openai-codex-responses",
                                        "azure-openai-responses","anthropic-messages","google-generative-ai",
                                        "google-gemini-cli","google-vertex","bedrock-converse-stream"]
                                currentIndex: 0
                                onCurrentTextChanged: root.formProviderApi = currentText
                            }
                        }

                        RowLayout {
                            spacing: 8
                            Text { id: statusText; color: "#666"; text: ""; elide: Text.ElideRight; Layout.fillWidth: true }
                        }

                        // ---- models 列表 ----
                        // 标签单独一行: 3 个按钮已占满整行, 标签挤在同一行会被压成省略号
                        Text { text: "models（本 provider）"; font.bold: true }
                        RowLayout {
                            spacing: 8
                            Button { text: "保存"; onClicked: root.saveCurrent() }
                            Button { text: "获取模型列表"; onClicked: root.beginFetch() }
                            Button { text: "＋ 添加模型"; onClicked: root.addModelCard() }
                        }
                        ListView {
                            id: modelsList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8
                            topMargin: 8
                            bottomMargin: 8
                            clip: true
                            model: ListModel { id: modelsModel }
                            delegate: Rectangle {
                                id: modelCard
                                required property int index
                                required property string id
                                required property string name
                                required property bool expanded
                                required property int contextWindow
                                required property int maxTokens
                                width: parent.width
                                height: expanded ? 190 : 52
                                radius: 6
                                border.color: "#e0e0e0"
                                color: "#fafbfb"
                                // 模型 id 的显示值来自 modelsModel 数据(唯一真源); 编辑框只是编辑入口。
                                // 可编辑 ComboBox 的 model 一变(append/clear), Qt 就把 editText 清空,
                                // 故响应 root.candidatesVersion 变化, 按数据回填。
                                function applyModelId() { idCombo.editText = id }
                                Connections {
                                    target: root
                                    function onCandidatesVersionChanged() { applyModelId() }
                                }
                                ColumnLayout {
                                    id: cardCol
                                    width: parent.width
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 8
                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            id: chevronText
                                            text: expanded ? "▼" : "▶"
                                            font.pixelSize: 10
                                            color: "#555"
                                            Layout.preferredWidth: 14
                                            MouseArea { anchors.fill: parent; onClicked: root.toggleModel(index) }
                                        }
                                        AppComboBox {
                                            id: idCombo
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            height: 32
                                            editable: true
                                            currentIndex: -1
                                            textRole: "id"
                                            model: candidatesModel
                                            palette.base: root.cardInputBase
                                            palette.text: root.cardInputText
                                            Component.onCompleted: applyModelId()
                                            // 鼠标点选走 itemChosen; 键盘 Enter 由 ComboBox 发 activated。
                                            onItemChosen: root.applyModelId(modelCard.index, currentText)
                                            onActivated: root.applyModelId(modelCard.index, currentText)
                                            onAccepted: root.updateModel(modelCard.index, { id: editText })
                                        }
                                        TextField {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            height: 32
                                            placeholderText: "显示名称"
                                            text: name
                                            palette.base: root.cardInputBase
                                            palette.text: root.cardInputText
                                            onEditingFinished: root.updateModel(index, { name: text })
                                        }
                                        Text {
                                            text: "✕"
                                            color: "#888"
                                            font.pixelSize: 13
                                            Layout.preferredWidth: 16
                                            MouseArea { anchors.fill: parent; onClicked: modelsModel.remove(index) }
                                        }
                                        Item { Layout.preferredWidth: 8 }
                                    }
                                    ColumnLayout {
                                        visible: expanded
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Text { text: "Token 限制"; font.bold: true }
                                        RowLayout {
                                            spacing: 8
                                            Text { text: "上下文" }
                                            TokenField {
                                                text: String(contextWindow)
                                                onEditingFinished: root.updateModel(index, { contextWindow: parseInt(text, 10) || 0 })
                                            }
                                            Text { text: "输出" }
                                            TokenField {
                                                text: String(maxTokens)
                                                onEditingFinished: root.updateModel(index, { maxTokens: parseInt(text, 10) || 0 })
                                            }
                                        }
                                        RowLayout {
                                            spacing: 8
                                            Text { text: "reasoning" }
                                            Switch { checked: root.getReasoning(index); onToggled: root.updateModel(index, { reasoning: checked }) }
                                        }
                                        RowLayout {
                                            spacing: 8
                                            Text { text: "input" }
                                            CheckBox { text: "text";  checked: root.hasInput(index, "text");  onToggled: root.toggleInput(index, "text", checked) }
                                            CheckBox { text: "image"; checked: root.hasInput(index, "image"); onToggled: root.toggleInput(index, "image", checked) }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: "#e2e2e2" }
                    }
                }
            }
        }

        // ---------- 第1页：角色绑定 ----------
        Page {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                Text { text: "角色绑定  /  将模型绑定到各工作角色（modelRoles）"; font.pixelSize: 15; font.bold: true }

                RowLayout {
                    Layout.fillWidth: true
                    Button { text: "保存角色绑定 → config.yml"; onClicked: root.saveRoles() }
                    Text { id: rolesStatus; color: "#666"; text: ""; elide: Text.ElideRight; Layout.fillWidth: true }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: ListModel {
                        ListElement { role: "smol";    modelRef: "uniontech-ai/deepseek-v4-flash-0731:auto" }
                        ListElement { role: "plan";    modelRef: "uniontech-ai/deepseek-v4-flash-0731" }
                        ListElement { role: "task";    modelRef: "uniontech-ai-ch/deepseek-v4-flash-0731" }
                        ListElement { role: "slow";    modelRef: "uniontech-ai/deepseek-v4-flash-0731:auto" }
                        ListElement { role: "default"; modelRef: "uniontech-ai/deepseek-v4-flash-0731:low" }
                        ListElement { role: "vision";  modelRef: "uniontech-ai/glm-5.3-flash:auto" }
                        ListElement { role: "commit";  modelRef: "uniontech-ai-ch/deepseek-v4-flash:high" }
                        ListElement { role: "tiny";    modelRef: "uniontech-ai-ch/deepseek-v4-flash-0731" }
                        ListElement { role: "advisor"; modelRef: "uniontech-ai-ch/deepseek-v4-flash-0731:high" }
                    }
                    delegate: Rectangle {
                        required property string role
                        required property string modelRef
                        width: parent.width
                        height: 48
                        radius: 6
                        color: "#f5f6f8"
                        border.color: "#e2e2e2"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12
                            Text { text: role; font.bold: true; width: 90 }
                            Text { text: "绑定"; color: "#888" }
                            AppComboBox {
                                Layout.fillWidth: true
                                editable: true
                                editText: root.cfg["modelRoles." + role] || ""
                                onCurrentTextChanged: root.roleVals[role] = currentText
                                model: ["uniontech-ai/deepseek-v4-flash-0731:auto",
                                        "uniontech-ai/deepseek-v4-pro-0813",
                                        "uniontech-ai-ch/deepseek-v4-flash-0731",
                                        "uniontech-ai/glm-5.2",
                                        "uniontech-ai/glm-5.3-flash"]
                            }
                        }
                    }
                }
            }
        }

        // ---------- 第2页：主题与外观 ----------
        Page {
            Flickable {
                anchors.fill: parent
                contentHeight: appearanceColumn.implicitHeight + 40
                clip: true
                ScrollBar.vertical: ScrollBar { }

                ColumnLayout {
                    id: appearanceColumn
                    width: parent.width
                    Layout.margins: 16
                    spacing: 16

                    Text { text: "主题与外观  /  theme · statusLine · display"
                           font.pixelSize: 15; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Button { text: "保存外观 → config.yml"; onClicked: root.saveCfg() }
                        Text { id: cfgStatus; color: "#666"; text: ""; elide: Text.ElideRight; Layout.fillWidth: true }
                    }

                    GroupBox {
                        title: "主题（Theme）"
                        Layout.fillWidth: true
                        GridLayout {
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 8
                            Text { text: "深色主题 dark" }
                            AppComboBox {
                                Layout.minimumWidth: 220; editable: true
                                editText: root.cfg["theme.dark"] || ""
                                onCurrentTextChanged: root.touch("theme.dark", currentText)
                                model: ["titanium","anthracite","dark-github","dark-nord","dark-dracula"]
                            }
                            Text { text: "浅色主题 light" }
                            AppComboBox {
                                Layout.minimumWidth: 220; editable: true
                                editText: root.cfg["theme.light"] || ""
                                onCurrentTextChanged: root.touch("theme.light", currentText)
                                model: ["light","light-solarized","light-github"]
                            }
                            Text { text: "符号字形 symbolPreset" }
                            AppComboBox {
                                Layout.minimumWidth: 220; editable: true
                                editText: root.cfg["symbolPreset"] || ""
                                onCurrentTextChanged: root.touch("symbolPreset", currentText)
                                model: ["unicode","nerd","ascii"]
                            }
                            Text { text: "色盲模式 colorBlindMode" }
                            Switch {
                                checked: root.cfg["colorBlindMode"] === true
                                onToggled: root.touch("colorBlindMode", checked)
                            }
                        }
                    }

                    GroupBox {
                        title: "状态栏（Status Line）"
                        Layout.fillWidth: true
                        GridLayout {
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 8
                            Text { text: "预设 preset" }
                            AppComboBox {
                                Layout.minimumWidth: 220; editable: true
                                editText: root.cfg["statusLine.preset"] || ""
                                onCurrentTextChanged: root.touch("statusLine.preset", currentText)
                                model: ["default","minimal","compact","full","nerd","ascii","custom"]
                            }
                            Text { text: "分隔符 separator" }
                            AppComboBox {
                                Layout.minimumWidth: 220; editable: true
                                editText: root.cfg["statusLine.separator"] || ""
                                onCurrentTextChanged: root.touch("statusLine.separator", currentText)
                                model: ["powerline","powerline-thin","slash","pipe","block","none","ascii"]
                            }
                            Text { text: "会话强调色 sessionAccent" }
                            Switch {
                                checked: root.cfg["statusLine.sessionAccent"] === true
                                onToggled: root.touch("statusLine.sessionAccent", checked)
                            }
                            Text { text: "透明背景 transparent" }
                            Switch {
                                checked: root.cfg["statusLine.transparent"] === true
                                onToggled: root.touch("statusLine.transparent", checked)
                            }
                        }
                    }

                    GroupBox {
                        title: "显示（Display）"
                        Layout.fillWidth: true
                        GridLayout {
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 8
                            Text { text: "加载动画 shimmer" }
                            AppComboBox {
                                Layout.minimumWidth: 220; editable: true
                                editText: root.cfg["display.shimmer"] || ""
                                onCurrentTextChanged: root.touch("display.shimmer", currentText)
                                model: ["classic","kitt","disabled"]
                            }
                            Text { text: "显示 token 用量 showTokenUsage" }
                            Switch {
                                checked: root.cfg["display.showTokenUsage"] === true
                                onToggled: root.touch("display.showTokenUsage", checked)
                            }
                            Text { text: "缓存未命中标记 cacheMissMarker" }
                            Switch {
                                checked: root.cfg["display.cacheMissMarker"] === true
                                onToggled: root.touch("display.cacheMissMarker", checked)
                            }
                            Text { text: "平滑流式 smoothStreaming" }
                            Switch {
                                checked: root.cfg["display.smoothStreaming"] === true
                                onToggled: root.touch("display.smoothStreaming", checked)
                            }
                            Text { text: "隐藏工具调用 hideToolActivity" }
                            Switch {
                                checked: root.cfg["display.hideToolActivity"] === true
                                onToggled: root.touch("display.hideToolActivity", checked)
                            }
                            Text { text: "压缩收起 collapseCompacted" }
                            Switch {
                                checked: root.cfg["display.collapseCompacted"] === true
                                onToggled: root.touch("display.collapseCompacted", checked)
                            }
                        }
                    }

                    GroupBox {
                        title: "思考显示（Thinking）"
                        Layout.fillWidth: true
                        GridLayout {
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 8
                            Text { text: "默认思考级别 defaultThinkingLevel" }
                            AppComboBox {
                                Layout.minimumWidth: 220; editable: true
                                editText: root.cfg["defaultThinkingLevel"] || ""
                                onCurrentTextChanged: root.touch("defaultThinkingLevel", currentText)
                                model: ["minimal","low","medium","high","xhigh","max","auto"]
                            }
                            Text { text: "隐藏思考块 hideThinkingBlock" }
                            Switch {
                                checked: root.cfg["hideThinkingBlock"] === true
                                onToggled: root.touch("hideThinkingBlock", checked)
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= 后端信号 =================
    Connections {
        target: ompBackend
        function onModelsFetched(ids) {
            candidatesModel.clear()
            for (var i = 0; i < ids.length; ++i)
                candidatesModel.append({ id: ids[i] })
            // 重建候选列表会把每个模型卡里可编辑 ComboBox 的 editText 清空, 通知卡片回填 id
            ++candidatesVersion
            statusText.text = "获取到 " + ids.length + " 个模型，下拉可选"
        }
        function onFetchFailed(reason) {
            statusText.text = "获取失败：" + reason
        }
        function onSaved(ok, message) {
            statusText.text = ok ? "✓ " + message : "✗ 保存失败：" + message
        }
        function onSettingsSaved(ok, message) {
            var m = ok ? "✓ " + message : "✗ " + message
            if (cfgStatus) cfgStatus.text = m
            if (rolesStatus) rolesStatus.text = m
        }
    }

    Dialog {
        id: addProviderDialog
        title: "新增 Provider"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 360
        contentItem: ColumnLayout {
            spacing: 8
            Text { text: "名称（唯一 key，将作为 models.yml 的 provider 键）" }
            TextField { id: newProviderName; placeholderText: "例如：my-provider" }
        }
        onAccepted: {
            var nm = newProviderName.text.trim()
            if (!nm) return
            var dup = false
            for (var i = 0; i < providersModel.count; ++i)
                if (providersModel.get(i).name === nm) { dup = true; break }
            if (dup) { statusText.text = "provider 已存在：" + nm; return }
            providersModel.append({ name: nm, baseUrl: "", apiKey: "", api: "openai-completions" })
            providerList.currentIndex = providersModel.count - 1
            newProviderName.text = ""
            statusText.text = "新增 provider：" + nm + "，请在右侧填 baseUrl/apiKey 后保存"
        }
    }

    Dialog {
        id: confirmDeleteDialog
        title: "删除 Provider"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 380
        contentItem: ColumnLayout {
            spacing: 8
            Text { text: "确定删除 provider：" + root.currentProviderName + " ？（连同其所有 models）" }
            Text { text: "会写入 ~/.omp/agent/models.yml"; color: "#999"; font.pixelSize: 12 }
        }
        onAccepted: {
            if (!root.currentProviderName) return
            ompBackend.removeProvider(root.currentProviderName)
            for (var i = 0; i < providersModel.count; ++i)
                if (providersModel.get(i).name === root.currentProviderName) { providersModel.remove(i); break }
            if (providersModel.count > 0) { providerList.currentIndex = 0; selectProvider(0) }
            else root.currentProviderName = ""
        }
    }

    Component.onCompleted: {
        loadCfg()
        fillProviders()
        if (providersModel.count > 0) {
            providerList.currentIndex = 0
        } else {
            statusText.text = "~/.omp/agent/models.yml 暂无 provider"
        }
    }
}
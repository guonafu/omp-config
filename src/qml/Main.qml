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

    // ---- 模型配置页状态 ----
    property string formProviderBaseUrl: ""
    property string formProviderApiKey: ""
    property string formProviderApi: "openai-completions"
    property string formId: ""
    property string formName: ""
    property bool   formReasoning: false
    property var    formInput: ["text"]
    property string formContext: "1000000"
    property string formMax: "384000"
    property string currentProviderName: ""
    property bool showKey: false

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
        modelsModel.clear()
        var list = ompBackend.loadProviderModels(p.name)
        for (var k = 0; k < list.length; ++k)
            modelsModel.append({
                id: list[k].id,
                name: list[k].name,
                reasoning: (list[k].reasoning === true),
                input: list[k].input || [],
                contextWindow: list[k].contextWindow || 0,
                maxTokens: list[k].maxTokens || 0
            })
        statusText.text = "已选择 provider：" + p.name + "（" + list.length + " 个模型）"
    }

    function saveCurrent() {
        if (currentProviderName === "") return
        var list = []
        for (var i = 0; i < modelsModel.count; ++i) {
            var mm = modelsModel.get(i)
            list.push({
                id: mm.id, name: mm.name, reasoning: mm.reasoning,
                input: mm.input, contextWindow: mm.contextWindow, maxTokens: mm.maxTokens
            })
        }
        ompBackend.saveProvider(currentProviderName, formProviderBaseUrl,
                                formProviderApiKey, formProviderApi, "apiKey", list)
    }

    function beginFetch() {
        statusText.text = "正在获取模型…"
        ompBackend.fetchModels(formProviderBaseUrl, formProviderApiKey, formProviderApi)
    }

    function addModel() {
        if (formId.trim() === "") return
        modelsModel.append({
            id: formId, name: formName, reasoning: formReasoning,
            input: formInput,
            contextWindow: parseInt(formContext) || 0,
            maxTokens: parseInt(formMax) || 0
        })
        formId = ""
        formName = ""
        formReasoning = false
        formInput = ["text"]
        formContext = "1000000"
        formMax = "384000"
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
                                required property string baseUrl
                                width: parent.width
                                height: 32
                                color: "transparent"
                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    verticalAlignment: Text.AlignVCenter
                                    text: name + "  ·  " + baseUrl
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
                    }
                }

                // ---- 右：Provider 详情 + 获取模型 + models ----
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
                                Button {
                                    text: root.showKey ? "隐藏" : "显示"
                                    onClicked: root.showKey = !root.showKey
                                }
                            }
                            Text { text: "api" }
                            ComboBox {
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
                            Button { text: "获取模型"; onClicked: root.beginFetch() }
                            Button { text: "保存到 models.yml"; onClicked: root.saveCurrent() }
                            Text { id: statusText; color: "#666"; text: ""; elide: Text.ElideRight; Layout.fillWidth: true }
                        }

                        // ---- models 列表 ----
                        Text { text: "models（本 provider）"; font.bold: true }
                        ListView {
                            id: modelsList
                            Layout.fillWidth: true
                            Layout.preferredHeight: 130
                            clip: true
                            model: ListModel { id: modelsModel }
                            delegate: RowLayout {
                                required property string name
                                required property string id
                                width: parent.width
                                spacing: 8
                                Text { text: "· " + name; Layout.fillWidth: true; elide: Text.ElideMiddle }
                                Text { text: "(" + id + ")"; color: "#888" }
                                Button {
                                    text: "删除"
                                    onClicked: modelsModel.remove(index)
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: "#e2e2e2" }

                        // ---- 添加/编辑模型表单 ----
                        GridLayout {
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 6
                            Text { text: "id（获取到的模型）" }
                            ComboBox {
                                id: modelIdCombo
                                Layout.fillWidth: true
                                editable: true
                                currentIndex: -1
                                textRole: "id"
                                model: ListModel { id: candidatesModel }
                                onActivated: {
                                    root.formId = currentText
                                    root.formName = currentText   // name 默认 = id
                                }
                            }
                            Text { text: "name（默认 = id）" }
                            TextField {
                                Layout.fillWidth: true
                                text: root.formName
                                onTextChanged: root.formName = text
                            }
                            Text { text: "reasoning" }
                            Switch { checked: root.formReasoning; onToggled: root.formReasoning = checked }
                            Text { text: "input" }
                            RowLayout {
                                spacing: 8
                                CheckBox {
                                    text: "text"
                                    checked: root.formInput.indexOf("text") >= 0
                                    onToggled: {
                                        var a = root.formInput.slice()
                                        var ix = a.indexOf("text")
                                        if (checked && ix < 0) a.push("text")
                                        else if (!checked && ix >= 0) a.splice(ix, 1)
                                        root.formInput = a
                                    }
                                }
                                CheckBox {
                                    text: "image"
                                    checked: root.formInput.indexOf("image") >= 0
                                    onToggled: {
                                        var a = root.formInput.slice()
                                        var ix = a.indexOf("image")
                                        if (checked && ix < 0) a.push("image")
                                        else if (!checked && ix >= 0) a.splice(ix, 1)
                                        root.formInput = a
                                    }
                                }
                            }
                            Text { text: "contextWindow" }
                            TextField {
                                Layout.fillWidth: true
                                text: root.formContext
                                validator: IntValidator { bottom: 0 }
                                onTextChanged: root.formContext = text
                            }
                            Text { text: "maxTokens" }
                            TextField {
                                Layout.fillWidth: true
                                text: root.formMax
                                validator: IntValidator { bottom: 0 }
                                onTextChanged: root.formMax = text
                            }
                        }
                        Button { text: "＋ 添加到 models"; onClicked: root.addModel() }
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
                            ComboBox {
                                Layout.fillWidth: true
                                editable: true
                                currentIndex: 0
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

                    GroupBox {
                        title: "主题（Theme）"
                        Layout.fillWidth: true
                        GridLayout {
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 8
                            Text { text: "深色主题 dark" }
                            ComboBox { Layout.minimumWidth: 220; model: ["titanium","anthracite","dark-github","dark-nord","dark-dracula"] }
                            Text { text: "浅色主题 light" }
                            ComboBox { Layout.minimumWidth: 220; model: ["light","light-solarized","light-github"] }
                            Text { text: "符号字形 symbolPreset" }
                            ComboBox { Layout.minimumWidth: 220; model: ["unicode","nerd","ascii"] }
                            Text { text: "色盲模式 colorBlindMode" }
                            Switch { checked: false }
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
                            ComboBox { Layout.minimumWidth: 220; model: ["default","minimal","compact","full","nerd","ascii","custom"] }
                            Text { text: "分隔符 separator" }
                            ComboBox { Layout.minimumWidth: 220; model: ["powerline","powerline-thin","slash","pipe","block","none","ascii"] }
                            Text { text: "会话强调色 sessionAccent" }
                            Switch { checked: true }
                            Text { text: "透明背景 transparent" }
                            Switch { checked: false }
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
                            ComboBox { Layout.minimumWidth: 220; model: ["classic","kitt","disabled"] }
                            Text { text: "显示 token 用量 showTokenUsage" }
                            Switch { checked: false }
                            Text { text: "缓存未命中标记 cacheMissMarker" }
                            Switch { checked: false }
                            Text { text: "平滑流式 smoothStreaming" }
                            Switch { checked: true }
                            Text { text: "隐藏工具调用 hideToolActivity" }
                            Switch { checked: false }
                            Text { text: "压缩收起 collapseCompacted" }
                            Switch { checked: true }
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
                            ComboBox { Layout.minimumWidth: 220; model: ["minimal","low","medium","high","xhigh","max","auto"] }
                            Text { text: "隐藏思考块 hideThinkingBlock" }
                            Switch { checked: false }
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
            statusText.text = "获取到 " + ids.length + " 个模型，下拉可选"
            modelIdCombo.currentIndex = -1
        }
        function onFetchFailed(reason) {
            statusText.text = "获取失败：" + reason
        }
        function onSaved(ok, message) {
            statusText.text = ok ? "✓ " + message : "✗ 保存失败：" + message
        }
    }

    Component.onCompleted: {
        fillProviders()
        if (providersModel.count > 0) {
            providerList.currentIndex = 0
            selectProvider(0)
        } else {
            statusText.text = "~/.omp/agent/models.yml 暂无 provider"
        }
    }
}
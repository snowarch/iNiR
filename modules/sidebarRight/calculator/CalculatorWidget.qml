pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

FocusScope {
    id: root
    focus: true
    property bool compactMode: false
    property bool centerContentVertically: false
    property bool expandedInPanel: true
    readonly property int contentMargin: 10
    readonly property int sectionSpacing: 6
    readonly property int buttonSpacing: 6
    readonly property int availableContentWidth: Math.max(0, width - (contentMargin * 2))
    readonly property int maxDisplayHeight: compactMode ? 72 : 64
    readonly property int displayHeight: Math.max(56, Math.min(maxDisplayHeight, Math.round(width * 0.2)))
    readonly property int toolButtonHeight: 28
    readonly property int maxButtonHeight: compactMode ? 48 : 40
    readonly property int compactButtonHeight: {
        const widthBound = Math.floor((Math.max(0, availableContentWidth) - (buttonSpacing * 3)) / 4)
        const fallback = widthBound > 0 ? widthBound : maxButtonHeight
        return Math.max(36, Math.min(maxButtonHeight, fallback))
    }
    readonly property int memoryButtonHeight: Math.max(32, Math.min(40, compactButtonHeight - 8))
    readonly property int scientificButtonHeight: compactButtonHeight
    readonly property int keypadHeight: (compactButtonHeight * 5) + (buttonSpacing * 4)
    readonly property int scientificHeight: scientificMode ? scientificButtonHeight * 2 + buttonSpacing : 0
    readonly property int totalContentHeight: headerRow.implicitHeight
        + modeRow.implicitHeight
        + displayHeight
        + (showHistory ? 132 : 0)
        + scientificHeight
        + memoryButtonHeight
        + keypadHeight
        + (sectionSpacing * (showHistory ? 6 : 5))
    readonly property int naturalImplicitHeight: (contentColumn?.implicitHeight ?? totalContentHeight) + (contentMargin * 2)
    readonly property int inactivePanelImplicitHeight: 300
    readonly property int activePanelImplicitHeight: 380
    implicitHeight: compactMode
        ? naturalImplicitHeight
        : Math.min(expandedInPanel ? activePanelImplicitHeight : inactivePanelImplicitHeight, naturalImplicitHeight)

    function ensureTypingFocus() {
        if (visible) Qt.callLater(() => root.forceActiveFocus())
    }

    Component.onCompleted: ensureTypingFocus()
    onVisibleChanged: {
        if (visible) ensureTypingFocus()
    }
    onFocusChanged: (focus) => {
        if (focus) ensureTypingFocus()
    }

    // Calculator state
    property string displayValue: "0"
    property string expression: ""
    property bool newNumber: true
    property string lastOp: ""
    
    // Memory
    property real memory: 0
    property bool hasMemory: false
    
    // History
    property var history: []
    property int maxHistory: 10
    property bool showHistory: false
    
    // Scientific mode
    property bool scientificMode: false

    // Style tokens
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colBg: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer0
    readonly property color colLayer1: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer1
    readonly property color colLayer2: Appearance.angelEverywhere ? Appearance.angel.colGlassElevated
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer2
    readonly property color colOperator: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.colors.colPrimary
    readonly property color colOperatorContainer: Appearance.angelEverywhere ? Appearance.colors.colPrimaryContainer
        : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
        : Appearance.colors.colPrimaryContainer
    readonly property color colOnOperator: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
        : Appearance.colors.colOnPrimary
    readonly property color colBorder: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    readonly property int borderWidth: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
        : Appearance.inirEverywhere ? 1 : 0
    readonly property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property real radiusSmall: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    // Keyboard handling
    Keys.onPressed: (event) => {
        switch (event.key) {
            case Qt.Key_0: case Qt.Key_1: case Qt.Key_2: case Qt.Key_3: case Qt.Key_4:
            case Qt.Key_5: case Qt.Key_6: case Qt.Key_7: case Qt.Key_8: case Qt.Key_9:
                appendDigit(event.text); break
            case Qt.Key_Period: case Qt.Key_Comma: appendDigit("."); break
            case Qt.Key_Plus: appendOperator("+"); break
            case Qt.Key_Minus: appendOperator("-"); break
            case Qt.Key_Asterisk: appendOperator("*"); break
            case Qt.Key_Slash: appendOperator("/"); break
            case Qt.Key_Percent: percent(); break
            case Qt.Key_Enter: case Qt.Key_Return: case Qt.Key_Equal: calculate(); break
            case Qt.Key_Backspace: backspace(); break
            case Qt.Key_Escape: case Qt.Key_C: clear(); break
            case Qt.Key_H: showHistory = !showHistory; break
            case Qt.Key_S: scientificMode = !scientificMode; break
        }
        event.accepted = true
    }

    // Calculator logic
    function appendDigit(digit) {
        if (newNumber) {
            displayValue = digit === "." ? "0." : digit
            newNumber = false
        } else {
            if (digit === "." && displayValue.includes(".")) return
            if (displayValue === "0" && digit !== ".") displayValue = digit
            else displayValue += digit
        }
    }

    function appendOperator(op) {
        expression += displayValue + " " + op + " "
        newNumber = true
        lastOp = op
    }

    function calculate() {
        try {
            let finalExpr = expression + displayValue
            // Sanitize: only allow digits, operators, parentheses, decimal
            finalExpr = finalExpr.replace(/[^-()\d/*+.\s]/g, '')
            if (!finalExpr.trim()) return
            
            let result = eval(finalExpr)
            
            if (!isFinite(result)) {
                displayValue = "Error"
            } else {
                let resultStr = result.toString()
                if (resultStr.length > 14) resultStr = result.toPrecision(10)
                
                // Add to history
                addToHistory(expression + displayValue, resultStr)
                
                displayValue = resultStr
            }
            expression = ""
            newNumber = true
        } catch (e) {
            displayValue = "Error"
            expression = ""
            newNumber = true
        }
    }

    function clear() {
        displayValue = "0"
        expression = ""
        newNumber = true
    }

    function backspace() {
        if (displayValue.length > 1) {
            displayValue = displayValue.slice(0, -1)
        } else {
            displayValue = "0"
            newNumber = true
        }
    }

    function toggleSign() {
        if (displayValue !== "0" && displayValue !== "Error") {
            displayValue = displayValue.startsWith("-") ? displayValue.substring(1) : "-" + displayValue
        }
    }

    function percent() {
        displayValue = (parseFloat(displayValue) / 100).toString()
    }

    // Memory functions
    function memoryClear() { memory = 0; hasMemory = false }
    function memoryRecall() { if (hasMemory) { displayValue = memory.toString(); newNumber = true } }
    function memoryAdd() { memory += parseFloat(displayValue); hasMemory = true }
    function memorySubtract() { memory -= parseFloat(displayValue); hasMemory = true }

    // Scientific functions
    function sciSqrt() { displayValue = Math.sqrt(parseFloat(displayValue)).toString(); newNumber = true }
    function sciSquare() { displayValue = Math.pow(parseFloat(displayValue), 2).toString(); newNumber = true }
    function sciSin() { displayValue = Math.sin(parseFloat(displayValue) * Math.PI / 180).toString(); newNumber = true }
    function sciCos() { displayValue = Math.cos(parseFloat(displayValue) * Math.PI / 180).toString(); newNumber = true }
    function sciTan() { displayValue = Math.tan(parseFloat(displayValue) * Math.PI / 180).toString(); newNumber = true }
    function sciLog() { displayValue = Math.log10(parseFloat(displayValue)).toString(); newNumber = true }
    function sciLn() { displayValue = Math.log(parseFloat(displayValue)).toString(); newNumber = true }
    function sciPi() { displayValue = Math.PI.toString(); newNumber = true }

    // History
    function addToHistory(expr, result) {
        history.unshift({ expr: expr.trim(), result: result })
        if (history.length > maxHistory) history.pop()
        history = history // Trigger binding update
    }

    function clearHistory() { history = [] }

    function useHistoryItem(item) {
        displayValue = item.result
        newNumber = true
        showHistory = false
    }

    Flickable {
        id: calculatorFlickable
        anchors.fill: parent
        anchors.margins: root.contentMargin
        clip: true
        contentWidth: width
        contentHeight: contentFrame.height
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: contentFrame
            width: calculatorFlickable.width
            height: Math.max(contentColumn.implicitHeight, calculatorFlickable.height)

            ColumnLayout {
                id: contentColumn
                width: parent.width
                y: root.centerContentVertically
                    ? Math.max(0, Math.floor((parent.height - implicitHeight) / 2))
                    : 0
                spacing: root.sectionSpacing

                RowLayout {
                    id: headerRow
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: "calculate"
                        iconSize: 17
                        color: root.colTextSecondary
                    }

                    StyledText {
                        text: Translation.tr("Calculator")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: root.colText
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: Translation.tr("Keyboard")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: root.colTextSecondary
                        opacity: 0.75
                    }
                }

                RowLayout {
                    id: modeRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.toolButtonHeight
                    spacing: 4

                    RippleButton {
                        implicitWidth: root.toolButtonHeight
                        implicitHeight: root.toolButtonHeight
                        buttonRadius: root.radiusSmall
                        colBackground: showHistory ? root.colLayer2 : "transparent"
                        colBackgroundHover: root.colLayer2
                        onClicked: showHistory = !showHistory
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "history"; iconSize: 16; color: root.colText }
                        StyledToolTip { text: Translation.tr("History (H)") }
                    }

                    RippleButton {
                        implicitWidth: root.toolButtonHeight
                        implicitHeight: root.toolButtonHeight
                        buttonRadius: root.radiusSmall
                        colBackground: scientificMode ? root.colLayer2 : "transparent"
                        colBackgroundHover: root.colLayer2
                        onClicked: scientificMode = !scientificMode
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "function"; iconSize: 16; color: root.colText }
                        StyledToolTip { text: Translation.tr("Scientific (S)") }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        visible: hasMemory
                        implicitWidth: memLabel.implicitWidth + 8
                        implicitHeight: 20
                        radius: 4
                        color: Appearance.colors.colSecondaryContainer

                        StyledText {
                            id: memLabel
                            anchors.centerIn: parent
                            text: "M"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.displayHeight
                    color: root.colBg
                    radius: root.radius
                    border.width: root.borderWidth
                    border.color: root.colBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignRight
                            text: expression.replace(/\*/g, "×").replace(/\//g, "÷")
                            horizontalAlignment: Text.AlignRight
                            color: root.colTextSecondary
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            elide: Text.ElideLeft
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignRight
                            text: displayValue
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                            color: root.colText
                            font.pixelSize: 28
                            font.family: Appearance.font.family.numbers
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 14
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: showHistory ? 132 : 0
                    visible: showHistory
                    color: root.colBg
                    radius: root.radiusSmall
                    border.width: root.borderWidth
                    border.color: root.colBorder
                    clip: true

                    Behavior on Layout.preferredHeight {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                text: Translation.tr("History")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: root.colText
                            }
                            Item { Layout.fillWidth: true }
                            RippleButton {
                                implicitWidth: 20
                                implicitHeight: 20
                                buttonRadius: 10
                                colBackground: "transparent"
                                enabled: history.length > 0
                                opacity: enabled ? 1 : 0.5
                                onClicked: clearHistory()
                                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "delete"; iconSize: 14; color: root.colTextSecondary }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: history
                            clip: true
                            spacing: 2

                            delegate: RippleButton {
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                implicitHeight: 24
                                buttonRadius: 4
                                colBackground: "transparent"
                                colBackgroundHover: root.colLayer2
                                onClicked: useHistoryItem(modelData)

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.expr + " ="
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: root.colTextSecondary
                                        elide: Text.ElideLeft
                                    }
                                    StyledText {
                                        text: modelData.result
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.family: Appearance.font.family.numbers
                                        color: root.colText
                                    }
                                }
                            }

                            StyledText {
                                anchors.centerIn: parent
                                visible: history.length === 0
                                text: Translation.tr("No history")
                                color: root.colTextSecondary
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? root.scientificHeight : 0
                    visible: scientificMode
                    columns: 5
                    rowSpacing: root.buttonSpacing
                    columnSpacing: root.buttonSpacing

                    CalcButton { label: "√"; fixedHeight: root.scientificButtonHeight; onClicked: sciSqrt() }
                    CalcButton { label: "x²"; fixedHeight: root.scientificButtonHeight; onClicked: sciSquare() }
                    CalcButton { label: "sin"; fixedHeight: root.scientificButtonHeight; onClicked: sciSin() }
                    CalcButton { label: "cos"; fixedHeight: root.scientificButtonHeight; onClicked: sciCos() }
                    CalcButton { label: "tan"; fixedHeight: root.scientificButtonHeight; onClicked: sciTan() }
                    CalcButton { label: "log"; fixedHeight: root.scientificButtonHeight; onClicked: sciLog() }
                    CalcButton { label: "ln"; fixedHeight: root.scientificButtonHeight; onClicked: sciLn() }
                    CalcButton { label: "π"; fixedHeight: root.scientificButtonHeight; onClicked: sciPi() }
                    CalcButton { label: "("; fixedHeight: root.scientificButtonHeight; onClicked: { expression += "("; newNumber = true } }
                    CalcButton { label: ")"; fixedHeight: root.scientificButtonHeight; onClicked: { expression += ")"; newNumber = true } }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.memoryButtonHeight
                    spacing: root.buttonSpacing

                    CalcButton { label: "MC"; fixedHeight: root.memoryButtonHeight; secondary: true; onClicked: memoryClear(); Layout.fillWidth: true }
                    CalcButton { label: "MR"; fixedHeight: root.memoryButtonHeight; secondary: true; onClicked: memoryRecall(); Layout.fillWidth: true }
                    CalcButton { label: "M+"; fixedHeight: root.memoryButtonHeight; secondary: true; onClicked: memoryAdd(); Layout.fillWidth: true }
                    CalcButton { label: "M-"; fixedHeight: root.memoryButtonHeight; secondary: true; onClicked: memorySubtract(); Layout.fillWidth: true }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.keypadHeight
                    Layout.alignment: Qt.AlignTop
                    columns: 4
                    rowSpacing: root.buttonSpacing
                    columnSpacing: root.buttonSpacing

                    CalcButton { label: "C"; secondary: true; onClicked: clear() }
                    CalcButton { label: "+/-"; secondary: true; onClicked: toggleSign() }
                    CalcButton { label: "%"; secondary: true; onClicked: percent() }
                    CalcButton { label: "÷"; accent: true; accentSecondary: true; onClicked: appendOperator("/") }

                    CalcButton { label: "7"; onClicked: appendDigit("7") }
                    CalcButton { label: "8"; onClicked: appendDigit("8") }
                    CalcButton { label: "9"; onClicked: appendDigit("9") }
                    CalcButton { label: "×"; accent: true; accentSecondary: true; onClicked: appendOperator("*") }

                    CalcButton { label: "4"; onClicked: appendDigit("4") }
                    CalcButton { label: "5"; onClicked: appendDigit("5") }
                    CalcButton { label: "6"; onClicked: appendDigit("6") }
                    CalcButton { label: "-"; accent: true; accentSecondary: true; onClicked: appendOperator("-") }

                    CalcButton { label: "1"; onClicked: appendDigit("1") }
                    CalcButton { label: "2"; onClicked: appendDigit("2") }
                    CalcButton { label: "3"; onClicked: appendDigit("3") }
                    CalcButton { label: "+"; accent: true; accentSecondary: true; onClicked: appendOperator("+") }

                    CalcButton { label: "0"; Layout.columnSpan: 2; onClicked: appendDigit("0") }
                    CalcButton { label: "."; onClicked: appendDigit(".") }
                    CalcButton { label: "="; accent: true; onClicked: calculate() }
                }
            }
        }
    }

    component CalcButton: RippleButton {
        required property string label
        property bool accent: false
        property bool accentSecondary: false
        property bool secondary: false
        property int fixedHeight: root.compactButtonHeight

        Layout.fillWidth: true
        Layout.preferredHeight: fixedHeight
        Layout.minimumHeight: 36
        Layout.maximumHeight: 48

        buttonText: label
        buttonRadius: root.radiusSmall

        colBackground: accent
            ? (accentSecondary ? root.colOperatorContainer : root.colOperator)
            : secondary ? root.colLayer2 : root.colLayer1

        colBackgroundHover: accent
            ? (accentSecondary ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colPrimaryHover)
            : secondary
                ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : Appearance.colors.colLayer2Hover)
                : (Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover : Appearance.colors.colLayer1Hover)

        contentItem: StyledText {
            text: parent.buttonText
            font.pixelSize: Appearance.font.pixelSize.normal
            font.family: label.length === 1 && /[0-9.]/.test(label) ? Appearance.font.family.numbers : Appearance.font.family.main
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: parent.accent
                ? (parent.accentSecondary ? Appearance.colors.colOnPrimaryContainer : root.colOnOperator)
                : root.colText
        }
    }
}

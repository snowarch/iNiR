pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root
    implicitHeight: column.implicitHeight

    property var widgetOrder: {
        const saved = Config.options?.sidebar?.widgets?.widgetOrder
        if (!saved) return defaultOrder
        // Agregar widgets nuevos que no estén en el orden guardado
        const missing = defaultOrder.filter(id => !saved.includes(id))
        return [...saved, ...missing]
    }
    readonly property var defaultOrder: ["media", "week", "context", "note", "launch", "controls", "status", "crypto"]
    readonly property int widgetSpacing: Config.options?.sidebar?.widgets?.spacing ?? 8

    readonly property bool showMedia: Config.options?.sidebar?.widgets?.media ?? true
    readonly property bool showWeek: Config.options?.sidebar?.widgets?.week ?? true
    readonly property bool showContext: Config.options?.sidebar?.widgets?.context ?? true
    readonly property bool showNote: Config.options?.sidebar?.widgets?.note ?? true
    readonly property bool showLaunch: Config.options?.sidebar?.widgets?.launch ?? true
    readonly property bool showControls: Config.options?.sidebar?.widgets?.controls ?? true
    readonly property bool showStatus: Config.options?.sidebar?.widgets?.status ?? true
    readonly property bool showCrypto: Config.options?.sidebar?.widgets?.crypto ?? false

    readonly property var visibleWidgets: {
        const order = widgetOrder ?? defaultOrder
        return order.filter(id => {
            switch(id) {
                case "media": return showMedia
                case "week": return showWeek
                case "context": return showContext
                case "note": return showNote
                case "launch": return showLaunch
                case "controls": return showControls
                case "status": return showStatus
                case "crypto": return showCrypto
                default: return false
            }
        })
    }

    property int dragIndex: -1
    property int dropIndex: -1
    property bool editMode: false  // Ctrl+Click activa modo edición

    function moveWidget(fromIdx, toIdx) {
        if (fromIdx === toIdx || fromIdx < 0 || toIdx < 0) return
        const fromId = visibleWidgets[fromIdx]
        const toId = visibleWidgets[toIdx]
        
        let newOrder = [...(widgetOrder ?? defaultOrder)]
        const realFrom = newOrder.indexOf(fromId)
        const realTo = newOrder.indexOf(toId)
        
        newOrder.splice(realFrom, 1)
        newOrder.splice(realTo, 0, fromId)
        
        Config.setNestedValue("sidebar.widgets.widgetOrder", newOrder)
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: root.widgetSpacing

        Repeater {
            id: repeater
            model: root.visibleWidgets

            delegate: Item {
                id: widgetWrapper
                required property string modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0
                Layout.leftMargin: needsMargin ? 12 : 0
                Layout.rightMargin: needsMargin ? 12 : 0
                visible: Layout.preferredHeight > 0
                opacity: root.dragIndex === index ? 0.5 : 1

                readonly property bool needsMargin: modelData === "context" || modelData === "note" || modelData === "media" || modelData === "crypto"

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: 150 }
                }

                // Drop zone indicator - más visible con fondo semitransparente
                Rectangle {
                    id: dropIndicator
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: Appearance.rounding.small + 2
                    color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                    border.width: 2
                    border.color: Appearance.colors.colPrimary
                    opacity: (root.dropIndex === widgetWrapper.index && root.dragIndex !== widgetWrapper.index) ? 1 : 0
                    visible: opacity > 0
                    z: 50

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: 100 }
                    }

                    // Linea superior animada para indicar "insertar aquí"
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: -6
                        width: parent.width * 0.6
                        height: 4
                        radius: 2
                        color: Appearance.colors.colPrimary

                        SequentialAnimation on opacity {
                            running: dropIndicator.visible && Appearance.animationsEnabled
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.5; duration: 400 }
                            NumberAnimation { to: 1; duration: 400 }
                        }
                    }

                    // Icono de drop
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "move_item"
                        iconSize: 32
                        color: Appearance.colors.colPrimary
                        opacity: 0.7
                    }
                }

                Loader {
                    id: contentLoader
                    width: parent.width
                    sourceComponent: {
                        switch(widgetWrapper.modelData) {
                            case "media": return mediaWidget
                            case "week": return weekWidget
                            case "context": return contextWidget
                            case "note": return noteWidget
                            case "launch": return launchWidget
                            case "controls": return controlsWidget
                            case "status": return statusWidget
                            case "crypto": return cryptoWidget
                            default: return null
                        }
                    }
                }

                // Drag handle - Ctrl+Click para activar
                MouseArea {
                    id: dragHandle
                    anchors.fill: parent
                    hoverEnabled: false  // No capturar hover - dejar que pase a los widgets
                    acceptedButtons: Qt.LeftButton
                    propagateComposedEvents: true
                    // No bloquear wheel events
                    onWheel: (wheel) => { wheel.accepted = false }

                    property bool isDragging: false

                    onPressed: (mouse) => {
                        if (mouse.modifiers & Qt.ControlModifier) {
                            isDragging = true
                            root.dragIndex = widgetWrapper.index
                            root.editMode = true
                            mouse.accepted = true
                        } else {
                            mouse.accepted = false
                        }
                    }

                    onPositionChanged: (mouse) => {
                        if (!isDragging) return
                        const globalY = mapToItem(column, mouse.x, mouse.y).y
                        let accY = 0
                        for (let i = 0; i < repeater.count; i++) {
                            const item = repeater.itemAt(i)
                            if (!item?.visible) continue
                            if (globalY < accY + item.height / 2) {
                                root.dropIndex = i
                                return
                            }
                            accY += item.height + column.spacing
                        }
                        root.dropIndex = repeater.count - 1
                    }

                    onReleased: {
                        if (isDragging && root.dropIndex >= 0 && root.dropIndex !== root.dragIndex) {
                            root.moveWidget(root.dragIndex, root.dropIndex)
                        }
                        isDragging = false
                        root.dragIndex = -1
                        root.dropIndex = -1
                        root.editMode = false
                    }
                }

                // Icono de drag visible cuando se está arrastrando
                Rectangle {
                    id: dragIcon
                    anchors.centerIn: parent
                    width: 48
                    height: 48
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colPrimaryContainer
                    opacity: root.dragIndex === widgetWrapper.index ? 1 : 0
                    visible: opacity > 0
                    z: 100

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "drag_indicator"
                        iconSize: 28
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: 150 }
                    }
                    Behavior on scale {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                    }
                    scale: opacity > 0 ? 1 : 0.5
                }
            }
        }
    }

    Component { id: mediaWidget; MediaPlayerWidget {} }
    Component { id: weekWidget; WeekStrip {} }
    Component { id: contextWidget; ContextCard {} }
    Component { id: noteWidget; QuickNote {} }
    Component { id: launchWidget; QuickLaunch {} }
    Component { id: controlsWidget; ControlsCard {} }
    Component { id: statusWidget; StatusRings {} }
    Component { id: cryptoWidget; CryptoWidget {} }
}

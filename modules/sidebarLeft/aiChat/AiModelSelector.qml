import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Model picker for the AI chat. A pill shows the current model; clicking it
 * morphs open a searchable list of every available model (local + API),
 * grouped by provider. Selecting one calls Ai.setModel.
 *
 * Organic morphing: one popup surface grows from the pill (height + opacity
 * Behaviors), no component swap. Closed state is height 0 / opacity 0.
 */
Item {
    id: root
    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    property bool expanded: false
    property string filter: ""

    readonly property var currentModel: Ai.getModel()
    readonly property string currentName: currentModel?.name ?? Translation.tr("Select model")

    // Build a flat, filtered, provider-grouped list from Ai.models.
    readonly property var entries: {
        const out = [];
        const ids = Ai.modelList ?? [];
        const q = root.filter.trim().toLowerCase();
        for (const id of ids) {
            const m = Ai.models[id];
            if (!m) continue;
            const name = m.name ?? id;
            if (q.length > 0 && !(name.toLowerCase().includes(q) || id.toLowerCase().includes(q)))
                continue;
            out.push({
                "id": id,
                "name": name,
                "icon": m.icon ?? "neurology",
                "description": m.description ?? "",
                "requiresKey": !!m.requires_key,
                "isLocal": (m.endpoint ?? "").includes("127.0.0.1") || (m.endpoint ?? "").includes("localhost"),
            });
        }
        return out;
    }

    function close() {
        root.expanded = false;
        root.filter = "";
    }

    // ── The pill (always visible) ───────────────────────────────────────────
    RippleButton {
        id: pill
        anchors.left: parent.left
        anchors.top: parent.top
        implicitHeight: 30
        implicitWidth: pillRow.implicitWidth + 20
        buttonRadius: Appearance.rounding.full
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        onClicked: root.expanded = !root.expanded

        contentItem: RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6
            AiModelIcon {
                icon: root.currentModel?.icon ?? "spark-symbolic"
                size: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer2
            }
            StyledText {
                text: root.currentName
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer2
                elide: Text.ElideRight
                Layout.maximumWidth: 180
            }
            MaterialSymbol {
                text: root.expanded ? "expand_less" : "expand_more"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colSubtext
                rotation: 0
            }
        }
    }

    // ── The morphing popup (grows from the pill) ────────────────────────────
    Rectangle {
        id: popup
        anchors.top: pill.bottom
        anchors.left: pill.left
        anchors.topMargin: 6
        z: 100
        width: 300
        // Height morphs between 0 (closed) and content height (open).
        readonly property real openHeight: Math.min(popupContent.implicitHeight + 16, 420)
        height: root.expanded ? openHeight : 0
        clip: true
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        radius: Appearance.rounding.normal
        // Opaque popup surface across every global style. colLayer1 carries
        // content/aurora/angel transparency and would render see-through here, so
        // mirror StyledComboBox._popupColor: inir uses its own layer, everything
        // else (material, aurora, angel) uses the solid colLayer3Base.
        color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
            : Appearance.colors.colLayer3Base
        border.width: 1
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
            : Appearance.colors.colLayer0Border

        Behavior on height {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
            }
        }

        ColumnLayout {
            id: popupContent
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            // Search box
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2

                MaterialSymbol {
                    id: searchIcon
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    text: "search"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colSubtext
                }
                StyledTextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 30
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    text: root.filter
                    onTextChanged: root.filter = text
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length === 0
                        text: Translation.tr("Search models...")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            // Empty hint
            StyledText {
                Layout.fillWidth: true
                Layout.margins: 8
                visible: root.entries.length === 0
                text: Translation.tr("No models yet. Add one in Settings → Services.")
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            // Model list
            StyledListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: contentHeight
                visible: root.entries.length > 0
                clip: true
                model: root.entries
                spacing: 2

                delegate: RippleButton {
                    id: modelRow
                    required property var modelData
                    required property int index
                    width: listView.width
                    implicitHeight: rowLayout.implicitHeight + 12
                    buttonRadius: Appearance.rounding.small
                    readonly property bool isCurrent: modelData.id === Ai.currentModelId
                    colBackground: isCurrent ? Appearance.colors.colSecondaryContainer : "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover

                    onClicked: {
                        Ai.setModel(modelData.id);
                        root.close();
                    }

                    contentItem: RowLayout {
                        id: rowLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        AiModelIcon {
                            icon: modelData.icon
                            size: Appearance.font.pixelSize.larger
                            color: modelRow.isCurrent ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: modelRow.isCurrent ? Font.DemiBold : Font.Normal
                                color: modelRow.isCurrent ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: modelData.description.length > 0
                                text: modelData.description
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                        // Status chips: local badge or key state
                        MaterialSymbol {
                            visible: modelData.isLocal
                            text: "computer"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                        MaterialSymbol {
                            visible: !modelData.isLocal && modelData.requiresKey
                            text: "key"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                        MaterialSymbol {
                            visible: modelRow.isCurrent
                            text: "check"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }
            }
        }
    }

    // Click-away closes the popup.
    MouseArea {
        anchors.fill: parent
        enabled: root.expanded
        visible: enabled
        z: -1
        onClicked: root.close()
        propagateComposedEvents: true
    }
}

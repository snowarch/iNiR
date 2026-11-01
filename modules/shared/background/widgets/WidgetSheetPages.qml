pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// A widget's sheet of controls, for the family's edit desk to hold: its own controls, Settings' options for it, its
// look, and where it sits.
WidgetQuickControlsLayout {
    id: root

    required property var widget
    availableWidth: root.widget.quickControlsAvailableWidth - 24
    availableHeight: root.widget.quickControlsAvailableHeight - 24
    title: root.widget.displayName
    glyph: root.widget.identityGlyph
    tint: root.widget.identityTint
    regularWidth: Math.round(340 * root.d)
    onCloseRequested: root.widget.closeQuickControls()

    // Keys a page draws itself: the size above the rows, the design, the placement controls.
    readonly property var drawn: ["sizeClass", DesktopWidgetDesign.spec.key, "placementStrategy", "locked", "widgetScale", ...root.widget.ownControlKeys]
    readonly property var widgetRows: DesktopWidgetOptions.sheetRows(root.widget.configEntryName, "widget", root.drawn).filter(spec => spec.showIf())
    readonly property var lookRows: DesktopWidgetOptions.sheetRows(root.widget.configEntryName, "look", root.drawn).filter(spec => spec.showIf())
    readonly property var pages: [
        { value: "widget", label: Translation.tr("Widget"), visible: !root.widget.locked
            && (root.widget.sizeChoices.length > 1 || root.widget.ownControls !== null || root.widgetRows.length > 0) },
        { value: "look", label: Translation.tr("Look"), visible: !root.widget.locked && (root.widget.designChoices.length > 1
            || root.widget.semanticPaletteQuickControls || root.lookRows.length > 0) },
        { value: "arrange", label: Translation.tr("Arrange") }
    ]
    readonly property string page: {
        const open = root.pages.filter(entry => entry.visible !== false).map(entry => entry.value)
        return open.includes(root.widget._quickTab) ? root.widget._quickTab : open[0]
    }

    WidgetQuickTabs {
        visible: quickTabsPart.url.length === 0 && root.pages.filter(entry => entry.visible !== false).length > 1
        current: root.page
        model: root.pages
        onPicked: value => root.widget._quickTab = value
    }
    FamilyPart {
        id: quickTabsPart
        visible: when
        when: root.pages.filter(entry => entry.visible !== false).length > 1
        Layout.fillWidth: true
        part: "control.segmented"
        props: ({ options: root.pages.filter(entry => entry.visible !== false), current: root.page,
            accessibleName: Translation.tr("Quick controls") })
        Connections {
            target: quickTabsPart.item
            function onPicked(value: var): void { root.widget._quickTab = value }
        }
    }

    WidgetQuickSection {
        visible: root.page === "widget" && root.widget.sizeChoices.length > 1
        Layout.fillWidth: true
        title: Translation.tr("Size")
        detail: root.widget.sizeLabels[root.widget.sizeClass] ?? ""
        WidgetQuickChoices {
            maxColumns: 3
            current: root.widget.sizeClass
            model: root.widget.sizeChoices.map(size => ({ value: size, label: root.widget.sizeLabels[size] }))
            onPicked: value => root.widget.commitSize(value)
        }
    }
    Loader {
        active: root.widget.ownControls !== null && root.page === "widget"
        visible: active
        sourceComponent: root.widget.ownControls
        Layout.fillWidth: true
        Layout.preferredHeight: item?.implicitHeight ?? 0
    }
    // The widget's own rows, scrolled by the sheet when the screen has less room than the list.
    Loader {
        active: root.page === "widget"
        visible: active
        Layout.fillWidth: true
        sourceComponent: WidgetOptionList { specs: root.widgetRows }
    }

    ColumnLayout {
        visible: root.page === "look"
        Layout.fillWidth: true
        spacing: Math.round(14 * root.d)

        WidgetQuickSection {
            visible: root.widget.designChoices.length > 1
            title: Translation.tr("Design")
            detail: root.widget.widgetDesignShared ? Translation.tr("Same as every widget") : Translation.tr("This widget only")
            WidgetQuickChoices {
                current: root.widget.widgetDesign
                model: root.widget.designChoices
                onPicked: value => root.widget.pickDesign(value)
            }
            WidgetEditAction {
                visible: root.widget.widgetDesignMatchable
                Layout.fillWidth: true
                iconName: "select_all"
                label: Translation.tr("Use on every widget")
                onClicked: root.widget.useDesignEverywhere()
            }
        }

        WidgetQuickSection {
            visible: root.widget.semanticPaletteQuickControls
            title: Translation.tr("Colors")
            detail: root.widget.widgetPalettePresetLabel

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: root.widget.widgetPalettePresets

                    delegate: WidgetQuickChoice {
                        id: palettePresetButton
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.maximumWidth: Number.POSITIVE_INFINITY
                        label: modelData.label
                        selected: root.widget.widgetPalettePreset === modelData.value
                        sidePadding: Math.round(12 * root.d) + swatches.width + 6
                        onClicked: root.widget.applyWidgetPalettePreset(modelData.value)

                        Row {
                            id: swatches
                            anchors.left: parent.left
                            anchors.leftMargin: Math.round(10 * root.d)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: -3
                            Repeater {
                                model: palettePresetButton.modelData.roles
                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: root.widget.widgetSemanticColor(modelData)
                                    border.width: 1
                                    border.color: Qt.rgba(0, 0, 0, 0.25)
                                    z: 3 - index
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        active: root.page === "look"
        visible: active
        Layout.fillWidth: true
        sourceComponent: WidgetOptionList { specs: root.lookRows }
    }

    WidgetPlacementControls {
        visible: root.page === "arrange"
        Layout.fillWidth: true
        widget: root.widget
        wide: root.wideDense
    }
}

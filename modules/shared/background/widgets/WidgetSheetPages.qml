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
    title: {
        const words = root.widget.configEntryName.split(".").pop().replace(/([A-Z])/g, " $1").toLowerCase().trim()
        return Translation.tr(words.charAt(0).toUpperCase() + words.slice(1))
    }
    glyph: root.widget.identityGlyph
    tint: root.widget.identityTint
    regularWidth: Math.max(Math.round(340 * root.d),
        specificQuickLoader.item?.implicitWidth ?? 0)
    onCloseRequested: root.widget.closeQuickControls()

    readonly property var pages: [
        { value: "widget", label: Translation.tr("Widget"), visible: root.widget._widgetSpecificPopover !== null && !root.widget.locked },
        { value: "options", label: Translation.tr("Options"), visible: root.widget.hasOptionRows && !root.widget.locked },
        { value: "colors", label: Translation.tr("Look"), visible: (root.widget.semanticPaletteQuickControls
            || root.widget.hasFamilyFace) && !root.widget.locked },
        { value: "layout", label: Translation.tr("Arrange") }
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

    Loader {
        id: specificQuickLoader
        active: root.widget._widgetSpecificPopover !== null && root.page === "widget"
        visible: active
        sourceComponent: root.widget._widgetSpecificPopover
        Layout.fillWidth: true
        Layout.preferredHeight: item?.implicitHeight ?? 0
    }

    // Everything Settings has for this widget, scrolled when the screen has less room than the list.
    Flickable {
        visible: root.page === "options"
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, Math.max(Math.round(200 * root.d),
            root.availableHeight - Math.round(140 * root.d)))
        contentHeight: optionsLoader.item?.implicitHeight ?? 0
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Loader {
            id: optionsLoader
            width: parent.width
            active: root.page === "options"
            sourceComponent: WidgetOptionList {
                widget: root.widget.configEntryName
                exclude: ["sizeClass", DesktopWidgetDesign.spec.key, ...(DesktopWidgetOptions.familyOptions["*"] ?? []).map(option => option.key), "placementStrategy", "locked"]
            }
        }
    }

    ColumnLayout {
        visible: root.page === "colors"
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

    WidgetQuickSection {
        visible: root.page === "layout" && root.widget.sizeChoices.length > 1 && !root.widget.locked
        Layout.fillWidth: true
        title: Translation.tr("Size")
        detail: root.widget.sizeLabels[root.widget.sizeClass] ?? ""
        WidgetQuickChoices {
            maxColumns: 3
            current: root.widget.sizeClass
            model: ["small", "medium", "large"].filter(size => root.widget.sizeChoices.includes(size))
                .map(size => ({ value: size, label: root.widget.sizeLabels[size] }))
            onPicked: value => root.widget.commitSize(value)
        }
    }

    WidgetPlacementControls {
        visible: root.page === "layout"
        Layout.fillWidth: true
        widget: root.widget
        wide: root.wideDense
    }
}

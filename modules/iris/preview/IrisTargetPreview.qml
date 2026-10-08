pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.pieces

Item {
    id: root

    clip: true
    property string target: "material"
    property bool playing: true
    readonly property real d: IrisStyle.density
    readonly property real specimenHeight: specimen.height + Math.round(44 * root.d)
    readonly property string scene: ({ motion: "card", bodies: "card", pieces: "card", island: "island" })[root.target]
        ?? ({ transients: "feedback", dock: "dock", places: "place", desktop: "widget" })[root.target] ?? "specimen"

    IrisPreviewStage {
        anchors.fill: parent
        visible: root.scene !== "card" && root.scene !== "island"
    }

    IrisMotionLab {
        anchors.fill: parent
        visible: root.scene === "card" || root.scene === "island"
        mode: root.scene === "island" ? "island" : "card"
        playing: root.playing && visible
    }

    component Body: Rectangle {
        color: IrisStyle.bodySurface
        radius: IrisStyle.radiusSheet
        border.width: IrisStyle.rim.a > 0 ? 1 : 0
        border.color: IrisStyle.rim
        IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
        IrisLightWash {
            anchors.fill: parent
            radius: parent.radius
            light: IrisStyle.wallpaperLight
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Math.round(22 * root.d)
        visible: root.scene === "specimen"

        Body {
            id: specimen
            anchors.centerIn: parent
            width: Math.min(parent.width, Math.round(420 * root.d))
            height: specimenColumn.implicitHeight + Math.round(40 * root.d)
            scale: Math.min(1, parent.height / Math.max(1, specimen.height), parent.width / Math.max(1, specimen.width))
            layer.enabled: specimen.scale < 0.999
            layer.smooth: true
            layer.mipmap: true

            ColumnLayout {
                id: specimenColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Math.round(20 * root.d)
                spacing: Math.round(14 * root.d)

                RowLayout {
                    spacing: Math.round(10 * root.d)
                    Rectangle {
                        implicitWidth: Math.round(34 * root.d)
                        implicitHeight: implicitWidth
                        radius: IrisStyle.iconRadius(width)
                        color: IrisStyle.accent
                        MaterialSymbol { anchors.centerIn: parent; text: "palette"; fill: 1; iconSize: Math.round(19 * root.d); color: IrisStyle.inkOnAccent }
                    }
                    ColumnLayout {
                        spacing: 0
                        IrisText { text: Translation.tr("Studio"); font.family: IrisStyle.fontTitle; font.weight: Font.Bold; font.pixelSize: 19 * IrisStyle.typeScale }
                        IrisText { text: Translation.tr("How every surface looks"); color: IrisStyle.textSecondary; font.pixelSize: IrisStyle.typeMeta }
                    }
                    Item { Layout.fillWidth: true }
                    IrisNumber {
                        text: Translation.locale.toString(DateTime.clock.date, "hh:mm")
                        pixelSize: 30 * IrisStyle.typeScale
                        weight: IrisStyle.figureWeight
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: IrisStyle.hairline }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(6 * root.d)
                    Repeater {
                        model: [IrisStyle.fillQuiet, IrisStyle.fill, IrisStyle.fillHover, IrisStyle.fillActive, IrisStyle.fillStrong]
                        Rectangle {
                            required property color modelData
                            Layout.fillWidth: true
                            implicitHeight: Math.round(30 * root.d)
                            radius: IrisStyle.radiusRow
                            color: modelData
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(8 * root.d)
                    Rectangle {
                        implicitWidth: accentLabel.implicitWidth + Math.round(26 * root.d)
                        implicitHeight: Math.round(32 * root.d)
                        radius: height / 2
                        color: IrisStyle.accent
                        IrisText { id: accentLabel; anchors.centerIn: parent; text: Translation.tr("Accent"); color: IrisStyle.inkOnAccent; font.weight: Font.DemiBold }
                    }
                    Rectangle {
                        implicitWidth: highlightLabel.implicitWidth + Math.round(26 * root.d)
                        implicitHeight: Math.round(32 * root.d)
                        radius: height / 2
                        color: IrisStyle.tintFill(IrisStyle.secondaryAccent)
                        IrisText { id: highlightLabel; anchors.centerIn: parent; text: Translation.tr("Highlight"); color: IrisStyle.secondaryAccent; font.weight: Font.DemiBold }
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: Math.round(22 * root.d)
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: IrisStyle.badge
                        IrisText { anchors.centerIn: parent; text: "3"; color: IrisStyle.inkOnBadge; font.family: IrisStyle.fontNumbers; font.weight: Font.Bold; font.pixelSize: IrisStyle.typeMeta }
                    }
                }

                IrisCapsuleSlider {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(44 * root.d)
                    icon: "volume_up"
                    value: 0.64
                }

                IrisText {
                    Layout.fillWidth: true
                    text: Translation.tr("Text reads in the main face. Secondary lines step back, tertiary ones whisper.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: IrisStyle.typeLabel
                }
                IrisText {
                    Layout.fillWidth: true
                    text: Translation.tr("Secondary text")
                    color: IrisStyle.textSecondary
                }
                IrisText {
                    Layout.fillWidth: true
                    text: Translation.tr("Tertiary text")
                    color: IrisStyle.textTertiary
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Math.round(22 * root.d)
        visible: root.scene === "feedback"

        Body {
            id: banner
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.22
            width: Math.min(parent.width, Math.round(Number(Config.options?.iris?.notifications?.width ?? 380) * root.d))
            height: Math.round(74 * root.d)
            radius: IrisStyle.radiusPlate
            RowLayout {
                anchors.fill: parent
                anchors.margins: Math.round(14 * root.d)
                spacing: Math.round(12 * root.d)
                IrisMark { implicitSize: Math.round(38 * root.d) }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(2 * root.d)
                    IrisText { text: Translation.tr("A notification"); font.weight: Font.DemiBold }
                    IrisText { Layout.fillWidth: true; text: Translation.tr("Banners grow out of the Island and fold back into it."); color: IrisStyle.textSecondary; elide: Text.ElideRight }
                }
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: banner.bottom
            anchors.topMargin: Math.round(28 * root.d)
            width: Math.round(250 * root.d)
            height: Math.round(42 * root.d)
            radius: height / 2
            color: IrisStyle.bodySurface
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(14 * root.d)
                anchors.rightMargin: Math.round(14 * root.d)
                spacing: Math.round(10 * root.d)
                MaterialSymbol { text: "volume_up"; fill: 1; iconSize: Math.round(18 * root.d); color: IrisStyle.text }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(6 * root.d)
                    radius: height / 2
                    color: IrisStyle.fill
                    Rectangle { width: parent.width * 0.7; height: parent.height; radius: height / 2; color: IrisStyle.fillStrong }
                }
                IrisText { text: "70"; font.family: IrisStyle.fontNumbers; font.weight: Font.DemiBold }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.scene === "dock"
        readonly property real icon: Math.max(28, Math.min(64, Number(Config.options?.iris?.dock?.iconSize ?? 40))) * root.d
        Rectangle {
            id: dockPlate
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(28 * root.d)
            width: dockRow.implicitWidth + Math.round(20 * root.d)
            height: parent.icon + Math.round(18 * root.d)
            radius: Math.min(height / 2, IrisStyle.radiusPlate)
            color: IrisStyle.bodySurface
            Row {
                id: dockRow
                anchors.centerIn: parent
                spacing: Math.round(8 * root.d)
                Repeater {
                    model: (TaskbarApps.apps ?? []).slice(0, 6)
                    Item {
                        required property var modelData
                        width: dockPlate.parent.icon
                        height: width
                        SmartAppIcon { anchors.fill: parent; implicitSize: parent.width; icon: IrisPieces.appIcon(parent.modelData?.appId ?? "") }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Math.round(22 * root.d)
        visible: root.scene === "place" || root.scene === "widget"
        Body {
            anchors.centerIn: parent
            width: root.scene === "widget" ? Math.round(220 * root.d) : Math.min(parent.width, Math.round(Number(Config.options?.iris?.sidebars?.right?.width ?? 380) * root.d * 0.8))
            height: root.scene === "widget" ? Math.round(160 * root.d) : Math.min(parent.height, Math.round(420 * root.d))
            radius: root.scene === "widget" ? IrisStyle.radiusPlate : IrisStyle.surfaceRadius("panels", IrisStyle.radiusPanel)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Math.round(16 * root.d)
                spacing: Math.round(10 * root.d)
                IrisText { text: root.scene === "widget" ? Translation.tr("Widget") : Translation.tr("Today"); font.family: IrisStyle.fontTitle; font.weight: Font.Bold; font.pixelSize: 18 * IrisStyle.typeScale }
                Repeater {
                    model: root.scene === "widget" ? 1 : 3
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: IrisStyle.radiusCard
                        color: IrisStyle.surfaceHigh
                    }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "userCard"
    defaultConfig: ({
            placementStrategy: "free",
            contentWidth: 280,
            contentHeight: 176,
            widgetScale: 100,
            widgetOpacity: 100,
            colorMode: "auto",
            dim: 0,
            showBackground: true,
            showBorder: true,
            backgroundOpacity: 0.16,
            borderWidth: 1,
            borderOpacity: 0.2,
            cornerRadius: -1,
            useBlur: false,
            x: 80,
            y: 420
        })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 280) * scaleFactor)
    implicitHeight: Math.round(Math.max(170, Number(root._readConfigKey("contentHeight") ?? 176)) * scaleFactor)
    resizableAxes: ({
            width: "contentWidth",
            height: "contentHeight"
        })
    resizeMinWidth: 240
    resizeMinHeight: 170
    needsColText: true

    readonly property color surfaceInk: root.widgetInk
    readonly property string username: SystemInfo.displayName || SystemInfo.username
    readonly property string hostname: SystemInfo.hostname
    readonly property string userDisplay: root.hostname.length > 0 ? `${root.username}@${root.hostname}` : root.username

    readonly property var weatherLine: {
        const desc = (Weather.data?.description ?? "").toLowerCase();
        if (desc.includes("rain"))
            return {
                text: Translation.tr("Rain today"),
                icon: "rainy"
            };
        if (desc.includes("snow"))
            return {
                text: Translation.tr("Snow today"),
                icon: "ac_unit"
            };
        if (desc.includes("clear"))
            return {
                text: Translation.tr("Clear skies"),
                icon: "clear_day"
            };
        if (desc.includes("cloud"))
            return {
                text: Translation.tr("A bit cloudy"),
                icon: "cloud"
            };
        return {
            text: Weather.data?.description ?? "",
            icon: "thermostat"
        };
    }

    function lockScreen(): void {
        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "lock", "activate"]);
    }

    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.surfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent3
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: Math.round(14 * root.scaleFactor)
        spacing: Math.round(10 * root.scaleFactor)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(12 * root.scaleFactor)

            Item {
                id: avatarContainer
                readonly property int size: Math.round(48 * root.scaleFactor)
                Layout.preferredWidth: size
                Layout.preferredHeight: size
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: ColorUtils.applyAlpha(root.surfaceInk, 0.12)
                    visible: avatarImg.status !== Image.Ready

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "person"
                        iconSize: Math.round(avatarContainer.size * 0.55)
                        color: ColorUtils.applyAlpha(root.surfaceInk, 0.6)
                    }
                }

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: avatarResolver.resolvedSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                    sourceSize.width: 96
                    sourceSize.height: 96
                    visible: status === Image.Ready
                    layer.enabled: status === Image.Ready
                    layer.effect: GE.OpacityMask {
                        maskSource: avatarMask
                    }
                }

                QtObject {
                    id: avatarResolver
                    property int avatarIndex: 0
                    readonly property string resolvedSource: Directories.avatarSourceAt(avatarIndex)

                    readonly property string primaryWatch: Directories.userAvatarSourcePrimary
                    onPrimaryWatchChanged: avatarIndex = 0

                    readonly property int imgStatus: avatarImg.status
                    onImgStatusChanged: {
                        if (imgStatus === Image.Error) {
                            const nextIdx = avatarIndex + 1;
                            if (nextIdx < Directories.userAvatarPaths.length)
                                avatarIndex = nextIdx;
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(2 * root.scaleFactor)

                StyledText {
                    Layout.fillWidth: true
                    text: root.userDisplay
                    elide: Text.ElideRight
                    color: root.surfaceInk
                    font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                    font.weight: Font.DemiBold
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Up %1").arg(DateTime.uptime || "--")
                    elide: Text.ElideRight
                    color: ColorUtils.applyAlpha(root.surfaceInk, 0.6)
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignLeft
            Layout.maximumWidth: parent.width
            visible: root.weatherLine.text !== ""
                && root.height >= Math.round(170 * root.scaleFactor)
            implicitWidth: Math.min(parent.width,
                weatherChip.implicitWidth + Math.round(18 * root.scaleFactor))
            implicitHeight: weatherChip.implicitHeight + Math.round(9 * root.scaleFactor)
            radius: height / 2
            color: root.widgetSemanticContainer(root.widgetTertiaryRole)

            RowLayout {
                id: weatherChip
                anchors.fill: parent
                anchors.leftMargin: Math.round(9 * root.scaleFactor)
                anchors.rightMargin: Math.round(9 * root.scaleFactor)
                spacing: Math.round(6 * root.scaleFactor)

                MaterialSymbol {
                    text: root.weatherLine.icon
                    fill: 1
                    iconSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                    color: root.widgetSemanticOnContainer(root.widgetTertiaryRole)
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.weatherLine.text
                    elide: Text.ElideRight
                    color: root.widgetSemanticOnContainer(root.widgetTertiaryRole)
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    font.weight: Font.Medium
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(6 * root.scaleFactor)

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: Math.round(38 * root.scaleFactor)
                buttonRadius: height / 2
                colBackground: root.widgetSemanticContainer(root.widgetPrimaryRole)
                colBackgroundHover: ColorUtils.mix(root.widgetSemanticContainer(root.widgetPrimaryRole),
                    root.widgetSemanticOnContainer(root.widgetPrimaryRole), 0.90)
                colRipple: ColorUtils.mix(root.widgetSemanticContainer(root.widgetPrimaryRole),
                    root.widgetSemanticOnContainer(root.widgetPrimaryRole), 0.80)
                onClicked: root.lockScreen()
                contentItem: RowLayout {
                    spacing: Math.round(6 * root.scaleFactor)
                    Item {
                        Layout.fillWidth: true
                    }
                    MaterialSymbol {
                        text: "lock"
                        fill: 1
                        iconSize: Math.round(17 * root.scaleFactor)
                        color: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
                    }
                    StyledText {
                        text: Translation.tr("Lock")
                        color: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
                        font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                        font.weight: Font.Medium
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            RippleButton {
                implicitWidth: Math.round(38 * root.scaleFactor)
                implicitHeight: Math.round(38 * root.scaleFactor)
                buttonRadius: height / 2
                colBackground: root.widgetSemanticContainer(root.widgetSecondaryRole)
                colBackgroundHover: ColorUtils.mix(root.widgetSemanticContainer(root.widgetSecondaryRole),
                    root.widgetSemanticOnContainer(root.widgetSecondaryRole), 0.90)
                colRipple: ColorUtils.mix(root.widgetSemanticContainer(root.widgetSecondaryRole),
                    root.widgetSemanticOnContainer(root.widgetSecondaryRole), 0.80)
                onClicked: GlobalStates.settingsOverlayOpen = true
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "settings"
                    fill: 1
                    iconSize: Math.round(17 * root.scaleFactor)
                    color: root.widgetSemanticOnContainer(root.widgetSecondaryRole)
                }
                StyledToolTip {
                    text: Translation.tr("Settings")
                }
            }

            RippleButton {
                implicitWidth: Math.round(38 * root.scaleFactor)
                implicitHeight: Math.round(38 * root.scaleFactor)
                buttonRadius: height / 2
                colBackground: root.widgetSemanticContainer(root.widgetSignalRole)
                colBackgroundHover: ColorUtils.mix(root.widgetSemanticContainer(root.widgetSignalRole),
                    root.widgetSemanticOnContainer(root.widgetSignalRole), 0.90)
                colRipple: ColorUtils.mix(root.widgetSemanticContainer(root.widgetSignalRole),
                    root.widgetSemanticOnContainer(root.widgetSignalRole), 0.80)
                onClicked: GlobalStates.sessionOpen = true
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "power_settings_new"
                    fill: 1
                    iconSize: Math.round(17 * root.scaleFactor)
                    color: root.widgetSemanticOnContainer(root.widgetSignalRole)
                }
                StyledToolTip {
                    text: Translation.tr("Power")
                }
            }
        }
    }
}

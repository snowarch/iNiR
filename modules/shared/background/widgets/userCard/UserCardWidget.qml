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
import qs.modules.shared.background.widgets
import qs.modules.shared.background.widgets.instrument
AbstractBackgroundWidget {
    id: root

    configEntryName: "userCard"
    familyOptions: [
        { key: "showAvatar", raw: true, label: Translation.tr("Picture"), icon: "account_circle", fallback: true },
        { key: "showWeather", raw: true, label: Translation.tr("Weather"), icon: "partly_cloudy_day", fallback: true },
        { key: "showHostname", raw: true, label: Translation.tr("Computer name"), icon: "computer", fallback: true }
    ]
    resizeMinWidth: 240
    resizeMinHeight: 170
    needsColText: true
    readonly property string cardStyle: root._readConfigKey("style") ?? "card"
    readonly property bool instrument: root.cardStyle === "instrument"
    readonly property bool showAvatar: root._readConfigKey("showAvatar") ?? true
    readonly property bool showWeather: root._readConfigKey("showWeather") ?? true
    readonly property bool showHostname: root._readConfigKey("showHostname") ?? true

    readonly property color surfaceInk: root.widgetInk
    readonly property string username: SystemInfo.displayName || SystemInfo.username
    readonly property string hostname: SystemInfo.hostname
    readonly property string userDisplay: root.showHostname && root.hostname.length > 0
        ? `${root.username}@${root.hostname}` : root.username

    readonly property var machineFacts: [
        { glyph: "terminal", label: Translation.tr("Shell"), value: String(Quickshell.env("SHELL") ?? "").split("/").pop() || "sh" },
        { glyph: "desktop_windows", label: Translation.tr("Desktop"),
            value: String(SystemInfo.desktopEnvironment || "Wayland").split(":")[0].replace(/^./, first => first.toUpperCase()) },
        { glyph: "computer", label: Translation.tr("Machine"), value: root.hostname || SystemInfo.distroName }
    ].concat(root.showWeather && root.weatherLine.text !== "" ? [{ glyph: root.weatherLine.icon, label: Translation.tr("Weather"), value: root.weatherLine.text }] : [])
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

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            WidgetSurface {
                widget: root
                anchors.fill: parent
                surfaceColor: root.surfaceInk
                surfaceAccent: root.widgetAccent3
                shown: !root.familyFaced && !root.instrument && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
            }
        }
    }

    ColumnLayout {
        id: cardColumn
        visible: !root.familyFaced && opacity > 0
        opacity: root.instrument ? 0 : 1
        enabled: !root.instrument
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        anchors.fill: parent
        anchors.margins: Math.round(14 * root.scaleFactor)
        spacing: Math.round(10 * root.scaleFactor)

        // Small stacks the picture over the name, which then has the whole width.
        GridLayout {
            Layout.fillWidth: true
            columns: root.isSmall ? 1 : 2
            columnSpacing: Math.round(12 * root.scaleFactor)
            rowSpacing: Math.round(8 * root.scaleFactor)

            Item {
                id: avatarContainer
                visible: root.showAvatar
                readonly property int size: Math.round((root.isLarge ? 84 : 48) * root.scaleFactor)
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
                        color: root.widgetInkMuted
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
                    text: root.isSmall || root.isLarge ? root.username : root.userDisplay
                    elide: Text.ElideRight
                    color: root.surfaceInk
                    font.family: root.widgetTitleFamily
                    font.pixelSize: Math.round((root.isLarge ? Appearance.font.pixelSize.huge : Appearance.font.pixelSize.normal)
                        * root.widgetTitleScale * root.scaleFactor)
                    font.weight: root.widgetTitleWeight
                    font.letterSpacing: root.widgetTitleTracking
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Up %1").arg(DateTime.uptime || "--")
                    elide: Text.ElideRight
                    color: root.widgetInkMuted
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignLeft
            Layout.maximumWidth: parent.width
            visible: root.showWeather && root.weatherLine.text !== "" && !root.isSmall && !root.isLarge
                && root.height >= Math.round(170 * root.scaleFactor)
            implicitWidth: Math.min(parent.width,
                weatherChip.implicitWidth + Math.round(18 * root.scaleFactor))
            implicitHeight: weatherChip.implicitHeight + Math.round(9 * root.scaleFactor)
            radius: root.widgetEditorial ? root.widgetControlRadius : height / 2
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
                    font.weight: root.widgetLabelWeight
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // Large: the machine the person is on, a row each, in the tonal discs the rest of Material uses.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            visible: root.isLarge
            spacing: Math.round(6 * root.scaleFactor)
            Repeater {
                model: root.isLarge ? root.machineFacts : []
                RowLayout {
                    id: fact
                    required property var modelData
                    required property int index
                    readonly property string role: fact.index % 2 === 0 ? root.widgetSecondaryRole : root.widgetTertiaryRole
                    Layout.fillWidth: true
                    spacing: Math.round(10 * root.scaleFactor)
                    Rectangle {
                        implicitWidth: Math.round(28 * root.scaleFactor)
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: root.widgetSemanticContainer(fact.role)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: fact.modelData.glyph
                            fill: 1
                            iconSize: Math.round(16 * root.scaleFactor)
                            color: root.widgetSemanticOnContainer(fact.role)
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: fact.modelData.label
                        color: root.widgetInkMuted
                        elide: Text.ElideRight
                        font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                    }
                    StyledText {
                        Layout.maximumWidth: Math.round(180 * root.scaleFactor)
                        text: fact.modelData.value
                        color: root.surfaceInk
                        elide: Text.ElideRight
                        font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: root.isLarge ? Math.round(6 * root.scaleFactor) : 0
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
                        visible: !root.isSmall
                        text: Translation.tr("Lock")
                        color: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
                        font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                        font.weight: root.widgetLabelWeight
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
                // the lock's tone: one family for the keys, red only where the session ends (three tones read as noise)
                colBackground: root.widgetSemanticContainer(root.widgetPrimaryRole)
                colBackgroundHover: ColorUtils.mix(root.widgetSemanticContainer(root.widgetPrimaryRole),
                    root.widgetSemanticOnContainer(root.widgetPrimaryRole), 0.90)
                colRipple: ColorUtils.mix(root.widgetSemanticContainer(root.widgetPrimaryRole),
                    root.widgetSemanticOnContainer(root.widgetPrimaryRole), 0.80)
                onClicked: GlobalStates.openSettings()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "settings"
                    fill: 1
                    iconSize: Math.round(17 * root.scaleFactor)
                    color: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
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

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            RowLayout {
                id: instrumentPlate
                anchors.fill: parent
                anchors.margins: Math.round(12 * root.scaleFactor)
                spacing: Math.round(12 * root.scaleFactor)
                visible: !root.familyFaced && opacity > 0
                opacity: root.instrument ? 1 : 0
                enabled: root.instrument
                Behavior on opacity {
                    enabled: root.animationsActive
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                // small is the person and the session: the label, condition and keys left the name 40 px
                Item {
                    visible: root.showAvatar
                    Layout.preferredWidth: Math.round((root.isSmall ? 44 : root.isLarge ? 96 : 58) * root.scaleFactor)
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.alignment: root.isSmall || root.isLarge ? Qt.AlignTop : Qt.AlignVCenter

                    Rectangle {
                        id: instrumentAvatarMask
                        anchors.fill: parent
                        radius: Math.round(8 * root.scaleFactor)
                        visible: false
                    }
                    Image {
                        anchors.fill: parent
                        source: avatarResolver.resolvedSource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                        mipmap: true
                        layer.enabled: status === Image.Ready
                        layer.effect: GE.OpacityMask { maskSource: instrumentAvatarMask }
                    }
                    InstrumentBrackets { anchors.fill: parent; color: root.widgetAccentVisible; length: Math.round(13 * root.scaleFactor) }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Math.round(3 * root.scaleFactor)

                    InstrumentLabel {
                        visible: !root.isSmall
                        text: Translation.tr("Identity / Session")
                        color: root.widgetAccentVisible
                        scaleFactor: root.scaleFactor
                        strong: true
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.username
                        color: root.widgetInk
                        elide: Text.ElideRight
                        font.family: root.widgetTitleFamily
                        font.pixelSize: Math.round((root.isSmall ? 20 : 26) * root.scaleFactor)
                        font.weight: Font.Bold
                    }
                    StyledText {
                        visible: root.showHostname && root.hostname.length > 0
                        Layout.fillWidth: true
                        text: root.familyDesign ? root.hostname : root.hostname.toUpperCase()
                        color: root.widgetInkMuted
                        elide: Text.ElideRight
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Math.max(9, Math.round(10 * root.scaleFactor))
                        font.letterSpacing: Math.round(0.8 * root.scaleFactor)
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(10 * root.scaleFactor)
                        InstrumentField {
                            Layout.alignment: Qt.AlignTop
                            scaleFactor: root.scaleFactor
                            label: Translation.tr("Session")
                            // small reads the two largest units, as the uptime widget does
                            value: root.isSmall ? String(DateTime.uptime).split(", ").slice(0, 2).join(" ") : DateTime.uptime
                            ink: root.widgetInk
                            muted: root.widgetInkMuted
                            family: root.widgetNumbersFamily
                        }
                        InstrumentField {
                            visible: root.showWeather && root.weatherLine.text !== "" && !root.isSmall
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            scaleFactor: root.scaleFactor
                            label: Translation.tr("Condition")
                            value: root.weatherLine.text
                            ink: root.widgetInk
                            muted: root.widgetInkMuted
                            family: root.widgetBodyFamily
                            valueSize: 12
                        }
                    }
                }

                ColumnLayout {
                    visible: !root.isSmall
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Math.round(5 * root.scaleFactor)
                    Repeater {
                        model: [
                            { icon: "lock", action: () => root.lockScreen() },
                            { icon: "settings", action: () => GlobalStates.openSettings() },
                            { icon: "power_settings_new", action: () => GlobalStates.sessionOpen = true }
                        ]
                        RippleButton {
                            required property var modelData
                            implicitWidth: Math.round(30 * root.scaleFactor)
                            implicitHeight: implicitWidth
                            buttonRadius: Math.round(6 * root.scaleFactor)
                            colBackground: "transparent"
                            colBackgroundHover: ColorUtils.applyAlpha(root.widgetAccent, 0.14)
                            colRipple: ColorUtils.applyAlpha(root.widgetAccent, 0.22)
                            downAction: modelData.action
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: modelData.icon; iconSize: Math.round(16 * root.scaleFactor); color: root.widgetInk }
                        }
                    }
                }
            }
        }
    }
}

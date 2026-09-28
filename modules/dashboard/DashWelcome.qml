import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Greeting card: avatar, "Welcome, user!" and an optional custom phrase.
 */
DashCard {
    id: root
    // The greeting is the dashboard's compositional focus: one ink field per scene.
    inkField: true

    readonly property string customSubtitle: Config.options?.dashboard?.subtitle ?? ""
    readonly property bool editorial: Appearance.editorialEverywhere

    readonly property string greeting: {
        const hour = DateTime.clock.hours
        if (hour < 5) return Translation.tr("Up late, %1?")
        if (hour < 12) return Translation.tr("Good morning, %1!")
        if (hour < 19) return Translation.tr("Welcome, %1!")
        return Translation.tr("Good evening, %1!")
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 4
        spacing: root.editorial ? Math.round(12 * Appearance.editorial.spacing) : 10

        // Editorial keeps its date, portrait, and signature mark on one
        // compact masthead row. Non-editorial still centers the 72 px avatar.
        RowLayout {
            Layout.fillWidth: true
            spacing: root.editorial ? 7 : 0

            StyledText {
                Layout.fillWidth: root.editorial
                Layout.minimumWidth: 0
                visible: root.editorial
                text: DateTime.date
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
                font.capitalization: Font.AllUppercase
                color: root.colText
                elide: Text.ElideRight
            }
            Item { Layout.fillWidth: true }

            // Avatar with circular clipping + reactive fallback chain
            Item {
                Layout.alignment: root.editorial ? Qt.AlignVCenter : Qt.AlignHCenter
                implicitWidth: root.editorial ? 48 : 72
                implicitHeight: root.editorial ? 48 : 72

            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: width / 2
                visible: false
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
                sourceSize.width: 144
                sourceSize.height: 144
                opacity: status === Image.Ready ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                layer.enabled: status === Image.Ready
                layer.effect: GE.OpacityMask { maskSource: avatarMask }
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
                        const nextIdx = avatarIndex + 1
                        if (nextIdx < Directories.userAvatarPaths.length)
                            avatarIndex = nextIdx
                    }
                }
            }

            // Fallback while no avatar image resolves
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                     : root.inirEverywhere ? Appearance.inir.colLayer2
                     : root.auroraEverywhere ? Appearance.aurora.colSubSurface
                     : Appearance.colors.colLayer2
                opacity: avatarImg.status !== Image.Ready ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "person"
                    iconSize: root.editorial ? 28 : 36
                    color: root.colAccent
                }
            }

            }

            // Keep the legacy avatar mathematically centered when Editorial
            // metadata is hidden; Editorial leaves this slot empty.
            Item { Layout.fillWidth: !root.editorial }

            MaterialShape {
                Layout.alignment: Qt.AlignTop
                implicitSize: 18
                visible: root.editorial && Appearance.editorial.ornaments
                shape: MaterialShape.Shape.Flower
                color: root.colText
            }
        }

        StyledText {
            Layout.alignment: root.editorial ? Qt.AlignLeft : Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.greeting.arg(SystemInfo.displayName || SystemInfo.username)
            horizontalAlignment: root.editorial ? Text.AlignLeft : Text.AlignHCenter
            font.pixelSize: root.editorial
                ? 38 * Appearance.editorial.titleScale * Appearance.fontSizeScale
                : Appearance.font.pixelSize.huge
            font.family: Appearance.font.family.title
            font.weight: root.editorial ? Appearance.editorial.titleWeight : Font.DemiBold
            font.letterSpacing: Appearance.editorialEverywhere ? Appearance.editorial.titleTracking : 0
            fontSizeMode: root.editorial ? Text.Fit : Text.FixedSize
            minimumPixelSize: root.editorial ? Math.max(18, 22 * Appearance.fontSizeScale) : 1
            wrapMode: root.editorial ? Text.WordWrap : Text.NoWrap
            color: root.colText
            elide: root.editorial ? Text.ElideNone : Text.ElideRight
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            visible: root.customSubtitle.length > 0
            text: root.customSubtitle
            horizontalAlignment: root.editorial ? Text.AlignLeft : Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.colSubtext
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.editorial && root.customSubtitle.length > 0
            Layout.preferredHeight: 1
            color: ColorUtils.applyAlpha(root.colText, 0.42)
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Greeting card: avatar, "Welcome, user!" and an optional custom phrase.
 */
DashCard {
    id: root

    readonly property string customSubtitle: Config.options?.dashboard?.subtitle ?? ""

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
        spacing: 10

        // Avatar with circular clipping + reactive fallback chain
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 72
            implicitHeight: 72

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
                    iconSize: 36
                    color: root.colAccent
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.greeting.arg(SystemInfo.displayName || SystemInfo.username)
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.huge
            font.family: Appearance.font.family.title
            font.weight: Font.DemiBold
            color: root.colText
            elide: Text.ElideRight
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            visible: root.customSubtitle.length > 0
            text: root.customSubtitle
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.colSubtext
            wrapMode: Text.WordWrap
        }
    }
}

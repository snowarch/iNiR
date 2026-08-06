pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.modules.wallpaperSelector
import QtQuick

Item {
    id: root

    required property var modelData
    required property int index
    required property real cardWidth
    required property real cardHeight
    signal activated(int index)

    readonly property bool current: PathView.isCurrentItem
    readonly property bool applied:
        root.modelData.path === (PathView.view?.currentWallpaperPath ?? "")
    property real entryScale: 0.96
    property real entryOpacity: 0

    implicitWidth: cardWidth
    implicitHeight: cardHeight
    scale: PathView.onPath ? 1 : 0
    opacity: PathView.onPath ? 1 : 0
    z: PathView.z ?? 0

    Component.onCompleted: entryAnimation.restart()

    ParallelAnimation {
        id: entryAnimation
        NumberAnimation {
            target: root
            property: "entryScale"
            from: 0.96
            to: 1
            duration: Appearance.animationsEnabled
                ? Appearance.animation.elementMoveEnter.duration : 0
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
        NumberAnimation {
            target: root
            property: "entryOpacity"
            from: 0
            to: 1
            duration: Appearance.animationsEnabled
                ? Appearance.animation.elementMoveEnter.duration : 0
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
    }

    WallpaperDirectoryItem {
        id: card
        anchors.fill: parent
        scale: root.entryScale
        opacity: root.entryOpacity
        fileModelData: ({
            filePath: root.modelData.path,
            fileName: root.modelData.name,
            fileIsDir: false,
            fileUrl: root.modelData.path
        })
        // Keep the original card inset and accent surface. The launcher has at
        // most five cards, so it can afford a 2x decoded thumbnail and mipmaps
        // without imposing that cost on the full wallpaper grid.
        thumbnailResolutionScale: 2
        thumbnailMipmap: true
        colBackground: (root.current || containsMouse)
            ? Appearance.colors.colPrimary
            : root.applied
                ? Appearance.colors.colSecondaryContainer
                : ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
        colText: (root.current || containsMouse)
            ? Appearance.colors.colOnPrimary
            : root.applied
                ? Appearance.colors.colOnSecondaryContainer
                : Appearance.colors.colOnLayer0
        onActivated: root.activated(root.index)
    }
}

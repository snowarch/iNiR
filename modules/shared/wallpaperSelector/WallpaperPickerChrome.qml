pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick

// The coverflow pickers' one row of controls: where you are (crumbs), where you can
// go (subfolders), search, and the switch between pickers. Slanted plates under the
// skew deck, rounded ones under the gallery.
Item {
    id: root

    property bool slanted: true
    // "skew" or "gallery": the picker showing this row
    property string currentView: "skew"
    property string folderPath: ""
    // [{ name, path }] of the current folder's subfolders
    property var folderItems: []
    property bool searchOpen: false
    readonly property bool searchFocused: searchField.activeFocus
    readonly property bool searching: (Wallpapers.searchQuery ?? "").length > 0

    signal viewRequested(string view)
    signal folderRequested(string path)
    // Search handed focus back (Esc, Enter, Tab, Down)
    signal focusReturned()

    function openSearch(): void {
        root.searchOpen = true
        searchField.forceActiveFocus()
    }

    function closeSearch(): void {
        Wallpapers.searchQuery = ""
        searchField.text = ""
        root.searchOpen = false
        root.focusReturned()
    }

    readonly property string _wallpapersDir: `${Directories.picturesPath}/Wallpapers`
    readonly property string _folderPathClean: FileUtils.trimFileProtocol(String(root.folderPath ?? "")).replace(/\/+$/, "") || "/"

    // Home (or /), at most the last three folders, the current one last
    readonly property var _crumbs: {
        const p = root._folderPathClean
        const home = Directories.homePath.replace(/\/+$/, "")
        const underHome = p === home || p.startsWith(home + "/")
        const base = underHome ? home : ""
        const parts = p.substring(base.length).split("/").filter(s => s.length > 0)
        const out = [{ name: "", icon: underHome ? "home" : "hard_drive", path: base || "/" }]
        const start = Math.max(0, parts.length - 3)
        let acc = base
        for (let i = 0; i < parts.length; i++) {
            acc += "/" + parts[i]
            if (i === start - 1)
                out.push({ name: "…", icon: "", path: acc })
            else if (i >= start)
                out.push({ name: parts[i], icon: "", path: acc })
        }
        return out
    }

    height: 36

    // ─ Where you are ─
    Row {
        id: crumbRow
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: 4

        WallpaperPickerChip {
            slanted: root.slanted
            visible: root._folderPathClean !== root._wallpapersDir
            icon: "wallpaper"
            onClicked: root.folderRequested(root._wallpapersDir)
            StyledToolTip { text: Translation.tr("Wallpapers folder") }
        }

        Repeater {
            model: root._crumbs
            delegate: WallpaperPickerChip {
                required property var modelData
                required property int index
                slanted: root.slanted
                label: modelData.name
                icon: modelData.icon
                active: index === root._crumbs.length - 1
                onClicked: if (!active) root.folderRequested(modelData.path)
            }
        }
    }

    // ─ Where you can go: the subfolders, scrolled sideways ─
    MaterialSymbol {
        id: subfolderMark
        visible: root.folderItems.length > 0
        anchors { left: crumbRow.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
        text: "subdirectory_arrow_right"
        iconSize: Appearance.font.pixelSize.larger
        color: Appearance.colors.colOnSurface
        opacity: 0.7
    }

    ListView {
        id: subfolderList
        visible: root.folderItems.length > 0
        anchors {
            left: subfolderMark.right; leftMargin: 6
            right: rightRow.left; rightMargin: 16
            verticalCenter: parent.verticalCenter
        }
        height: parent.height
        orientation: ListView.Horizontal
        spacing: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.folderItems
        delegate: WallpaperPickerChip {
            required property var modelData
            slanted: root.slanted
            muted: true
            icon: "folder"
            label: modelData.name
            onClicked: root.folderRequested(modelData.path)
        }

        // Sideways scroll here; the picker keeps the wheel everywhere else
        MouseArea {
            anchors.fill: parent
            z: 10
            acceptedButtons: Qt.NoButton
            onWheel: event => {
                const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                subfolderList.contentX = Math.max(0, Math.min(subfolderList.contentWidth - subfolderList.width,
                    subfolderList.contentX - d))
            }
        }
    }

    // ─ Search and the picker switch ─
    Row {
        id: rightRow
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 4

        WallpaperPickerChip {
            id: searchChip
            readonly property bool open: root.searchOpen || root.searching
            readonly property int closedWidth: 36 + slant
            readonly property int openWidth: 280
            // 0 → 1 as the plate grows: the glyph slides left and the field fades in behind it
            readonly property real reveal: Math.max(0, Math.min(1, (width - closedWidth) / (openWidth - closedWidth)))
            slanted: root.slanted
            active: root.searching && !searchField.activeFocus
            implicitWidth: open ? openWidth : closedWidth
            Behavior on implicitWidth {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }
            onClicked: root.openSearch()
            StyledToolTip {
                text: Translation.tr("Search (/)")
                extraVisibleCondition: !searchChip.open
            }

            // Own glyph: centred while closed, at the start of the field while open
            MaterialSymbol {
                id: searchGlyph
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2 * (1 - searchChip.reveal)
                    + (searchChip.slant + 12) * searchChip.reveal)
                text: "search"
                iconSize: Appearance.font.pixelSize.larger
                color: searchChip.ink
            }

            TextInput {
                id: searchField
                visible: searchChip.reveal > 0
                opacity: searchChip.reveal
                anchors {
                    left: searchGlyph.right; leftMargin: 8
                    right: parent.right; rightMargin: searchChip.slant + 12
                    verticalCenter: parent.verticalCenter
                }
                clip: true
                color: searchChip.ink
                selectionColor: Appearance.colors.colPrimary
                selectedTextColor: Appearance.colors.colOnPrimary
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                text: Wallpapers.searchQuery
                onTextChanged: Wallpapers.searchQuery = text
                onActiveFocusChanged: if (!activeFocus && text.length === 0) root.searchOpen = false
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.closeSearch()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        // Back to the wallpapers with the results; the query stays
                        root.focusReturned()
                        event.accepted = true
                    }
                }

                StyledText {
                    visible: searchField.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: Translation.tr("Search wallpapers")
                    color: searchChip.ink
                    opacity: 0.6
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        Item { width: 12; height: 1 }

        Repeater {
            model: [
                { name: Translation.tr("Skew"), icon: "view_week", view: "skew" },
                { name: Translation.tr("Gallery"), icon: "view_carousel", view: "gallery" },
                { name: Translation.tr("Grid"), icon: "grid_view", view: "grid" }
            ]
            delegate: WallpaperPickerChip {
                required property var modelData
                slanted: root.slanted
                icon: modelData.icon
                label: modelData.name
                active: modelData.view === root.currentView
                onClicked: if (!active) root.viewRequested(modelData.view)
            }
        }
    }
}

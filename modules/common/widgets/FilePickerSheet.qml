pragma ComponentBehavior: Bound
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// The chooser FilePickerDialog shows: places on the left, the folder as pictures, the choice at the bottom.
// Keys: arrows move, Enter opens, Backspace goes up, Alt+Left goes back, Ctrl+L types a path, Ctrl+H shows hidden
// files, typing searches, Esc cancels.
Item {
    id: root

    property string title: ""
    property list<string> nameFilters: []
    property string startFolder: ""
    property bool selectFolder: false

    signal chosen(string path)
    signal cancelled()

    readonly property real s: FamilyStyle.density

    // Where we are and how we got here.
    property string folder: ""
    onFolderChanged: rebuild.restart()
    property list<string> trail: []
    property string revealName: ""
    property string query: ""
    property bool showHidden: false
    property int filterIndex: 0
    property bool editingPath: false

    // "Images (*.png *.jpg)" -> { label: "Images", globs: ["*.png", "*.jpg"] }
    readonly property var filters: root.nameFilters.map(f => {
        const m = String(f).match(/^(.*?)\s*\(([^)]*)\)\s*$/)
        if (!m)
            return { label: String(f), globs: ["*"] }
        const globs = m[2].split(/\s+/).filter(g => g.length > 0)
        return { label: m[1], globs: globs.length > 0 ? globs : ["*"] }
    })
    readonly property list<string> globs: root.filters[root.filterIndex]?.globs ?? ["*"]

    property var entries: []
    readonly property var shown: {
        const q = root.query.trim().toLowerCase()
        return q.length === 0 ? root.entries : root.entries.filter(e => e.name.toLowerCase().includes(q))
    }
    readonly property var current: grid.currentIndex >= 0 ? (root.shown[grid.currentIndex] ?? null) : null
    // What the main button takes: the highlighted file, or in folder mode the highlighted folder or this one.
    readonly property string choice: root.selectFolder
        ? (root.current?.dir ? root.current.path : root.folder)
        : (root.current && !root.current.dir ? root.current.path : "")

    readonly property list<string> imageSuffixes: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "tif", "tiff", "avif", "apng"]
    readonly property list<string> videoSuffixes: ["mp4", "webm", "mkv", "avi", "mov"]

    function pathOf(target: string): string {
        let p = FileUtils.trimFileProtocol(String(target ?? ""))
        try { p = decodeURIComponent(p) } catch (e) {}
        if (p.length > 1 && p.endsWith("/"))
            p = p.slice(0, -1)
        return p
    }
    function urlOf(path: string): string {
        return "file://" + path.split("/").map(part => encodeURIComponent(part)).join("/")
    }
    function nameOf(path: string): string {
        return path === "/" ? "/" : path.slice(path.lastIndexOf("/") + 1)
    }
    function parentOf(path: string): string {
        const i = path.lastIndexOf("/")
        return i <= 0 ? "/" : path.slice(0, i)
    }
    function go(path: string, remember = true): void {
        if (path.length === 0 || path === root.folder)
            return
        if (remember && root.folder.length > 0)
            root.trail = root.trail.concat([root.folder])
        root.query = ""
        root.editingPath = false
        root.entries = []
        grid.currentIndex = -1
        root.folder = path
        grid.forceActiveFocus()
    }
    function up(): void {
        if (root.folder === "/")
            return
        root.revealName = root.nameOf(root.folder)
        root.go(root.parentOf(root.folder))
    }
    function back(): void {
        if (root.trail.length === 0)
            return
        const previous = root.trail[root.trail.length - 1]
        root.trail = root.trail.slice(0, -1)
        root.go(previous, false)
    }
    function activate(entry: var): void {
        if (!entry)
            return
        if (entry.dir)
            root.go(entry.path)
        else if (!root.selectFolder)
            root.chosen(entry.path)
    }
    function accept(): void {
        if (root.choice.length > 0)
            root.chosen(root.choice)
    }
    function kindOf(entry: var): string {
        if (entry.dir) return "folder"
        if (root.imageSuffixes.includes(entry.suffix)) return "image"
        if (root.videoSuffixes.includes(entry.suffix)) return "video"
        return "file"
    }
    function glyphOf(entry: var): string {
        switch (root.kindOf(entry)) {
        case "folder": return "folder"
        case "image": return "image"
        case "video": return "movie"
        }
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar"].includes(entry.suffix)) return "folder_zip"
        if (["srt", "ass", "ssa", "vtt", "sub", "txt", "md", "conf", "ovpn", "json"].includes(entry.suffix)) return "description"
        return "draft"
    }

    Component.onCompleted: {
        const start = root.pathOf(root.startFolder)
        const images = (root.filters[0]?.globs ?? []).some(g => g.endsWith(".png") || g.endsWith(".jpg"))
        root.folder = start.length > 0 ? start : (images ? Directories.picturesPath : Directories.homePath)
        places.running = true
        grid.forceActiveFocus()
    }

    FolderListModel {
        id: listing
        folder: root.folder.length > 0 ? root.urlOf(root.folder) : ""
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: root.showHidden
        showFiles: !root.selectFolder
        nameFilters: root.globs
        caseSensitive: false
        sortCaseSensitive: false
        onStatusChanged: rebuild.restart()
        onCountChanged: rebuild.restart()
    }
    Timer {
        id: rebuild
        interval: 16
        onTriggered: {
            if (root.folder.length === 0)
                return
            // The model refuses a folder that does not exist and keeps its last one: step up to one that exists.
            if (root.pathOf(String(listing.folder)) !== root.folder) {
                if (root.folder !== "/")
                    root.go(root.parentOf(root.folder), false)
                return
            }
            if (listing.status !== FolderListModel.Ready)
                return
            const rows = []
            for (let i = 0; i < listing.count; i++) {
                rows.push({
                    name: String(listing.get(i, "fileName")),
                    path: String(listing.get(i, "filePath")),
                    dir: Boolean(listing.get(i, "fileIsDir")),
                    suffix: String(listing.get(i, "fileSuffix")).toLowerCase()
                })
            }
            root.entries = rows
            // Nothing is chosen until the person picks: in folder mode that means this folder.
            grid.currentIndex = -1
            if (root.revealName.length > 0) {
                const at = rows.findIndex(r => r.name === root.revealName)
                if (at >= 0) {
                    grid.currentIndex = at
                    grid.positionViewAtIndex(at, GridView.Contain)
                    root.revealName = ""
                }
            }
        }
    }

    // The places column: home, the person's own folders that exist, then their GTK bookmarks.
    property var placeList: []
    Process {
        id: places
        command: ["bash", "-c", "for d in \"$@\"; do [ -d \"$d\" ] && printf '%s\\n' \"$d\"; done; echo --; cat \"$HOME/.config/gtk-3.0/bookmarks\" 2>/dev/null", "places",
            Directories.homePath,
            FileUtils.trimFileProtocol(StandardPaths.writableLocation(StandardPaths.DesktopLocation)),
            FileUtils.trimFileProtocol(StandardPaths.writableLocation(StandardPaths.DocumentsLocation)),
            FileUtils.trimFileProtocol(StandardPaths.writableLocation(StandardPaths.DownloadLocation)),
            Directories.picturesPath,
            FileUtils.trimFileProtocol(StandardPaths.writableLocation(StandardPaths.MoviesLocation)),
            FileUtils.trimFileProtocol(StandardPaths.writableLocation(StandardPaths.MusicLocation))]
        stdout: StdioCollector {
            id: placesOut
            onStreamFinished: {
                const glyphs = ["home", "desktop_windows", "description", "download", "image", "movie", "music_note"]
                const [standard, marks] = placesOut.text.split("--\n")
                const wanted = [Directories.homePath,
                    FileUtils.trimFileProtocol(StandardPaths.writableLocation(StandardPaths.DesktopLocation)),
                    FileUtils.trimFileProtocol(StandardPaths.writableLocation(StandardPaths.DocumentsLocation)),
                    FileUtils.trimFileProtocol(StandardPaths.writableLocation(StandardPaths.DownloadLocation)),
                    Directories.picturesPath,
                    FileUtils.trimFileProtocol(StandardPaths.writableLocation(StandardPaths.MoviesLocation)),
                    FileUtils.trimFileProtocol(StandardPaths.writableLocation(StandardPaths.MusicLocation))]
                const found = (standard ?? "").split("\n").filter(l => l.length > 0)
                const list = []
                wanted.forEach((path, i) => {
                    if (found.includes(path) && !list.some(p => p.path === path))
                        list.push({ path: path, label: i === 0 ? Translation.tr("Home") : root.nameOf(path), glyph: glyphs[i] })
                })
                const bookmarks = (marks ?? "").split("\n")
                bookmarks.forEach(line => {
                    const m = line.match(/^file:\/\/(\S+)(?:\s+(.*))?$/)
                    if (!m)
                        return
                    const path = root.pathOf(m[1])
                    if (!list.some(p => p.path === path))
                        list.push({ path: path, label: m[2] || root.nameOf(path), glyph: "bookmark" })
                })
                root.placeList = list
            }
        }
    }

    ShellSheet {
        id: sheet
        anchors.fill: parent
        cardWidth: 980 * root.s
        cardHeight: 640 * root.s
        onDismissed: root.cancelled()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(16 * root.s)
            spacing: Math.round(12 * root.s)

            // The ask, and where we are.
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * root.s)

                StyledText {
                    Layout.preferredWidth: placesColumn.width
                    elide: Text.ElideRight
                    text: root.title.length > 0 ? root.title : root.selectFolder ? Translation.tr("Choose a folder") : Translation.tr("Choose a file")
                    color: FamilyStyle.textStrong
                    font.family: FamilyStyle.fontTitle
                    font.pixelSize: FamilyStyle.typeLabel
                    font.weight: Font.DemiBold
                }
                SheetButton {
                    glyph: "arrow_back"
                    tip: Translation.tr("Back")
                    enabled: root.trail.length > 0
                    onClicked: root.back()
                }
                SheetButton {
                    glyph: "arrow_upward"
                    tip: Translation.tr("Up")
                    enabled: root.folder !== "/"
                    onClicked: root.up()
                }

                // The path: its folders as steps, or typed after Ctrl+L or a click on its free end.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(34 * root.s)
                    radius: FamilyStyle.radiusRow
                    color: FamilyStyle.fillQuiet

                    MouseArea {
                        anchors.fill: parent
                        visible: !root.editingPath
                        cursorShape: Qt.IBeamCursor
                        onClicked: root.editPath()
                    }
                    ListView {
                        id: crumbs
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(4 * root.s)
                        anchors.rightMargin: Math.round(4 * root.s)
                        visible: !root.editingPath
                        orientation: ListView.Horizontal
                        interactive: contentWidth > width
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: {
                            const home = Directories.homePath
                            const inHome = root.folder === home || root.folder.startsWith(home + "/")
                            const rest = inHome ? root.folder.slice(home.length) : root.folder
                            const parts = rest.split("/").filter(p => p.length > 0)
                            const steps = [{ label: inHome ? Translation.tr("Home") : "/", path: inHome ? home : "/" }]
                            let at = steps[0].path
                            parts.forEach(p => {
                                at = at === "/" ? "/" + p : at + "/" + p
                                steps.push({ label: p, path: at })
                            })
                            return steps
                        }
                        onContentWidthChanged: crumbs.positionViewAtEnd()
                        delegate: Row {
                            id: crumb
                            required property var modelData
                            required property int index
                            height: crumbs.height
                            MaterialSymbol {
                                visible: crumb.index > 0
                                anchors.verticalCenter: parent.verticalCenter
                                text: "chevron_right"
                                iconSize: Math.round(16 * root.s)
                                color: FamilyStyle.textTertiary
                            }
                            MouseArea {
                                id: crumbArea
                                anchors.verticalCenter: parent.verticalCenter
                                width: crumbLabel.implicitWidth + Math.round(16 * root.s)
                                height: Math.round(26 * root.s)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.go(crumb.modelData.path)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: FamilyStyle.radiusChip
                                    color: crumbArea.containsMouse ? FamilyStyle.fillHover : "transparent"
                                }
                                StyledText {
                                    id: crumbLabel
                                    anchors.centerIn: parent
                                    text: crumb.modelData.label
                                    color: crumb.index === crumbs.count - 1 ? FamilyStyle.textStrong : FamilyStyle.textSecondary
                                    font.family: FamilyStyle.fontMain
                                    font.pixelSize: FamilyStyle.typeMeta
                                    font.weight: crumb.index === crumbs.count - 1 ? Font.DemiBold : Font.Normal
                                }
                            }
                        }
                    }
                    TextInput {
                        id: pathInput
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(12 * root.s)
                        anchors.rightMargin: Math.round(12 * root.s)
                        visible: root.editingPath
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: FamilyStyle.textStrong
                        selectionColor: ColorUtils.applyAlpha(FamilyStyle.accent, 0.35)
                        selectedTextColor: FamilyStyle.textStrong
                        font.family: FamilyStyle.fontMain
                        font.pixelSize: FamilyStyle.typeMeta
                        onAccepted: {
                            let typed = pathInput.text.trim()
                            if (typed.startsWith("~"))
                                typed = Directories.homePath + typed.slice(1)
                            root.go(root.pathOf(typed))
                        }
                        Keys.onEscapePressed: event => {
                            root.editingPath = false
                            grid.forceActiveFocus()
                            event.accepted = true
                        }
                        onActiveFocusChanged: if (!activeFocus) root.editingPath = false
                    }
                }

                // Search in this folder.
                Rectangle {
                    implicitWidth: Math.round(200 * root.s)
                    implicitHeight: Math.round(34 * root.s)
                    radius: FamilyStyle.radiusRow
                    color: searchInput.activeFocus ? FamilyStyle.fillHover : FamilyStyle.fillQuiet
                    MaterialSymbol {
                        id: searchGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(10 * root.s)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        iconSize: Math.round(16 * root.s)
                        color: FamilyStyle.textTertiary
                    }
                    TextInput {
                        id: searchInput
                        anchors.left: searchGlyph.right
                        anchors.right: parent.right
                        anchors.leftMargin: Math.round(6 * root.s)
                        anchors.rightMargin: Math.round(10 * root.s)
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        text: root.query
                        color: FamilyStyle.textStrong
                        selectionColor: ColorUtils.applyAlpha(FamilyStyle.accent, 0.35)
                        selectedTextColor: FamilyStyle.textStrong
                        font.family: FamilyStyle.fontMain
                        font.pixelSize: FamilyStyle.typeMeta
                        onTextEdited: {
                            root.query = searchInput.text
                            grid.currentIndex = root.shown.length > 0 ? 0 : -1
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                grid.forceActiveFocus()
                                if (event.key !== Qt.Key_Down)
                                    root.activate(root.current)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                if (root.query.length > 0)
                                    root.query = ""
                                grid.forceActiveFocus()
                                event.accepted = true
                            }
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text.length === 0
                            text: Translation.tr("Search")
                            color: FamilyStyle.textTertiary
                            font: searchInput.font
                        }
                    }
                }
                SheetButton {
                    glyph: root.showHidden ? "visibility" : "visibility_off"
                    tip: root.showHidden ? Translation.tr("Hide hidden files") : Translation.tr("Show hidden files")
                    toggled: root.showHidden
                    onClicked: root.showHidden = !root.showHidden
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(12 * root.s)

                // Places.
                ListView {
                    id: placesColumn
                    Layout.preferredWidth: Math.round(184 * root.s)
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: Math.round(2 * root.s)
                    model: root.placeList
                    delegate: MouseArea {
                        id: place
                        required property var modelData
                        readonly property bool here: root.folder === place.modelData.path
                        width: placesColumn.width
                        height: Math.round(34 * root.s)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.go(place.modelData.path)
                        Rectangle {
                            anchors.fill: parent
                            radius: FamilyStyle.radiusRow
                            color: place.here ? ColorUtils.applyAlpha(FamilyStyle.accent, 0.16) : place.containsMouse ? FamilyStyle.fillHover : "transparent"
                            Behavior on color { ColorAnimation { duration: FamilyStyle.feedbackDuration } }
                        }
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Math.round(10 * root.s)
                            anchors.rightMargin: Math.round(8 * root.s)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.round(10 * root.s)
                            MaterialSymbol {
                                id: placeGlyph
                                anchors.verticalCenter: parent.verticalCenter
                                text: place.modelData.glyph
                                iconSize: Math.round(18 * root.s)
                                fill: place.here ? 1 : 0
                                color: place.here ? FamilyStyle.accent : FamilyStyle.textSecondary
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - placeGlyph.width - parent.spacing
                                elide: Text.ElideRight
                                text: place.modelData.label
                                color: place.here ? FamilyStyle.textStrong : FamilyStyle.text
                                font.family: FamilyStyle.fontMain
                                font.pixelSize: FamilyStyle.typeMeta
                                font.weight: place.here ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }

                // The folder, its pictures as pictures.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: FamilyStyle.radiusCard
                    color: FamilyStyle.fillQuiet

                    GridView {
                        id: grid
                        anchors.fill: parent
                        anchors.margins: Math.round(8 * root.s)
                        readonly property int columns: Math.max(1, Math.floor(width / Math.round(124 * root.s)))
                        cellWidth: Math.floor(width / grid.columns)
                        cellHeight: Math.round(grid.cellWidth * 0.78 + 40 * root.s)
                        clip: true
                        focus: true
                        currentIndex: -1
                        keyNavigationEnabled: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.shown
                        ScrollBar.vertical: ScrollBar {
                            id: gridBar
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: Math.round(4 * root.s)
                                radius: width / 2
                                color: FamilyStyle.textTertiary
                                opacity: gridBar.size >= 1 ? 0 : gridBar.active ? 0.8 : 0.35
                            }
                        }
                        Keys.onPressed: event => root.key(event)

                        delegate: MouseArea {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool chosen: grid.currentIndex === tile.index
                            readonly property string kind: root.kindOf(tile.modelData)
                            width: grid.cellWidth
                            height: grid.cellHeight
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                grid.currentIndex = tile.index
                                grid.forceActiveFocus()
                            }
                            onDoubleClicked: root.activate(tile.modelData)

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: Math.round(3 * root.s)
                                radius: FamilyStyle.radiusTile
                                color: tile.chosen ? ColorUtils.applyAlpha(FamilyStyle.accent, 0.2) : tile.containsMouse ? FamilyStyle.fillHover : "transparent"
                                Behavior on color { ColorAnimation { duration: FamilyStyle.feedbackDuration } }
                            }
                            ClippingRectangle {
                                id: preview
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.topMargin: Math.round(9 * root.s)
                                width: parent.width - Math.round(18 * root.s)
                                height: Math.round(grid.cellWidth * 0.78 - 12 * root.s)
                                radius: FamilyStyle.radiusChip
                                color: tile.kind === "image" && thumb.status === Image.Ready ? FamilyStyle.fillQuiet : "transparent"
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: thumb.status !== Image.Ready
                                    text: root.glyphOf(tile.modelData)
                                    iconSize: Math.round((tile.kind === "folder" ? 52 : 40) * root.s)
                                    fill: tile.kind === "folder" ? 1 : 0
                                    color: tile.kind === "folder" ? FamilyStyle.accent : FamilyStyle.textTertiary
                                }
                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    visible: status === Image.Ready
                                    source: tile.kind === "image" ? root.urlOf(tile.modelData.path) : ""
                                    sourceSize.width: Math.round(256 * root.s)
                                    sourceSize.height: Math.round(256 * root.s)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                }
                            }
                            StyledText {
                                anchors.top: preview.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.topMargin: Math.round(5 * root.s)
                                anchors.leftMargin: Math.round(8 * root.s)
                                anchors.rightMargin: Math.round(8 * root.s)
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                text: tile.modelData.name
                                color: tile.chosen ? FamilyStyle.textStrong : FamilyStyle.text
                                font.family: FamilyStyle.fontMain
                                font.pixelSize: FamilyStyle.typeFootnote
                                font.weight: tile.chosen ? Font.DemiBold : Font.Normal
                            }
                        }
                    }

                    // Nothing to show.
                    Column {
                        anchors.centerIn: parent
                        visible: listing.status === FolderListModel.Ready && root.shown.length === 0
                        spacing: Math.round(6 * root.s)
                        MaterialSymbol {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.query.length > 0 ? "search_off" : "folder_open"
                            iconSize: Math.round(32 * root.s)
                            color: FamilyStyle.textTertiary
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.query.length > 0 ? Translation.tr("Nothing matches") : root.selectFolder ? Translation.tr("No folders here") : Translation.tr("Nothing to choose here")
                            color: FamilyStyle.textSecondary
                            font.family: FamilyStyle.fontMain
                            font.pixelSize: FamilyStyle.typeMeta
                        }
                    }
                }
            }

            // The choice.
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * root.s)

                // Which kind of file, when the asker offers several.
                Row {
                    visible: root.filters.length > 1
                    spacing: Math.round(4 * root.s)
                    Repeater {
                        model: root.filters
                        MouseArea {
                            id: kindChip
                            required property var modelData
                            required property int index
                            readonly property bool on: root.filterIndex === kindChip.index
                            width: kindLabel.implicitWidth + Math.round(20 * root.s)
                            height: Math.round(30 * root.s)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.filterIndex = kindChip.index
                                grid.currentIndex = -1
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: kindChip.on ? ColorUtils.applyAlpha(FamilyStyle.accent, 0.18) : kindChip.containsMouse ? FamilyStyle.fillHover : FamilyStyle.fillQuiet
                            }
                            StyledText {
                                id: kindLabel
                                anchors.centerIn: parent
                                text: kindChip.modelData.label
                                color: kindChip.on ? FamilyStyle.textStrong : FamilyStyle.textSecondary
                                font.family: FamilyStyle.fontMain
                                font.pixelSize: FamilyStyle.typeFootnote
                                font.weight: kindChip.on ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideMiddle
                    text: root.selectFolder ? root.choice.replace(Directories.homePath, "~") : root.nameOf(root.choice)
                    color: FamilyStyle.textSecondary
                    font.family: FamilyStyle.fontMain
                    font.pixelSize: FamilyStyle.typeMeta
                }
                SheetButton {
                    label: Translation.tr("Cancel")
                    onClicked: root.cancelled()
                }
                SheetButton {
                    label: root.selectFolder ? Translation.tr("Select folder") : Translation.tr("Open")
                    strong: true
                    enabled: root.choice.length > 0
                    onClicked: root.accept()
                }
            }
        }
    }

    function editPath(): void {
        pathInput.text = root.folder
        root.editingPath = true
        pathInput.forceActiveFocus()
        pathInput.selectAll()
    }

    function key(event: var): void {
        const ctrl = event.modifiers & Qt.ControlModifier
        const alt = event.modifiers & Qt.AltModifier
        if (event.key === Qt.Key_Escape) {
            if (root.query.length > 0)
                root.query = ""
            else
                root.cancelled()
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (ctrl || (root.selectFolder && !root.current))
                root.accept()
            else
                root.activate(root.current)
        } else if (event.key === Qt.Key_Backspace || (alt && event.key === Qt.Key_Up)) {
            root.up()
        } else if (alt && event.key === Qt.Key_Left) {
            root.back()
        } else if (ctrl && event.key === Qt.Key_L) {
            root.editPath()
        } else if (ctrl && event.key === Qt.Key_H) {
            root.showHidden = !root.showHidden
        } else if (ctrl && event.key === Qt.Key_F) {
            searchInput.forceActiveFocus()
        } else if (!ctrl && !alt && event.text.length === 1 && event.text.trim().length === 1) {
            root.query += event.text
            searchInput.forceActiveFocus()
            grid.currentIndex = root.shown.length > 0 ? 0 : -1
        } else {
            return
        }
        event.accepted = true
    }
}

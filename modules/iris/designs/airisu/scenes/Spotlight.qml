pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's Spotlight (board Desktop): a vermilion bar across the top, the prompt `>` and the query wide, the count in
// mono, then numbered rows: the chosen one is the gofun plate with ENTER ▸. IrisPalette keeps the search, the
// selection, the keys and the window; this is the body and what it shows.
Item {
    id: stage
    property Item palette
    readonly property alias progress: surface.progress
    readonly property alias armed: surface.armed
    readonly property Item surfaceItem: surface
    readonly property real d: Airisu.d
    function focusInput(): void { input.forceActiveFocus() }

    readonly property var rows: !stage.palette ? []
        : stage.palette.browsing ? stage.palette.suggestions.map(app => Object.assign({}, app, { rowKey: "app|" + app.appId, comment: app.verb }))
        : stage.palette.keyedResults
    readonly property int shown: Math.min(stage.rows.length, stage.palette?.resultLimit ?? 8)
    readonly property real rowHeight: Math.round(57 * stage.d)

    IrisMorphSurface {
        id: surface
        open: stage.palette?.here === true && GlobalStates.searchOpen
        settles: true
        motionSurface: "spotlight"
        fieldBacked: true
        chassisKey: "spotlight"
        color: Airisu.lacquer
        radius: 0
        originShare: IrisStyle.absorbShare
        width: Math.max(Math.round(320 * stage.d), Math.min(stage.width - 32, Math.round(640 * stage.d)))
        x: Math.round((stage.width - width) / 2)
        y: Math.max(Math.round(72 * stage.d), Math.round(stage.height * 0.18))
        height: column.implicitHeight
        onClosed: LauncherSearch.query = ""
        onSettledChanged: if (surface.settled && surface.open) stage.focusInput()
        Behavior on height {
            enabled: surface.settled
            NumberAnimation { duration: Airisu.whip; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }
        }

        MouseArea { anchors.fill: parent }

        // The vermilion bar: the body's top edge, ending where the field cuts the corner.
        Shape {
            id: sealBar
            z: 2
            width: parent.width
            height: Math.round(4 * stage.d)
            preferredRendererType: Shape.CurveRenderer
            readonly property real c: IrisStyle.fieldChamfer ? IrisStyle.chamferCut : 0
            ShapePath {
                fillColor: Airisu.seal
                strokeColor: "transparent"
                startX: 0; startY: 0
                PathLine { x: surface.width - sealBar.c; y: 0 }
                PathLine { x: surface.width - sealBar.c + Math.round(4 * stage.d); y: Math.round(4 * stage.d) }
                PathLine { x: 0; y: Math.round(4 * stage.d) }
                PathLine { x: 0; y: 0 }
            }
        }

        Column {
            id: column
            width: parent.width

            Item {
                width: parent.width
                height: Math.round(72 * stage.d)
                AText {
                    id: prompt
                    x: Airisu.pad + Math.round(2 * stage.d)
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "mono"
                    size: IrisStyle.typeTitle
                    font.weight: Font.Bold
                    color: Airisu.sealText
                    text: ">"
                }
                TextInput {
                    id: input
                    anchors.left: prompt.right
                    anchors.leftMargin: Math.round(16 * stage.d)
                    anchors.right: count.left
                    anchors.rightMargin: Math.round(16 * stage.d)
                    anchors.verticalCenter: parent.verticalCenter
                    text: LauncherSearch.query
                    color: Airisu.gofun
                    selectionColor: Airisu.seal
                    selectedTextColor: Airisu.inkOnSeal
                    font.family: Airisu.wide
                    font.weight: Font.ExtraBold
                    font.pixelSize: IrisStyle.typeDisplay + Math.round(2 * IrisStyle.typeScale)
                    font.letterSpacing: -Math.round((IrisStyle.typeDisplay + Math.round(2 * IrisStyle.typeScale)) * 0.04)
                    cursorDelegate: Rectangle {
                        width: Math.round(3 * stage.d)
                        color: Airisu.seal
                        visible: input.activeFocus
                    }
                    clip: true
                    focus: true
                    onTextChanged: if (LauncherSearch.query !== text) LauncherSearch.query = text
                    Keys.onPressed: event => stage.palette?.handleKey(event)
                    AText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text.length === 0
                        voice: "wide"
                        size: input.font.pixelSize
                        color: Airisu.quiet
                        text: Translation.tr("search")
                    }
                }
                AText {
                    id: count
                    anchors.right: parent.right
                    anchors.rightMargin: Airisu.pad + Math.round(2 * stage.d)
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "mono"
                    color: Airisu.quiet
                    text: stage.palette?.browsing ? Translation.tr("Suggestions")
                        : Translation.tr("%1 results").arg(stage.palette?.clipboardMode ? stage.palette.clipboardTotal : stage.rows.length)
                }
            }
            ARule { width: parent.width }

            AText {
                visible: stage.rows.length === 0 && !(stage.palette?.browsing ?? true)
                width: parent.width
                height: stage.rowHeight
                leftPadding: Airisu.pad + Math.round(2 * stage.d)
                verticalAlignment: Text.AlignVCenter
                color: Airisu.data
                text: stage.palette?.actionMode ? Translation.tr("Nothing by that name. Fewer letters find more.")
                    : Translation.tr("No results. Try fewer letters, or / for every action.")
            }

            Flickable {
                id: list
                width: parent.width
                height: stage.shown * stage.rowHeight + (stage.shown > 0 ? Math.round(8 * stage.d) : 0)
                contentHeight: rowColumn.implicitHeight + Math.round(8 * stage.d)
                clip: true
                interactive: contentHeight > height + 1
                boundsBehavior: Flickable.StopAtBounds
                Behavior on contentY { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.whip; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
                Connections {
                    target: stage.palette
                    function onSelectedIndexChanged(): void {
                        const top = stage.palette.selectedIndex * stage.rowHeight
                        if (top < list.contentY) list.contentY = top
                        else if (top + stage.rowHeight > list.contentY + list.height - Math.round(8 * stage.d))
                            list.contentY = Math.min(list.contentHeight - list.height, top + stage.rowHeight - list.height + Math.round(8 * stage.d))
                    }
                }
                Connections {
                    target: LauncherSearch
                    function onQueryChanged(): void { list.contentY = 0 }
                }

                // The chosen row: a gofun plate that moves with the selection in a whip.
                Rectangle {
                    visible: stage.rows.length > 0
                    y: Math.round(8 * stage.d) + Math.min(stage.palette?.selectedIndex ?? 0, stage.rows.length - 1) * stage.rowHeight
                    width: parent.width
                    height: stage.rowHeight
                    color: Airisu.gofun
                    Behavior on y { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.whip; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
                }

                Column {
                    id: rowColumn
                    y: Math.round(8 * stage.d)
                    width: parent.width
                    Repeater {
                        model: ScriptModel { objectProp: "rowKey"; values: stage.rows }
                        MouseArea {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool chosen: (stage.palette?.selectedIndex ?? -1) === row.index
                            readonly property color ink: row.chosen ? Airisu.inkOnGofun : Airisu.gofun
                            width: rowColumn.width
                            height: stage.rowHeight
                            hoverEnabled: true
                            cursorShape: stage.palette?.pointerSelectionArmed ? Qt.PointingHandCursor : Qt.BlankCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: String(row.modelData?.name ?? "")
                            onPositionChanged: event => {
                                if (stage.palette.armPointerSelection(row, event) && !row.chosen) stage.palette.selectedIndex = row.index
                            }
                            onClicked: {
                                stage.palette.pointerSelectionArmed = true
                                stage.palette.selectedIndex = row.index
                                stage.palette.executeSelected()
                            }
                            AText {
                                id: number
                                x: Airisu.pad + Math.round(2 * stage.d)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(32 * stage.d)
                                voice: "wide"
                                size: IrisStyle.typeTitleLarge
                                font.weight: Font.Black
                                color: row.chosen ? Airisu.inkOnGofun : Airisu.quiet
                                text: String(row.index + 1).padStart(2, "0")
                            }
                            Column {
                                anchors.left: number.right
                                anchors.leftMargin: Math.round(12 * stage.d)
                                anchors.right: enter.visible ? enter.left : parent.right
                                anchors.rightMargin: Airisu.pad
                                anchors.verticalCenter: parent.verticalCenter
                                AText {
                                    width: parent.width
                                    size: IrisStyle.typeTitle
                                    font.weight: Font.Bold
                                    color: row.ink
                                    text: String(row.modelData?.name ?? "").replace(/\s*\(v?\d[^)]*\)\s*$/, "")
                                }
                                AText {
                                    width: parent.width
                                    visible: text.length > 0
                                    size: IrisStyle.typeLabel
                                    font.weight: Font.Normal
                                    color: row.chosen ? Airisu.inkOnGofun : Airisu.data
                                    opacity: row.chosen ? 0.72 : 1 // iris-literal: lacquer ink at secondary strength on the gofun plate
                                    readonly property string about: String(row.modelData?.comment || row.modelData?.genericName || "")
                                    readonly property string kind: String(row.modelData?.type ?? "").toLowerCase()
                                    text: [about, kind].filter(part => part.length > 0).join(" · ")
                                }
                            }
                            AText {
                                id: enter
                                visible: row.chosen
                                anchors.right: parent.right
                                anchors.rightMargin: Airisu.pad + Math.round(2 * stage.d)
                                anchors.verticalCenter: parent.verticalCenter
                                voice: "mono"
                                font.weight: Font.Bold
                                color: Airisu.inkOnGofun
                                text: "Enter ▶"
                            }
                        }
                    }
                }
            }

            ARule { width: parent.width }
            Item {
                width: parent.width
                height: Math.round(34 * stage.d)
                AText {
                    x: Airisu.pad + Math.round(2 * stage.d)
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "mono"
                    color: Airisu.quiet
                    readonly property var prefix: Config.options?.search?.prefix ?? ({})
                    text: `${prefix.action ?? "/"} ${Translation.tr("Actions")} · ${prefix.clipboard ?? ";"} ${Translation.tr("Clipboard")} · ${prefix.math ?? "="} ${Translation.tr("Calculator")}`
                }
                AText {
                    anchors.right: parent.right
                    anchors.rightMargin: Airisu.pad + Math.round(2 * stage.d)
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "mono"
                    color: Airisu.quiet
                    text: `↑↓ ${Translation.tr("Move")}`
                }
            }
        }
    }
}

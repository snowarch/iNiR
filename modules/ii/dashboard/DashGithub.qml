import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * GitHub contributions card: total count + heatmap for the last year.
 * Fetches once per panel session (cached 1h) and only when a username is
 * configured — zero cost otherwise.
 */
DashCard {
    id: root

    readonly property string username: Config.options?.dashboard?.github?.username ?? ""
    property var weeks: [] // [[level 0–4 per day] per week]
    property int total: -1
    property double _lastFetch: 0
    property bool fetching: false
    readonly property bool hasData: total >= 0 && weeks.length > 0

    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: if (visible) refresh()
    onUsernameChanged: { total = -1; weeks = []; _lastFetch = 0; if (visible) refresh() }

    function refresh() {
        if (root.username.length === 0 || root.fetching) return
        if (Date.now() - root._lastFetch < 3600 * 1000) return
        root.fetching = true
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (!root) return  // dashboard closed mid-fetch
            root.fetching = false
            if (xhr.status !== 200) return
            try {
                const data = JSON.parse(xhr.responseText)
                const days = data?.contributions ?? []
                root.total = data?.total?.lastYear ?? days.reduce((acc, d) => acc + (d.count ?? 0), 0)
                const wk = []
                for (let i = 0; i < days.length; i += 7) {
                    wk.push(days.slice(i, i + 7).map(d => d.level ?? 0))
                }
                root.weeks = wk
                root._lastFetch = Date.now()
                heatmap.requestPaint()
            } catch (e) {
                console.log("[DashGithub] failed to parse contributions:", e)
            }
        }
        xhr.open("GET", `https://github-contributions-api.jogruber.de/v4/${encodeURIComponent(root.username)}?y=last`)
        xhr.send()
    }

    // No username configured
    ColumnLayout {
        visible: root.username.length === 0
        Layout.fillWidth: true
        spacing: 6

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "code"
            shape: MaterialShape.Shape.PixelCircle
            padding: 10
            iconSize: 32
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("Set your GitHub username in Settings to see your contributions")
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.colSubtext
            wrapMode: Text.WordWrap
        }
    }

    ColumnLayout {
        visible: root.username.length > 0
        Layout.fillWidth: true
        spacing: 4

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.hasData ? root.total.toLocaleString(Qt.locale(), 'f', 0) : (root.fetching ? "…" : "—")
            font.pixelSize: Appearance.font.pixelSize.title * 1.5
            font.family: Appearance.font.family.numbers
            font.weight: Font.DemiBold
            color: root.colAccent
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("contributions in the last year")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.colSubtext
        }

        Canvas {
            id: heatmap
            Layout.fillWidth: true
            Layout.topMargin: 8
            implicitHeight: 7 * 9 // 7 rows, 9px pitch (7px cell + 2px gap)
            visible: root.hasData

            readonly property color cellColor: root.colAccent
            readonly property color emptyColor: root.inirEverywhere ? Appearance.inir.colLayer2
                : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                : Appearance.colors.colLayer2
            onCellColorChanged: requestPaint()
            onWidthChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const wk = root.weeks
                if (!wk.length) return
                const pitch = 9
                const cell = 7
                const cols = Math.min(wk.length, Math.floor(width / pitch))
                const start = wk.length - cols
                const xOff = Math.max(0, (width - cols * pitch) / 2)
                for (let c = 0; c < cols; c++) {
                    const week = wk[start + c]
                    for (let r = 0; r < week.length; r++) {
                        const level = week[r]
                        ctx.fillStyle = level === 0
                            ? emptyColor
                            : Qt.alpha(cellColor, 0.25 + 0.75 * Math.min(level, 4) / 4)
                        ctx.beginPath()
                        ctx.roundedRect(xOff + c * pitch, r * pitch, cell, cell, 2, 2)
                        ctx.fill()
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.hasData
            text: `@${root.username}`
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.colSubtext
        }
    }
}

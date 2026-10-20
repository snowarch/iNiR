pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// General's welcome (2026-10-12, the maintainer: "que muestre una entrada ESTÉTICA a first glance… luego de los cambios
// de hoy está todo mezclado"): the desktop as its hero, then every General group as a fact you can read without opening
// it — the clock in its own format, the apps that start with you, the terminal, the family. A tile opens its group in
// the pane. One grammar for every Design: iRiS's rounded tiles with gaps, a plate Design's grid parted by fillets with
// its parts numbered and its captions in mono.
ColumnLayout {
    id: root

    readonly property real d: IrisStyle.settingsDensity
    property var screen: GlobalStates.focusedScreen
    // [{ key, title, detail, glyph, tint, action }] in the column's order.
    property var entries: []
    // A group opened from here: its fact alone, wide, as the head of its rows.
    property string only: ""
    // The facts as a grid while browsing; a Design whose page lists them with their answers beside it shows only the hero.
    property bool facts: true
    readonly property var shown: root.only.length > 0 ? root.entries.filter(entry => entry.key === root.only) : root.entries
    readonly property bool fillets: IrisStyle.plateSelection
    readonly property int columns: root.only.length > 0 ? 1 : root.width >= 620 * root.d ? 3 : 2
    // The height the page gives the welcome: what the facts leave goes to the desk (DI38: a 1080p window left a third empty).
    property real room: 0

    spacing: Math.round(14 * root.d)

    IrisWallpaperCard {
        id: welcomeCard
        visible: root.only.length === 0
        Layout.fillWidth: true
        screen: root.screen
        stageHeight: Math.round(Math.max(228 * root.d, Math.min(440 * root.d,
            root.room - (root.facts ? grid.implicitHeight : 0) - root.spacing - welcomeCard.stripRoom)))
    }

    // A Design that lists General's groups beside its page greets with the desktop and the three choices that change how
    // the whole shell looks at once, as real rows; the groups stay one click away in its column.
    readonly property var quick: ["iris.appearance.design", "iris.appearance.scheme", "iris.appearance.accent"]
        .map(path => IrisOptions.settings.find(spec => spec.path === path)).filter(spec => spec !== undefined)
    ColumnLayout {
        visible: !root.facts && root.only.length === 0
        Layout.fillWidth: true
        Layout.topMargin: Math.round(6 * root.d)
        spacing: 0
        Repeater {
            model: !root.facts && root.only.length === 0 ? root.quick : []
            IrisSetting {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spec: modelData
                last: index === root.quick.length - 1
            }
        }
    }

    // A plate Design parts its tiles with the 1 px fillet the grid shows between them; iRiS sets them apart with air.
    Rectangle {
        visible: root.facts || root.only.length > 0
        Layout.fillWidth: true
        implicitHeight: grid.implicitHeight + (root.fillets ? 2 : 0)
        color: root.fillets ? IrisStyle.hairline : "transparent"
        radius: root.fillets ? 0 : IrisStyle.radiusTile

        GridLayout {
            id: grid
            x: root.fillets ? 1 : 0
            y: root.fillets ? 1 : 0
            width: parent.width - (root.fillets ? 2 : 0)
            columns: root.columns
            rowSpacing: root.fillets ? 1 : Math.round(8 * root.d)
            columnSpacing: root.fillets ? 1 : Math.round(8 * root.d)
            Repeater {
                model: root.shown
                Fact {}
            }
        }
    }

    // What the at-login tile shows: the faces of what starts with you, managed or written in Niri's file.
    readonly property var loginIcons: {
        const apps = AppSearch.list ?? []
        const managed = (Autostart.entries ?? []).filter(entry => entry.enabled === true).map(entry => {
            if (entry.type === "command") return AppSearch.getIconSource(String(entry.command).split(/\s+/).pop().split("/").pop())
            const app = apps.find(candidate => candidate.id === String(entry.desktopId))
            return app ? AppSearch.getIconSource(app.icon, app.name) : ""
        })
        const external = apps.filter(app => Autostart.appEntrySource(app) === "external").map(app => AppSearch.getIconSource(app.icon, app.name))
        return managed.concat(external).filter(icon => String(icon).length > 0)
    }
    readonly property string terminal: String(Config.options?.apps?.terminal ?? "kitty")

    component Fact: MouseArea {
        id: fact
        required property var modelData
        required property int index
        readonly property string key: String(fact.modelData.key ?? "")
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        readonly property bool wide: root.only.length > 0
        implicitHeight: Math.round((fact.wide ? 148 : 116) * root.d)
        enabled: !fact.wide
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: String(fact.modelData.title ?? "")
        Accessible.description: figure.text
        onClicked: fact.modelData.action()

        Rectangle {
            anchors.fill: parent
            radius: root.fillets ? 0 : IrisStyle.radiusTile
            color: fact.pressed ? IrisStyle.fillActive
                : root.fillets ? (fact.containsMouse ? IrisStyle.fillHover : IrisStyle.readingCard)
                : fact.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
        }

        readonly property int pad: Math.round(14 * root.d)
        RowLayout {
            id: head
            x: fact.pad
            y: fact.pad
            width: fact.width - 2 * fact.pad
            spacing: Math.round(8 * root.d)
            IrisSquircle {
                Layout.preferredWidth: Math.round(22 * root.d)
                Layout.preferredHeight: Layout.preferredWidth
                tint: fact.modelData.tint
                glyph: String(fact.modelData.glyph ?? "settings")
            }
            IrisText {
                Layout.fillWidth: true
                text: String(fact.modelData.title ?? "")
                color: IrisStyle.monoCaptions ? IrisStyle.textSecondary : IrisStyle.subtext
                font.family: IrisStyle.monoCaptions ? IrisStyle.fontMono : IrisStyle.fontMain
                font.capitalization: IrisStyle.monoCaptions ? Font.AllUppercase : Font.MixedCase
                font.letterSpacing: IrisStyle.monoCaptions ? Math.round(IrisStyle.typeCaption * 0.14) : 0
                font.pixelSize: IrisStyle.monoCaptions ? IrisStyle.typeCaption : IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.Medium)
                elide: Text.ElideRight
            }
            IrisText {
                visible: IrisStyle.indexed
                // Its place among General's groups, the same whether the grid or the group alone is shown.
                text: IrisStyle.indexLabel(Math.max(0, root.entries.findIndex(entry => String(entry.key ?? "") === fact.key)))
                color: IrisStyle.textTertiary
                font.family: IrisStyle.fontMono
                font.pixelSize: IrisStyle.typeCaption
            }
            MaterialSymbol {
                visible: !IrisStyle.indexed && !fact.wide
                text: "chevron_right"
                iconSize: Math.round(16 * root.d)
                color: fact.containsMouse ? IrisStyle.text : IrisStyle.textTertiary
            }
        }

        // The fact itself, at the foot: its figure large, one line under it.
        ColumnLayout {
            x: fact.pad
            width: fact.width - 2 * fact.pad
            anchors.bottom: parent.bottom
            anchors.bottomMargin: fact.pad - Math.round(2 * root.d)
            spacing: Math.round(2 * root.d)
            RowLayout {
                spacing: Math.round(8 * root.d)
                IconImage {
                    visible: fact.key === "Apps"
                    implicitSize: Math.round(24 * root.d)
                    source: fact.key === "Apps" ? AppSearch.getIconSource(root.terminal) : ""
                }
                IrisText {
                    id: figure
                    Layout.fillWidth: true
                    text: fact.figure
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: fact.wide ? IrisStyle.typeDisplay : IrisStyle.typeTitleLarge
                    font.weight: IrisStyle.weight(fact.wide ? Font.Bold : Font.DemiBold)
                    font.features: { "tnum": 1 }
                    elide: Text.ElideRight
                }
                // At login: the faces of what starts, overlapping like a hand of cards, beside their count.
                Row {
                    visible: fact.key === "At login"
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -Math.round(6 * root.d)
                    Repeater {
                        model: fact.key === "At login" ? root.loginIcons.slice(0, 5) : []
                        IconImage {
                            required property string modelData
                            implicitSize: Math.round(26 * root.d)
                            source: modelData
                        }
                    }
                }
            }
            IrisText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: fact.line
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
                elide: Text.ElideRight
            }
        }

        readonly property string figure: {
            switch (fact.key) {
            case "Date & time": return DateTime.time
            case "At login": return root.loginIcons.length === 0 ? Translation.tr("Nothing yet")
                : root.loginIcons.length === 1 ? Translation.tr("1 app") : Translation.tr("%1 apps").arg(root.loginIcons.length)
            case "Apps": return root.terminal
            case "Performance": return Config.options?.performance?.lowPower ? Translation.tr("Low power") : Translation.tr("Full effects")
            case "Shell family": return IrisDesign.custom ? `iRiS · ${IrisDesign.name}` : "iRiS"
            case "@about": return ShellUpdates.localVersion.length > 0 ? "iNiR " + ShellUpdates.localVersion : "iNiR"
            case "@shortcuts": return "Super  /"
            default: return String(fact.modelData.detail ?? "")
            }
        }
        readonly property string line: {
            switch (fact.key) {
            case "Date & time": return Qt.locale().toString(DateTime.clock.date, "dddd d MMMM")
            case "Language": return Translation.tr("Every label in the shell")
            case "At login": return Translation.tr("Start with you, in order")
            case "Apps": return Translation.tr("Terminal")
            case "Settings window": return Translation.tr("Settings opens here")
            case "Performance": return Config.options?.performance?.lowPower ? Translation.tr("Glass and blur are off") : Translation.tr("Glass, blur and motion on")
            case "Shell family": return Translation.tr("The whole shell's look")
            case "@about": return SystemInfo.distroName !== "Unknown" ? SystemInfo.distroName : ""
            case "@shortcuts": return Translation.tr("Every key, by what it does")
            default: return ""
            }
        }
    }
}

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
    id: root
    spacing: 6
    property bool animateWidth: false
    property alias searchInput: searchInput
    property string searchingText

    function forceFocus() {
        searchInput.forceActiveFocus();
    }

    enum SearchPrefixType { Action, App, Clipboard, Emojis, Math, ShellCommand, WebSearch, DefaultSearch }
    readonly property var searchPrefixes: Config.options?.search?.prefix ?? {}

    property var searchPrefixType: {
        if (root.searchingText.startsWith(root.searchPrefixes.action ?? "/")) return SearchBar.SearchPrefixType.Action;
        if (root.searchingText.startsWith(root.searchPrefixes.app ?? ">")) return SearchBar.SearchPrefixType.App;
        if (root.searchingText.startsWith(root.searchPrefixes.clipboard ?? ";")) return SearchBar.SearchPrefixType.Clipboard;
        if (root.searchingText.startsWith(root.searchPrefixes.emojis ?? ":")) return SearchBar.SearchPrefixType.Emojis;
        if (root.searchingText.startsWith(root.searchPrefixes.math ?? "=")) return SearchBar.SearchPrefixType.Math;
        if (root.searchingText.startsWith(root.searchPrefixes.shellCommand ?? "$")) return SearchBar.SearchPrefixType.ShellCommand;
        if (root.searchingText.startsWith(root.searchPrefixes.webSearch ?? "?")) return SearchBar.SearchPrefixType.WebSearch;
        return SearchBar.SearchPrefixType.DefaultSearch;
    }
    
    MaterialShapeWrappedMaterialSymbol {
        id: searchIcon
        Layout.alignment: Qt.AlignVCenter
        iconSize: Appearance.font.pixelSize.huge
        shape: switch(root.searchPrefixType) {
            case SearchBar.SearchPrefixType.Action: return MaterialShape.Shape.Pill;
            case SearchBar.SearchPrefixType.App: return MaterialShape.Shape.Clover4Leaf;
            case SearchBar.SearchPrefixType.Clipboard: return MaterialShape.Shape.Gem;
            case SearchBar.SearchPrefixType.Emojis: return MaterialShape.Shape.Sunny;
            case SearchBar.SearchPrefixType.Math: return MaterialShape.Shape.PuffyDiamond;
            case SearchBar.SearchPrefixType.ShellCommand: return MaterialShape.Shape.PixelCircle;
            case SearchBar.SearchPrefixType.WebSearch: return MaterialShape.Shape.SoftBurst;
            default: return MaterialShape.Shape.Cookie7Sided;
        }
        text: switch (root.searchPrefixType) {
            case SearchBar.SearchPrefixType.Action: return "settings_suggest";
            case SearchBar.SearchPrefixType.App: return "apps";
            case SearchBar.SearchPrefixType.Clipboard: return "content_paste_search";
            case SearchBar.SearchPrefixType.Emojis: return "add_reaction";
            case SearchBar.SearchPrefixType.Math: return "calculate";
            case SearchBar.SearchPrefixType.ShellCommand: return "terminal";
            case SearchBar.SearchPrefixType.WebSearch: return "travel_explore";
            case SearchBar.SearchPrefixType.DefaultSearch: return "search";
            default: return "search";
        }
    }
    ToolbarTextField { // Search box
        id: searchInput
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 40
        focus: GlobalStates.overviewOpen
        font.pixelSize: Appearance.font.pixelSize.small
        placeholderText: Translation.tr("Search, calculate or run")
        implicitWidth: root.searchingText == "" ? Appearance.sizes.searchWidthCollapsed : Appearance.sizes.searchWidth

        Behavior on implicitWidth {
            id: searchWidthBehavior
            enabled: root.animateWidth
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }

        onTextChanged: root.searchingText = text

        Keys.onPressed: (event) => {
            if (actionModeView?.visible) {
                if (event.key === Qt.Key_Tab) {
                    actionModeView.selectedCategoryIndex = (actionModeView.selectedCategoryIndex + 1) % actionModeView.categoryList.length
                    event.accepted = true
                } else if (event.key === Qt.Key_Backtab) {
                    actionModeView.selectedCategoryIndex = (actionModeView.selectedCategoryIndex - 1 + actionModeView.categoryList.length) % actionModeView.categoryList.length
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    actionModeView.focusFirstItem()
                    event.accepted = true
                }
            } else if (event.key === Qt.Key_Down && appResults?.visible && appResults.count > 0) {
                appResults.stepSelection(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up && appResults?.visible && appResults.count > 0) {
                appResults.stepSelection(-1)
                event.accepted = true
            }
        }

        onAccepted: {
            if (actionModeView?.visible) {
                actionModeView.executeCurrentOrFirst()
                return
            }
            if (appResults.count > 0) {
                appResults.activateCurrentOrFirst()
            }
        }
    }

    IconToolbarButton {
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        onClicked: {
            GlobalStates.overviewOpen = false;
            // Use IPC to trigger region search (works for both Hyprland and Niri)
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "googleLens"]);
        }
        text: "image_search"
        StyledToolTip {
            text: Translation.tr("Google Lens")
        }
    }

    IconToolbarButton {
        id: songRecButton
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        Layout.rightMargin: 4
        toggled: SongRec.running
        onClicked: SongRec.toggleRunning()
        text: "music_cast"

        StyledToolTip {
            text: Translation.tr("Recognize music")
        }

        colText: toggled ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary) : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurfaceVariant)
        background: MaterialShape {
            RotationAnimation on rotation {
                running: songRecButton.toggled
                duration: 12000
                easing.type: Easing.Linear
                loops: Animation.Infinite
                from: 0
                to: 360
            }
            shape: {
                if (songRecButton.down) {
                    return songRecButton.toggled ? MaterialShape.Shape.Circle : MaterialShape.Shape.Square
                } else {
                    return songRecButton.toggled ? MaterialShape.Shape.SoftBurst : MaterialShape.Shape.Circle
                }
            }
            color: {
                if (songRecButton.toggled) {
                    return songRecButton.hovered ? (Appearance.inirEverywhere ? Appearance.inir.colPrimaryHover : Appearance.colors.colPrimaryHover) : (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                } else {
                    return songRecButton.hovered ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : Appearance.colors.colSurfaceContainerHigh) : (Appearance.inirEverywhere ? Appearance.inir.colLayer2 : ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh))
                }
            }
            Behavior on color {
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }
}

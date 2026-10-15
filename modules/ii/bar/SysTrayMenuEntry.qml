pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

RippleButton {
    id: root
    required property QsMenuEntry menuEntry
    property bool forceIconColumn: false
    property bool forceSpecialInteractionColumn: false
    readonly property bool hasIcon: menuEntry.icon.length > 0
    readonly property bool hasSpecialInteraction: menuEntry.buttonType !== QsMenuButtonType.None

    signal dismiss()
    signal openSubmenu(handle: QsMenuHandle)

    colBackground: menuEntry.isSeparator ? Appearance.colors.colOutlineVariant : "transparent"
    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
    colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
    enabled: !menuEntry.isSeparator
    opacity: 1

    horizontalPadding: 8
    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
    implicitHeight: menuEntry.isSeparator ? 1 : 32
    Layout.topMargin: menuEntry.isSeparator ? 2 : 0
    Layout.bottomMargin: menuEntry.isSeparator ? 2 : 0
    Layout.fillWidth: true

    Component.onCompleted: {
        if (menuEntry.isSeparator) {
            root.buttonColor = root.colBackground;
        }
    }

    releaseAction: () => { 
        if (menuEntry.hasChildren) {
            root.openSubmenu(root.menuEntry);
            return;
        }
        menuEntry.triggered();
        root.dismiss(); 
    }
    altAction: (event) => { // Not hog right-click
        event.accepted = false;
    }

    contentItem: RowLayout {
        id: contentItem
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            right: parent.right
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 6
        visible: !root.menuEntry.isSeparator

        // Interaction: checkbox or radio button
        Item {
            visible: root.hasSpecialInteraction || root.forceSpecialInteractionColumn
            implicitWidth: 16
            implicitHeight: 16

            Loader {
                anchors.fill: parent
                active: root.menuEntry.buttonType === QsMenuButtonType.RadioButton

                sourceComponent: StyledRadioButton {
                    enabled: false
                    padding: 0
                    checked: root.menuEntry.checkState === Qt.Checked
                }
            }

            Loader {
                anchors.fill: parent
                active: root.menuEntry.buttonType === QsMenuButtonType.CheckBox && root.menuEntry.checkState !== Qt.Unchecked

                sourceComponent: MaterialSymbol {
                    text: root.menuEntry.checkState === Qt.PartiallyChecked ? "check_indeterminate_small" : "check"
                    iconSize: 16
                }
            }
        }

        // Button icon
        Item {
            visible: root.hasIcon || root.forceIconColumn
            implicitWidth: 16
            implicitHeight: 16

            Loader {
                anchors.centerIn: parent
                active: root.menuEntry.icon.length > 0
                sourceComponent: IconImage {
                    asynchronous: true
                    source: root.menuEntry.icon
                    implicitSize: 16
                    mipmap: true
                }
            }
        }

        StyledText {
            id: label
            text: root.menuEntry.text
            font.pixelSize: Appearance.font.pixelSize.small
            Layout.fillWidth: true
        }

        Loader {
            active: root.menuEntry.hasChildren

            sourceComponent: MaterialSymbol {
                text: "chevron_right"
                iconSize: 16
            }
        }
    }
}

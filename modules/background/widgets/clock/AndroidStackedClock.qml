pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    required property var currentDate
    required property string timeText
    required property color timeColor
    required property color dateColor
    required property color haloColor
    required property string fontFamily
    property real scaleFactor: 1
    property real timeScale: 1
    property real dateScale: 1
    property bool showDate: true
    property bool showShadow: true
    property bool animateChange: true
    property int horizontalAlignment: Text.AlignLeft

    readonly property int layoutAlignment: root.horizontalAlignment === Text.AlignRight
        ? Qt.AlignRight
        : root.horizontalAlignment === Text.AlignHCenter
            ? Qt.AlignHCenter
            : Qt.AlignLeft
    readonly property int heroPixelSize: Math.round(
        Appearance.font.pixelSize.huge * 3.2 * root.timeScale * root.scaleFactor)
    readonly property int datePixelSize: Math.round(
        Appearance.font.pixelSize.huge * 2.2 * root.dateScale * root.scaleFactor)
    readonly property int labelPixelSize: Math.round(
        Appearance.font.pixelSize.large * root.dateScale * root.scaleFactor)

    readonly property real desiredImplicitWidth: Math.ceil(Math.max(
        weekdayLabel.visible ? weekdayLabel.implicitWidth : 0,
        dateLabel.visible ? dateLabel.implicitWidth : 0,
        heroLabel.implicitWidth))
    readonly property real desiredImplicitHeight: Math.ceil(
        (weekdayLabel.visible ? weekdayLabel.implicitHeight : 0)
        + (dateLabel.visible
            ? dateLabel.implicitHeight - Appearance.sizes.spacingSmall : 0)
        + heroLabel.implicitHeight
        - (root.showDate ? Appearance.sizes.spacingMedium : 0))

    spacing: 0

    StyledText {
        id: weekdayLabel
        visible: root.showDate
        Layout.alignment: root.layoutAlignment
        horizontalAlignment: root.horizontalAlignment
        text: Qt.locale().toString(root.currentDate, "dddd").toUpperCase()
        color: root.dateColor
        style: root.showShadow ? Text.Raised : Text.Normal
        styleColor: root.haloColor
        font {
            family: root.fontFamily
            pixelSize: root.labelPixelSize
            weight: Font.DemiBold
            letterSpacing: Appearance.zzzEverywhere ? Appearance.zzz.tracking : 0
        }
    }

    StyledText {
        id: dateLabel
        visible: root.showDate
        Layout.alignment: root.layoutAlignment
        Layout.topMargin: -Appearance.sizes.spacingSmall
        horizontalAlignment: root.horizontalAlignment
        text: Qt.locale().toString(root.currentDate, "d MMM")
        color: root.dateColor
        style: root.showShadow ? Text.Raised : Text.Normal
        styleColor: root.haloColor
        font {
            family: root.fontFamily
            pixelSize: root.datePixelSize
            weight: Font.Medium
            features: ({ "tnum": 1 })
        }
    }

    StyledText {
        id: heroLabel
        Layout.alignment: root.layoutAlignment
        Layout.topMargin: root.showDate ? -Appearance.sizes.spacingMedium : 0
        horizontalAlignment: root.horizontalAlignment
        text: root.timeText
        color: root.timeColor
        style: root.showShadow ? Text.Raised : Text.Normal
        styleColor: root.haloColor
        animateChange: root.animateChange && Appearance.animationsEnabled
        font {
            family: root.fontFamily
            pixelSize: root.heroPixelSize
            weight: Font.Bold
            features: ({ "tnum": 1 })
        }
    }
}

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

QtObject {
    id: root

    readonly property int maxContentWidth: 760

    readonly property int pageSpacing: 10

    readonly property int cardRadius: Appearance.rounding.normal
    readonly property int cardPadding: 10

    readonly property int headerRadius: Appearance.rounding.small
    readonly property int headerPaddingX: 8
    readonly property int headerPaddingY: 5

    readonly property int groupRadius: Appearance.rounding.small
    readonly property int groupPadding: 10
    readonly property int groupSpacing: 6

    readonly property color cardColor: Appearance.colors.colLayer1
    readonly property color cardBorderColor: Appearance.colors.colLayer0Border

    readonly property color groupColor: Appearance.colors.colLayer2
    readonly property color groupBorderColor: Appearance.colors.colLayer0Border
}

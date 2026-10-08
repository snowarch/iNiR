pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// The recording mark, breathing (IrisPulse).
IrisPulse {
    implicitWidth: 9 * IrisStyle.density
    implicitHeight: implicitWidth
    color: IrisStyle.danger
}

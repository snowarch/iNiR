pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.modules.inir.overlay.crosshair
import qs.modules.inir.overlay.volumeMixer
import qs.modules.inir.overlay.floatingImage
import qs.modules.inir.overlay.fpsLimiter
import qs.modules.inir.overlay.recorder
import qs.modules.inir.overlay.resources
import qs.modules.inir.overlay.notes
import qs.modules.inir.overlay.discord
import qs.modules.inir.overlay.notifications

DelegateChooser {
    id: root
    role: "identifier"

    DelegateChoice { roleValue: "crosshair"; Crosshair {} }
    DelegateChoice { roleValue: "floatingImage"; FloatingImage {} }
    DelegateChoice { roleValue: "fpsLimiter"; FpsLimiter {} }
    DelegateChoice { roleValue: "recorder"; Recorder {} }
    DelegateChoice { roleValue: "resources"; Resources {} }
    DelegateChoice { roleValue: "notes"; Notes {} }
    DelegateChoice { roleValue: "discord"; Discord {} }
    DelegateChoice { roleValue: "volumeMixer"; VolumeMixer {} }
    DelegateChoice { roleValue: "notifications"; Notifications {} }
}

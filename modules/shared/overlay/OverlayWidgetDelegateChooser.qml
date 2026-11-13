pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.modules.shared.overlay.crosshair
import qs.modules.shared.overlay.volumeMixer
import qs.modules.shared.overlay.floatingImage
import qs.modules.shared.overlay.fpsLimiter
import qs.modules.shared.overlay.recorder
import qs.modules.shared.overlay.resources
import qs.modules.shared.overlay.gamePerformance
import qs.modules.shared.overlay.notes
import qs.modules.shared.overlay.discord
import qs.modules.shared.overlay.notifications
import qs.modules.shared.overlay.clock
import qs.modules.shared.overlay.timer
import qs.modules.shared.overlay.network

DelegateChooser {
    id: root
    role: "identifier"

    DelegateChoice { roleValue: "crosshair"; Crosshair {} }
    DelegateChoice { roleValue: "floatingImage"; FloatingImage {} }
    DelegateChoice { roleValue: "fpsLimiter"; FpsLimiter {} }
    DelegateChoice { roleValue: "recorder"; Recorder {} }
    DelegateChoice { roleValue: "resources"; Resources {} }
    DelegateChoice { roleValue: "gamePerformance"; GamePerformance {} }
    DelegateChoice { roleValue: "notes"; Notes {} }
    DelegateChoice { roleValue: "discord"; Discord {} }
    DelegateChoice { roleValue: "volumeMixer"; VolumeMixer {} }
    DelegateChoice { roleValue: "notifications"; Notifications {} }
    DelegateChoice { roleValue: "clock"; Clock {} }
    DelegateChoice { roleValue: "timer"; TimerTool {} }
    DelegateChoice { roleValue: "network"; Network {} }
}

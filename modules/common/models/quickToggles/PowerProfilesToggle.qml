import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    id: root
    // without a daemon PowerProfiles is never touched (Quickshell warns on it) and the toggle says unavailable
    readonly property int profile: PowerProfilePersistence.available ? PowerProfiles.profile : PowerProfile.Balanced

    name: Translation.tr("Power Profile")
    available: PowerProfilePersistence.available
    toggled: root.profile !== PowerProfile.Balanced
    icon: switch(root.profile) {
        case PowerProfile.PowerSaver: return "energy_savings_leaf"
        case PowerProfile.Balanced: return "airwave"
        case PowerProfile.Performance: return "local_fire_department"
    }
    statusText: switch(root.profile) {
        case PowerProfile.PowerSaver: return "Power Saver"
        case PowerProfile.Balanced: return "Balanced"
        case PowerProfile.Performance: return "Performance"
    }
    
    mainAction: () => {
        if (!root.available)
            return
        if (PowerProfiles.hasPerformanceProfile) {
            switch(PowerProfiles.profile) {
                case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced
                break;
                case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance
                break;
                case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver
                break;
            }
        } else {
            PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
        }
    }
    tooltipText: Translation.tr("Click to cycle through power profiles")
}

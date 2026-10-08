// iNiR SDDM: picks the appearance theme.conf names. sync-pixel-sddm.py writes it from the lock.loginScreen
// setting, so switching needs no root: this directory belongs to the user who installed it.
import QtQuick 2.15

Item {
    Loader {
        anchors.fill: parent
        focus: true
        source: String(config.appearance || "classic") === "iris" ? "IrisLogin.qml" : "ClassicLogin.qml"
        // A login screen that fails to load locks people out: fall back to the Classic one.
        onStatusChanged: if (status === Loader.Error && String(source).indexOf("ClassicLogin.qml") < 0) source = "ClassicLogin.qml"
    }
}

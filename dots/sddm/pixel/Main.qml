// iNiR SDDM: picks the look theme.conf names. inir-accel sddm-sync writes it from lock.loginScreen (Classic, or the
// look a family declares: iRiS, Waffle) and lock.loginStyle (iRiS's Cover, Frame or Lens), so switching needs no
// root: this directory belongs to the user who installed it. A look this theme lacks shows Classic.
import QtQuick 2.15

Item {
    readonly property var irisStyles: ({ cover: "LoginCover.qml", frame: "LoginFrame.qml", lens: "LoginLens.qml" })
    readonly property string look: String(config.appearance || "classic")
    Loader {
        anchors.fill: parent
        focus: true
        source: parent.look === "iris" ? parent.irisStyles[String(config.irisLoginStyle || "lens")] || "LoginLens.qml"
            : parent.look === "waffle" ? "WaffleLogin.qml"
            : "ClassicLogin.qml"
        // A login screen that fails to load locks people out: fall back to the Classic one.
        onStatusChanged: if (status === Loader.Error && String(source).indexOf("ClassicLogin.qml") < 0) source = "ClassicLogin.qml"
    }
}

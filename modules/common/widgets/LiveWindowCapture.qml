import QtQuick
import Quickshell
import qs.services

// A window's live picture where the runtime can stream one (qs-rs on niri, through niri's ScreenCast), laid over the
// cached still its caller keeps underneath: the still shows at once and the stream covers it from its first frame.
// Each live view holds a compositor session, so `active` follows whether the surface is on screen.
Item {
    id: root
    property int windowId: -1
    property bool active: true
    property bool live: true
    property int fillMode: Image.PreserveAspectCrop
    // A stream starts only once the view has wanted it this long: a surface that opens for a moment, or a delegate
    // rebuilt while its list settles, keeps the still instead of opening and closing a compositor session each time.
    property int settleMs: 250
    // The view reads this instead of `live`: a recording freezes the streams without closing them.
    readonly property bool effectiveLive: root.live && !RecorderStatus.isRecording
    // Whether a stream is drawing: a caller may stop refreshing its still while it is.
    readonly property bool streaming: capture.item?.streaming ?? false

    // The view sets a property only qs-rs has, so it lives in its own file and is compiled only where it exists.
    readonly property bool supported: CompositorService.isNiri
        && SystemInfo.runtimeHas(["niri-window-capture"])
    // A game gets the GPU to itself: the still stays.
    readonly property bool wanted: root.supported && root.active && root.windowId >= 0 && !GameMode.active
    property bool settled: false

    onWantedChanged: {
        root.settled = false
        if (root.wanted) settle.restart()
        else settle.stop()
    }
    Component.onCompleted: if (root.wanted) settle.start()

    Timer {
        id: settle
        interval: root.settleMs
        onTriggered: root.settled = true
    }

    Loader {
        id: capture
        anchors.fill: parent
        active: root.wanted && root.settled
        source: "LiveWindowCaptureView.qml"
        onLoaded: item.host = root
    }
}

import Quickshell

// Loaded by IrisBlurRegion only on qs-rs (feature "field-region"): FieldRegion exists nowhere else.
FieldRegion {
    required property var owner
    bodies: owner.nativeBodies
    framed: owner.framed
    joinsFrame: owner.joinsFrame
    windowWidth: owner.windowWidth
    windowHeight: owner.windowHeight
    band: owner.band
    cornerRadius: owner.cornerRadius
    chamfer: owner.chamfer
    inset: owner.inset
    wave: owner.edgeWave
    waveClock: owner.waveClock
}

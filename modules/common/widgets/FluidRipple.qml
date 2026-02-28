import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/*
 * Copyright (C) 2021 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Ported to QtQuick/Quickshell by Gemini CLI.
 */

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

Item {
    id: root
    
    // --- Configuration ---
    property color color: Appearance.colors.colPrimary
    property int duration: Config.options?.background?.effects?.ripple?.rippleDuration ?? 3000
    
    // --- State ---
    property real progress: 0
    property real centerX: 0.5
    property real centerY: 0.5
    property bool playing: progress > 0 && progress < 1.0

    // Normalized distance calculation to ensure consistent expansion speed
    readonly property real _maxDistance: {
        if (width <= 0 || height <= 0) return 1.0;
        const aspect = width / height;
        const dx0 = centerX * aspect;
        const dx1 = (1.0 - centerX) * aspect;
        const dy0 = centerY;
        const dy1 = (1.0 - centerY);
        
        return Math.max(
            Math.sqrt(dx0*dx0 + dy0*dy0),
            Math.sqrt(dx1*dx1 + dy0*dy0),
            Math.sqrt(dx0*dx0 + dy1*dy1),
            Math.sqrt(dx1*dx1 + dy1*dy1)
        );
    }

    function spawn(x, y) {
        if (x !== undefined && y !== undefined) {
            centerX = x / width;
            centerY = y / height;
        } else {
            centerX = 0.5;
            centerY = 0.5;
        }
        anim.restart();
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent
        visible: root.playing
        
        property color color: root.color
        // Map 0-1 animation progress to the actual physical distance needed
        property real progress: root.progress * root._maxDistance
        property point center: Qt.point(root.centerX, root.centerY)
        property real aspect: width / height

        fragmentShader: "FluidRipple.qsb"
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        from: 0
        to: 1.0
        duration: root.duration
        easing.type: Easing.OutCubic
        onFinished: root.progress = 0
    }
}

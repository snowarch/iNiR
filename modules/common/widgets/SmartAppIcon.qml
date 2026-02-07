import QtQuick
import org.kde.kirigami as Kirigami
import Quickshell
import qs.modules.waffle.looks
import qs.services

/**
 * Intelligent icon component that handles:
 * 1. Absolute paths (Electron apps, etc.) via Image
 * 2. System theme icons via Kirigami.Icon
 * 3. Fluent assets (if available) via direct path
 * 4. Fallback gracefully
 */
Item {
    id: root

    // === API ===
    property string icon: ""
    property string fallback: "application-x-executable"
    property bool filled: false           // Use filled variant for fluent icons
    property int iconSize: 24
    property alias implicitSize: root.iconSize
    
    // Style control
    property bool monochrome: false       // If true, applies 'color' as mask. If false, renders original colors.
    property color color: Looks.colors.fg // Used only if monochrome=true
    
    // Fluent icon mode - only try fluent asset paths when true (set by FluentIcon)
    property bool useFluent: false

    // === Layout ===
    implicitWidth: iconSize
    implicitHeight: iconSize


    // === Logic ===
    readonly property string resolvedSource: AppSearch.resolveIcon(root.icon, root.fallback)
    readonly property bool isFileUrl: resolvedSource.startsWith("file://")
    
    // Error handling state
    property bool _imageError: false

    Loader {
        anchors.fill: parent
        sourceComponent: {
            if (root._imageError) return fallbackKind
            if (root.isFileUrl) return imageKind
            return iconKind
        }
    }

    // 1. Direct Image (Web-based, absolute paths, etc.)
    Component {
        id: imageKind
        Image {
            source: root.resolvedSource
            sourceSize.width: root.iconSize
            sourceSize.height: root.iconSize
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            
            // If monochrome, we need a shader or native masking. 
            // Quickshell/Qt 6 Image doesn't support 'color' overlay directly without MultiEffect.
            // For now, we assume images (icons) are mostly full-color apps.
            // If monochrome is requested for an Image, we rely on layer effect?
            // Expensive. Use OpacityMask if strictly needed, but rare for App Icons.
            
            onStatusChanged: {
                if (status === Image.Error) {
                    print(`[SmartAppIcon] Failed to load image: ${root.resolvedSource}`)
                    root._imageError = true
                }
            }
        }
    }

    // 2. System/Fluent Icon (SVG/Theme)
    Component {
        id: iconKind
        Kirigami.Icon {
            source: {
                // Only try fluent path if explicitly requested
                if (root.useFluent && root.icon && !root.icon.includes("/") && !root.icon.includes(".")) {
                    return `${Looks.iconsPath}/${root.icon}${root.filled ? "-filled" : ""}.svg`
                }
                return root.resolvedSource
            }
            
            fallback: root.resolvedSource // Falls back to system theme if file not found
            
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize
            
            // Masking behavior
            isMask: root.monochrome
            color: root.monochrome ? root.color : "transparent"
        }
    }
    
    // 3. Last Resort Fallback
    Component {
        id: fallbackKind
        Kirigami.Icon {
            source: root.fallback
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize
            isMask: root.monochrome
            color: root.monochrome ? root.color : "transparent"
        }
    }
}

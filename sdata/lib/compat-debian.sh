#!/bin/bash
# sdata/lib/compat-debian.sh
# Fix compatibility issues for Debian/Ubuntu (older Qt/QML stack)
# This script "downgrades" the QML code syntax to be compatible with older Qt versions

echo -e "\033[0;34m[compat]: Applying compatibility fixes for Debian/Ubuntu...\033[0m"

TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target directory not found: $TARGET_DIR"
  exit 1
fi

# 1. Strip type annotations from JS functions in QML
# function foo(arg: type): type -> function foo(arg)
find "$TARGET_DIR" -name '*.qml' -exec sed -i -E 's/function ([a-zA-Z0-9_]+)\(([^)]*)\): [a-zA-Z0-9_<>]+ \{/function \1(\2) {/g' {} \;

# 2. Strip type annotations from function arguments inside JS functions
# arg: type -> arg
# This regex matches "arg: Type" followed by comma or close parenthesis
find "$TARGET_DIR" -name '*.qml' -exec sed -i -E 's/([a-zA-Z0-9_]+): [a-zA-Z0-9_<>]+([,)])/\1\2/g' {} \;

# 3. Fix signal definitions (Qt 6.5+ syntax "signal name(type arg)" is not supported everywhere, needs "signal name(var arg)" or older syntax)
# signal foo(arg: type) -> signal foo(var arg)
find "$TARGET_DIR" -name '*.qml' -exec sed -i -E 's/signal ([a-zA-Z0-9_]+)\(([a-zA-Z0-9_]+)\)/signal \1(var \2)/g' {} \;
find "$TARGET_DIR" -name '*.qml' -exec sed -i -E 's/signal ([a-zA-Z0-9_]+)\(([a-zA-Z0-9_]+), ([a-zA-Z0-9_]+)\)/signal \1(var \2, var \3)/g' {} \;

# 4. Patch StyledRectangularShadow to use MultiEffect (fallback) if RectangularShadow is missing
# (This overwrites the file in the target directory only)
cat > "$TARGET_DIR/modules/common/widgets/StyledRectangularShadow.qml" <<EOF
import QtQuick
import QtQuick.Effects
import qs.modules.common

// Fallback implementation using MultiEffect for systems where RectangularShadow is missing
Item {
    id: root
    required property var target
    
    // Properties matching RectangularShadow API
    property real radius: target.radius
    property real blur: 0.9 * Appearance.sizes.elevationMargin
    property vector2d offset: Qt.vector2d(0.0, 1.0)
    property real spread: 1
    property color color: Appearance.colors.colShadow
    property bool cached: true
    
    visible: Appearance.effectsEnabled
    anchors.fill: target
    z: -1 // Behind target
    
    // Shadow source (rectangle matching target)
    Rectangle {
        id: sourceRect
        anchors.fill: parent
        radius: root.radius
        color: root.color
        visible: false
    }

    MultiEffect {
        source: sourceRect
        anchors.fill: sourceRect
        shadowEnabled: true
        shadowColor: root.color
        shadowBlur: 0.5
        shadowVerticalOffset: root.offset.y
        shadowHorizontalOffset: root.offset.x
        visible: true
    }
}
EOF

# 5. Fix DelegateChoice import (needs Qt.labs.qmlmodels in some versions)
find "$TARGET_DIR" -name '*.qml' -print0 | xargs -0 grep -l 'DelegateChoice' | xargs sed -i '2i import Qt.labs.qmlmodels'

echo -e "\033[0;32m[compat]: Compatibility fixes applied.\033[0m"

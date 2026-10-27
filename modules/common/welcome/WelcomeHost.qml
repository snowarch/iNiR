pragma Singleton

import QtQuick
import Quickshell

// The wizard, set before its window exists, so pages and widgets in their own files read it as `root`.
Singleton {
    property var wizard: null
}

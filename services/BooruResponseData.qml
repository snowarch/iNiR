import qs.modules.common
import QtQuick;

/**
 * A booru response.
 */
QtObject {
    property string provider
    property var tags
    property var page
    property var images
    property string message
    property int lastPage: 0
    property int total: 0
}

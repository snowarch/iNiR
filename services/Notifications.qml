pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.services

/**
 * Provides extra features not in Quickshell.Services.Notifications:
 *  - Persistent storage
 *  - Popup notifications, with timeout
 *  - Notification groups by app
 */
Singleton {
	id: root
    component Notif: QtObject {
        id: wrapper
        required property int notificationId // Could just be `id` but it conflicts with the default prop in QtObject
        property Notification notification
        property list<var> actions: notification?.actions.map((action) => ({
            "identifier": action.identifier,
            "text": action.text,
        })) ?? []
        property bool popup: false
        property bool isTransient: notification?.hints.transient ?? false
        property string appIcon: notification?.appIcon ?? ""
        property string appName: notification?.appName ?? ""
        property string body: notification?.body ?? ""
        property string image: notification?.image ?? ""
        property string summary: notification?.summary ?? ""
        property double time
        property string urgency: notification?.urgency.toString() ?? "normal"
        property Timer timer

        onNotificationChanged: {
            if (notification === null) {
                root.discardNotification(notificationId);
            }
        }
    }

    function notifToJSON(notif) {
        return {
            "notificationId": notif.notificationId,
            "actions": notif.actions,
            "appIcon": notif.appIcon,
            "appName": notif.appName,
            "body": notif.body,
            "image": notif.image,
            "summary": notif.summary,
            "time": notif.time,
            "urgency": notif.urgency,
        }
    }
    function notifToString(notif) {
        return JSON.stringify(notifToJSON(notif), null, 2);
    }

    component NotifTimer: Timer {
        required property int notificationId
        interval: 7000
        running: true
        onTriggered: () => {
            const index = root.list.findIndex((notif) => notif.notificationId === notificationId);
            if (index === -1) {
                console.warn("[Notifications] Timer triggered for non-existent notification ID: " + notificationId);
                destroy()
                return
            }
            const notifObject = root.list[index];
            console.log("[Notifications] Timer triggered for ID: " + notificationId + ", transient: " + notifObject.isTransient);
            if (notifObject.isTransient) root.discardNotification(notificationId);
            else root.timeoutNotification(notificationId);
            destroy()
        }
    }

    // Estado de silencio / "No molestar" - synced with config
    property bool silent: false
    
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                root.silent = Config.options?.notifications?.silent ?? false
            }
        }
        function onOptionsChanged() {
            root.silent = Config.options?.notifications?.silent ?? false
        }
    }
    
    onSilentChanged: {
        if (Config.ready && Config.options?.notifications?.silent !== silent) {
            Config.setNestedValue("notifications.silent", silent)
        }
    }
    property int unread: 0
    property var filePath: Directories.notificationsPath
    property list<Notif> list: []
    // Cached lists - updated via debounce timer
    property var popupList: []
    property var _cachedGroupsByAppName: ({})
    property var _cachedPopupGroupsByAppName: ({})
    property var _cachedAppNameList: []
    property var _cachedPopupAppNameList: []
    property bool _groupsDirty: true
    
    property bool popupInhibited: (GlobalStates?.sidebarRightOpen ?? false) || (GlobalStates?.waffleNotificationCenterOpen ?? false) || silent
    property var latestTimeForApp: ({})
    
    // Debounce timer for group updates (16ms = 1 frame at 60fps)
    Timer {
        id: groupUpdateTimer
        interval: 16
        onTriggered: root._updateGroups()
    }
    Component {
        id: notifComponent
        Notif {}
    }
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    function stringifyList(list) {
        return JSON.stringify(list.map((notif) => notifToJSON(notif)), null, 2);
    }
    
    onListChanged: {
        root._groupsDirty = true
        groupUpdateTimer.restart()
    }
    
    function _updateGroups() {
        if (!_groupsDirty) return
        _groupsDirty = false
        
        // Update popupList
        root.popupList = root.list.filter((notif) => notif.popup)
        
        // Update latest time for each app
        const newLatestTime = {}
        root.list.forEach((notif) => {
            if (!newLatestTime[notif.appName] || notif.time > newLatestTime[notif.appName]) {
                newLatestTime[notif.appName] = notif.time
            }
        })
        root.latestTimeForApp = newLatestTime
        
        // Update groups
        root._cachedGroupsByAppName = _groupsForListOptimized(root.list)
        root._cachedPopupGroupsByAppName = _groupsForListOptimized(root.popupList)
        root._cachedAppNameList = _appNameListForGroups(root._cachedGroupsByAppName)
        root._cachedPopupAppNameList = _appNameListForGroups(root._cachedPopupGroupsByAppName)
    }
    
    function _groupsForListOptimized(list) {
        const groups = {}
        for (let i = 0; i < list.length; i++) {
            const notif = list[i]
            const appName = notif.appName
            if (!groups[appName]) {
                groups[appName] = {
                    appName: appName,
                    appIcon: notif.appIcon,
                    notifications: [],
                    time: 0,
                    hasCritical: false  // Pre-calculate hasCritical
                }
            }
            groups[appName].notifications.push(notif)
            groups[appName].time = root.latestTimeForApp[appName] || notif.time
            // Check critical urgency
            if (notif.urgency === "Critical") {
                groups[appName].hasCritical = true
            }
        }
        return groups
    }
    
    function _appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => groups[b].time - groups[a].time)
    }

    // Public API - use cached values
    property var groupsByAppName: _cachedGroupsByAppName
    property var popupGroupsByAppName: _cachedPopupGroupsByAppName
    property var appNameList: _cachedAppNameList
    property var popupAppNameList: _cachedPopupAppNameList

    // Rate limiting sencillo para evitar spam de notificaciones
    property double _lastIngressSec: 0
    property int _ingressCountThisSec: 0
    property int maxIngressPerSecond: 20

    // Quickshell's notification IDs starts at 1 on each run, while saved notifications
    // can already contain higher IDs. This is for avoiding id collisions
    property int idOffset
    signal initDone();
    signal notify(notification: var);
    signal discard(id: int);
    signal discardAll();
    signal timeout(id: var);

    function _nowSec() {
        return Date.now() / 1000.0;
    }

    function _ingressAllowed(notification) {
        const t = _nowSec();
        if (t - _lastIngressSec >= 1.0) {
            _lastIngressSec = t;
            _ingressCountThisSec = 0;
        }
        _ingressCountThisSec += 1;

        if (notification.urgency === NotificationUrgency.Critical)
            return true;

        return _ingressCountThisSec <= maxIngressPerSecond;
    }

    function _timeoutForNotification(notification) {
        const ignoreApp = Config.options?.notifications?.ignoreAppTimeout ?? false;
        
        // 1) La app define un timeout explícito (> 0): respetarlo solo si no ignoramos
        if (!ignoreApp && notification.expireTimeout > 0) {
            return notification.expireTimeout;
        }

        // 2) expireTimeout == 0 => "no expira" según spec freedesktop (solo si no ignoramos)
        if (!ignoreApp && notification.expireTimeout === 0) {
            return 0;
        }

        // 3) Usar defaults por urgencia
        let urgencyStr = "normal";
        if (notification.urgency && notification.urgency.toString) {
            urgencyStr = notification.urgency.toString();
        }

        if (urgencyStr === "Low") {
            return Config.options?.notifications?.timeoutLow ?? 5000;
        } else if (urgencyStr === "Critical") {
            // Por defecto críticas quedan pegadas (0 = nunca auto-ocultar)
            return Config.options?.notifications?.timeoutCritical ?? 0;
        }

        // Normal / desconocida
        return Config.options?.notifications?.timeoutNormal ?? 7000;
    }

	NotificationServer {
        id: notifServer
        // actionIconsSupported: true
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: (notification) => {
            if (!_ingressAllowed(notification)) {
                return;
            }

            notification.tracked = true
            const newNotifObject = notifComponent.createObject(root, {
                "notificationId": notification.id + root.idOffset,
                "notification": notification,
                "time": Date.now(),
            });
			root.list = [...root.list, newNotifObject];

            // Sonido de notificación opcional
            if (Config.options.sounds.notifications) {
                var soundName = "message-new-instant";
                if (notification.urgency === NotificationUrgency.Critical) {
                    soundName = "dialog-warning";
                }
                Audio.playSystemSound(soundName);
            }

            // Popup
            if (!root.popupInhibited) {
                newNotifObject.popup = true;

                const timeout = _timeoutForNotification(notification);
                if (timeout !== 0) {
                    newNotifObject.timer = notifTimerComponent.createObject(root, {
                        "notificationId": newNotifObject.notificationId,
                        "interval": timeout,
                    });
                }

                root.unread++;
            }
            root.notify(newNotifObject);
            // console.log(notifToString(newNotifObject));
            notifFileView.setText(stringifyList(root.list));
        }
    }

    function markAllRead() {
        root.unread = 0;
    }

    function discardNotification(id) {
        console.log("[Notifications] Discarding notification with ID: " + id);
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex((notif) => notif.id + root.idOffset === id);
        if (index !== -1) {
            root.list.splice(index, 1);
            notifFileView.setText(stringifyList(root.list));
            triggerListChange()
        }
        if (notifServerIndex !== -1) {
            notifServer.trackedNotifications.values[notifServerIndex].dismiss()
        }
        root.discard(id); // Emit signal
    }

    function discardAllNotifications() {
        root.list = []
        triggerListChange()
        notifFileView.setText(stringifyList(root.list));
        notifServer.trackedNotifications.values.forEach((notif) => {
            notif.dismiss()
        })
        root.discardAll();
    }

    function cancelTimeout(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (index !== -1 && root.list[index] != null && root.list[index].timer != null) {
            root.list[index].timer.stop();
        }
    }

    function timeoutNotification(id) {
        const index = root.list.findIndex((notif) => notif.notificationId === id);
        if (root.list[index] != null)
            root.list[index].popup = false;
        triggerListChange();
        root.timeout(id);
    }

    function timeoutAll() {
        root.popupList.forEach((notif) => {
            root.timeout(notif.notificationId);
        })
        root.popupList.forEach((notif) => {
            notif.popup = false;
        });
        triggerListChange();
    }

    function attemptInvokeAction(id, notifIdentifier) {
        console.log("[Notifications] Attempting to invoke action with identifier: " + notifIdentifier + " for notification ID: " + id);
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex((notif) => notif.id + root.idOffset === id);
        console.log("Notification server index: " + notifServerIndex);
        if (notifServerIndex !== -1) {
            const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex];
            const action = notifServerNotif.actions.find((action) => action.identifier === notifIdentifier);
            // console.log("Action found: " + JSON.stringify(action));
            action.invoke()
        } 
        else {
            console.log("Notification not found in server: " + id)
        }
        root.discardNotification(id);
    }

    function triggerListChange() {
        root._groupsDirty = true
        root._updateGroups()
    }

    function refresh() {
        notifFileView.reload()
    }

    // Enviar algunas notificaciones de prueba para previsualizar posición/sonido
    function sendTestNotifications() {
        const tests = [
            {
                summary: "Notification Position Test",
                body: "ii test notification 1 of 3 ~ Hi there!",
                icon: "preferences-system"
            },
            {
                summary: "Second Test",
                body: "ii notification 2 of 3 ~ Check it out!",
                icon: "applications-graphics"
            },
            {
                summary: "Third Test",
                body: "ii notification 3 of 3 ~ Enjoy!",
                icon: "face-smile"
            }
        ];

        for (let i = 0; i < tests.length; ++i) {
            const t = tests[i];
            Quickshell.execDetached([
                "notify-send",
                "-h", "int:transient:1",
                "-a", "Quickshell ii",
                "-i", t.icon,
                t.summary,
                t.body,
            ]);
        }
    }

    IpcHandler {
        target: "notifications"

        function test(): void {
            root.sendTestNotifications()
        }

        function clearAll(): void {
            root.discardAllNotifications()
        }

        function toggleSilent(): void {
            root.silent = !root.silent
        }
    }

    Component.onCompleted: {
        refresh()
    }

    FileView {
        id: notifFileView
        path: Qt.resolvedUrl(filePath)
        onLoaded: {
            const fileContents = notifFileView.text()
            root.list = JSON.parse(fileContents).map((notif) => {
                return notifComponent.createObject(root, {
                    "notificationId": notif.notificationId,
                    "actions": [], // Notification actions are meaningless if they're not tracked by the server or the sender is dead
                    "appIcon": notif.appIcon,
                    "appName": notif.appName,
                    "body": notif.body,
                    "image": notif.image,
                    "summary": notif.summary,
                    "time": notif.time,
                    "urgency": notif.urgency,
                });
            });
            // Find largest notificationId
            let maxId = 0
            root.list.forEach((notif) => {
                maxId = Math.max(maxId, notif.notificationId)
            })

            console.log("[Notifications] File loaded")
            root.idOffset = maxId
            root.initDone()
        }
        onLoadFailed: (error) => {
            if(error == FileViewError.FileNotFound) {
                console.log("[Notifications] File not found, creating new file.")
                root.list = []
                notifFileView.setText(stringifyList(root.list));
            } else {
                console.log("[Notifications] Error loading file: " + error)
            }
        }
    }
}

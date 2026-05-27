pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property bool packageManagerRunning: false
    property bool downloadRunning: false

    function refresh(): void {
        packageManagerRunning = false;
        downloadRunning = false;

        detectPackageManagerProc.running = false;
        detectPackageManagerProc.running = true;

        detectDownloadProc.running = false;
        detectDownloadProc.running = true;
    }

    Process {
        id: detectPackageManagerProc
        command: ["/usr/bin/pidof", "pacman", "yay", "paru", "dnf", "zypper", "apt", "apx", "xbps", "flatpak", "snap", "apk", "yum", "epsi", "pikman"]
        onExited: (exitCode, exitStatus) => {
            root.packageManagerRunning = (exitCode === 0);
        }
    }

    Process {
        id: detectDownloadProc
        command: ["/usr/bin/pidof", "curl", "wget", "aria2c", "yt-dlp"]
        onExited: (exitCode, exitStatus) => {
            root.downloadRunning = (exitCode === 0);
        }
    }
}

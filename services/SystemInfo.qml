pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Provides some system info: distro, username.
 */
Singleton {
    id: root
    property string distroName: "Unknown"
    property string distroId: "unknown"
    property string distroIcon: "linux-symbolic"
    property string username: "user"
    property string displayName: ""
    property string homeUrl: ""
    property string documentationUrl: ""
    property string supportUrl: ""
    property string bugReportUrl: ""
    property string privacyPolicyUrl: ""
    property string logo: ""
    property string desktopEnvironment: ""
    property string windowingSystem: ""

    function refreshIdentity(): void {
        if (getUsername.running || getDisplayName.running)
            return
        getUsername.running = true
    }

    Timer {
        triggeredOnStart: true
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            refreshIdentity()
            getDesktopEnvironment.running = true
            fileOsRelease.reload()
            const textOsRelease = fileOsRelease.text()

            // Extract the friendly name (PRETTY_NAME field, fallback to NAME)
            const prettyNameMatch = textOsRelease.match(/^PRETTY_NAME="(.+?)"/m)
            const nameMatch = textOsRelease.match(/^NAME="(.+?)"/m)
            distroName = prettyNameMatch ? prettyNameMatch[1] : (nameMatch ? nameMatch[1].replace(/Linux/i, "").trim() : "Unknown")

            // Extract the ID
            const idMatch = textOsRelease.match(/^ID="?(.+?)"?$/m)
            distroId = idMatch ? idMatch[1] : "unknown"

            // Extract additional URLs and logo
            const homeUrlMatch = textOsRelease.match(/^HOME_URL="(.+?)"/m)
            homeUrl = homeUrlMatch ? homeUrlMatch[1] : ""
            const documentationUrlMatch = textOsRelease.match(/^DOCUMENTATION_URL="(.+?)"/m)
            documentationUrl = documentationUrlMatch ? documentationUrlMatch[1] : ""
            const supportUrlMatch = textOsRelease.match(/^SUPPORT_URL="(.+?)"/m)
            supportUrl = supportUrlMatch ? supportUrlMatch[1] : ""
            const bugReportUrlMatch = textOsRelease.match(/^BUG_REPORT_URL="(.+?)"/m)
            bugReportUrl = bugReportUrlMatch ? bugReportUrlMatch[1] : ""
            const privacyPolicyUrlMatch = textOsRelease.match(/^PRIVACY_POLICY_URL="(.+?)"/m)
            privacyPolicyUrl = privacyPolicyUrlMatch ? privacyPolicyUrlMatch[1] : ""
            const logoFieldMatch = textOsRelease.match(/^LOGO="?(.+?)"?$/m)
            logo = logoFieldMatch ? logoFieldMatch[1] : ""

            // Update the distroIcon property based on distroId
            switch (distroId) {
                case "arch": distroIcon = "arch-symbolic"; break;
                case "endeavouros": distroIcon = "endeavouros-symbolic"; break;
                case "cachyos": distroIcon = "cachyos-symbolic"; break;
                case "nixos": distroIcon = "nixos-symbolic"; break;
                case "fedora": distroIcon = "fedora-symbolic"; break;
                case "linuxmint":
                case "ubuntu":
                case "zorin":
                case "popos": distroIcon = "ubuntu-symbolic"; break;
                case "debian":
                case "raspbian":
                case "kali": distroIcon = "debian-symbolic"; break;
                case "funtoo":
                case "gentoo": distroIcon = "gentoo-symbolic"; break;
                default: distroIcon = "linux-symbolic"; break;
            }
            if (textOsRelease.toLowerCase().includes("nyarch")) {
                distroIcon = "nyarch-symbolic"
            }

            if (logo.trim().length === 0) {
                logo = distroIcon
            }

        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: refreshIdentity()
    }

    Process {
        id: getUsername
        command: ["/usr/bin/id", "-un"]
        stdout: StdioCollector {
            id: usernameCollector
            onStreamFinished: {
                const name = usernameCollector.text.trim() || Quickshell.env("USER") || root.username
                root.username = name
                getDisplayName.command = ["/usr/bin/getent", "passwd", name]
                getDisplayName.running = true
            }
        }
    }

    Process {
        id: getDisplayName
        running: false
        command: ["/usr/bin/getent", "passwd", root.username]
        stdout: StdioCollector {
            id: displayNameCollector
            onStreamFinished: {
                const passwdLine = displayNameCollector.text.trim().split("\n")[0] ?? ""
                const fields = passwdLine.split(":")
                const gecosField = fields.length >= 5 ? fields[4] : ""
                const name = gecosField.split(",")[0].trim()
                root.displayName = name.length > 0 ? name : root.username
            }
        }
    }

    Process {
        id: getDesktopEnvironment
        running: false
        command: ["/usr/bin/bash", "-c", "echo $XDG_CURRENT_DESKTOP,$WAYLAND_DISPLAY"]
        stdout: StdioCollector {
            id: deCollector
            onStreamFinished: {
                const [desktop, wayland] = deCollector.text.split(",")
                root.desktopEnvironment = desktop.trim()
                root.windowingSystem = wayland.trim().length > 0 ? "Wayland" : "X11" // Are there others? 🤔
            }
        }
    }

    FileView {
        id: fileOsRelease
        path: "/etc/os-release"
    }
}
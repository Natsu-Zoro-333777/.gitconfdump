pragma Singleton

import QtQuick
import Quickshell

Singleton {
	id: root

	property bool launcherOpen: false
	property string launcherMonitor: ""
	property bool clipboardOpen: false
	property bool centerOpen: false
	// Screen the control center opens on. Empty means the focused niri output.
	property string centerMonitor: ""
	property string centerPage: "main"
	property string wifiTarget: ""
	property bool mullvadOn: false

	function closeTransient() {
		launcherOpen = false
		launcherMonitor = ""
		clipboardOpen = false
		centerOpen = false
		centerMonitor = ""
		centerPage = "main"
		wifiTarget = ""
	}

	function toggleLauncher(monitor) {
		const open = !launcherOpen
		closeTransient()
		if (!open)
			return
		launcherMonitor = monitor || ""
		launcherOpen = true
	}

	function toggleClipboard() {
		const open = !clipboardOpen
		closeTransient()
		clipboardOpen = open
	}

	function toggleCenter(monitor) {
		const open = !centerOpen
		closeTransient()
		centerPage = "main"
		centerMonitor = open ? (monitor || "") : ""
		centerOpen = open
	}

	function openCenter(page, monitor) {
		launcherOpen = false
		clipboardOpen = false
		centerPage = page || "main"
		wifiTarget = ""
		centerMonitor = monitor || ""
		centerOpen = true
	}

	signal lockRequested()

	function requestLock() {
		closeTransient()
		lockRequested()
	}
}

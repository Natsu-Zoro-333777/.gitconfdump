pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Replaces usb-notify.sh: udev add/remove of a top-level USB device.
Singleton {
	id: root

	property var fields: ({})
	property bool open: false

	function label(event, databaseKey, rawKey, fallback) {
		const database = (event[databaseKey] || "").trim()
		if (database)
			return database
		const raw = (event[rawKey] || "").trim().replace(/_/g, " ")
		return raw || fallback
	}

	function commit() {
		if (!root.open)
			return
		const event = root.fields
		root.fields = {}
		root.open = false
		if ((event.SUBSYSTEM || "") !== "usb" || (event.DEVTYPE || "") !== "usb_device")
			return
		const action = event.ACTION || ""
		if (action !== "add" && action !== "remove")
			return
		const vendor = root.label(event, "ID_VENDOR_FROM_DATABASE", "ID_VENDOR", "Unknown")
		const model = root.label(event, "ID_MODEL_FROM_DATABASE", "ID_MODEL", "Device")
		const connected = action === "add"
		Quickshell.execDetached([
			"notify-send",
			"-a", "USB",
			"-i", connected ? "drive-removable-media" : "media-eject",
			connected ? "USB Connected" : "USB Disconnected",
			vendor + " " + model
		])
	}

	function consider(line) {
		const text = line || ""
		if (text.startsWith("UDEV") && text.indexOf("[") !== -1) {
			root.commit()
			root.fields = {}
			root.open = true
			return
		}
		if (!root.open)
			return
		if (!text.trim()) {
			root.commit()
			return
		}
		const eq = text.indexOf("=")
		if (eq <= 0)
			return
		const next = Object.assign({}, root.fields)
		next[text.slice(0, eq)] = text.slice(eq + 1)
		root.fields = next
	}

	Process {
		id: watch
		command: ["udevadm", "monitor", "--udev", "--subsystem-match=usb", "--property"]
		running: true
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: data => root.consider(data)
		}
		stderr: SplitParser {
			splitMarker: "\n"
			onRead: data => {
				const line = (data || "").trim()
				if (line)
					console.warn("usb:", line)
			}
		}
		onExited: retry.start()
	}

	Timer {
		id: retry
		interval: 1500
		onTriggered: {
			if (!watch.running)
				watch.running = true
		}
	}
}

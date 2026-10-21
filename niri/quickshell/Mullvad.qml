pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Mullvad tunnel state. `mullvad status listen` pushes every state change, so
// the label no longer goes stale after a slow connect or a change made in the
// Mullvad app. ShellState.mullvadOn is kept in sync for existing callers.
Singleton {
	id: root

	property bool on: false
	property bool available: true

	// Same rule as before: "Connected…" is on; Disconnected/Connecting/Error are off.
	// Indented detail lines (relay, location) are ignored.
	function consider(line) {
		const text = line || ""
		if (!text.trim() || /^\s/.test(text))
			return
		const value = text.toLowerCase()
		root.on = value.indexOf("disconnected") === -1 && value.indexOf("connected") !== -1
	}

	function refresh() {
		if (!once.running)
			once.running = true
	}

	function toggle() {
		Quickshell.execDetached(["mullvad", root.on ? "disconnect" : "connect"])
		root.refresh()
	}

	onOnChanged: ShellState.mullvadOn = on

	Process {
		id: once
		command: ["mullvad", "status"]
		running: true
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: data => root.consider(data)
		}
	}

	Process {
		id: listen
		command: ["mullvad", "status", "listen"]
		running: true
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: data => {
				retry.interval = 1500
				root.consider(data)
			}
		}
		onExited: retry.start()
	}

	// Back off when the daemon is down or mullvad is not installed.
	Timer {
		id: retry
		interval: 1500
		onTriggered: {
			if (!listen.running)
				listen.running = true
			interval = Math.min(60000, interval * 2)
		}
	}
}

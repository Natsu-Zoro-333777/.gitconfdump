pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "niri-events.js" as NiriEvents

// Bar contract: monitors, tags, and clients.
// State comes from niri's event stream on $NIRI_SOCKET: full state up front,
// then incremental updates. Actions go over a second, persistent socket.
Singleton {
	id: root

	property var monitors: []
	property var clients: []
	readonly property var layouts: [{ symbol: "n", name: "niri" }]
	property bool watchAlive: false

	property var workspaces: []
	property var windows: []

	readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""

	function monitorFor(screenName) {
		for (let i = 0; i < monitors.length; i++) {
			if (monitors[i].name === screenName)
				return monitors[i]
		}
		return monitors.length > 0 ? monitors[0] : null
	}

	function tagsFor(screenName) {
		const monitor = monitorFor(screenName)
		return monitor && monitor.tags ? monitor.tags : []
	}

	function clientsFor(screenName) {
		const out = []
		for (let i = 0; i < clients.length; i++) {
			const client = clients[i]
			if (!screenName || client.monitor === screenName)
				out.push(client)
		}
		return out
	}

	function layoutName(symbol) {
		for (let i = 0; i < layouts.length; i++) {
			if (layouts[i].symbol === symbol)
				return layouts[i].name
		}
		return symbol || ""
	}

	function shQuote(value) {
		return "'" + String(value).replace(/'/g, "'\\''") + "'"
	}

	function focusedOutput() {
		for (let i = 0; i < workspaces.length; i++) {
			if (workspaces[i].is_focused && workspaces[i].output)
				return workspaces[i].output
		}
		for (let i = 0; i < monitors.length; i++) {
			if (monitors[i].active)
				return monitors[i].name
		}
		return ""
	}

	// One request per line on the command socket. Without a socket, fall back to
	// a single `niri msg action` call with the equivalent CLI arguments.
	function send(request, cliArgs) {
		if (commandSocket.connected) {
			commandSocket.write(JSON.stringify(request) + "\n")
			commandSocket.flush()
			return
		}
		if (cliArgs)
			Quickshell.execDetached(["niri", "msg", "action"].concat(cliArgs))
	}

	function onOutput(output, action, cliArgs) {
		const out = output || root.focusedOutput()
		if (out)
			root.send({ Action: { FocusMonitor: { output: out } } }, ["focus-monitor", out])
		root.send({ Action: action }, cliArgs)
	}

	function viewTag(index, output) {
		const n = parseInt(index, 10)
		if (!n)
			return
		const out = output || root.focusedOutput()
		for (let i = 0; i < workspaces.length; i++) {
			const ws = workspaces[i]
			if (ws.idx === n && (!out || ws.output === out)) {
				root.send({ Action: { FocusWorkspace: { reference: { Id: ws.id } } } },
					["focus-workspace", String(n)])
				return
			}
		}
		root.onOutput(out, { FocusWorkspace: { reference: { Index: n } } }, ["focus-workspace", String(n)])
	}

	function focusClient(client) {
		const id = parseInt(client && client.id, 10)
		if (!id)
			return
		root.send({ Action: { FocusWindow: { id: id } } }, ["focus-window", "--id", String(id)])
	}

	function viewLeft(output) {
		root.onOutput(output, { FocusWorkspaceUp: {} }, ["focus-workspace-up"])
	}

	function viewRight(output) {
		root.onOutput(output, { FocusWorkspaceDown: {} }, ["focus-workspace-down"])
	}

	function switchLayout() {
		root.send({ Action: { ToggleOverview: {} } }, ["toggle-overview"])
	}

	// Kept for callers of the old API. State is pushed by events now.
	function scheduleRefresh() {
		Qt.callLater(root.publish)
	}

	function parseList(text) {
		try {
			const data = JSON.parse(text || "")
			return Array.isArray(data) ? data : []
		} catch (error) {
			return null
		}
	}

	function publish() {
		const bar = NiriEvents.buildBar(root.workspaces, root.windows)
		root.monitors = bar.monitors
		root.clients = bar.clients
		root.watchAlive = true
	}

	function handleLine(line) {
		const text = (line || "").trim()
		if (!text)
			return
		let message
		try {
			message = JSON.parse(text)
		} catch (error) {
			console.warn("niri: bad event line:", text.slice(0, 200))
			return
		}
		// The first line on the socket is the reply to "EventStream".
		if (message && message.Ok !== undefined)
			return
		if (message && message.Err !== undefined) {
			console.warn("niri: event stream error:", message.Err)
			return
		}
		const next = NiriEvents.reduce({ workspaces: root.workspaces, windows: root.windows }, message)
		if (!next.changed)
			return
		root.workspaces = next.workspaces
		root.windows = next.windows
		publishTimer.restart()
	}

	// Several events often arrive together (workspace + window + focus).
	// Coalesce them into one publish.
	Timer {
		id: publishTimer
		interval: 16
		onTriggered: root.publish()
	}

	Socket {
		id: eventSocket
		path: root.socketPath
		connected: root.socketPath !== ""
		parser: SplitParser {
			splitMarker: "\n"
			onRead: data => root.handleLine(data)
		}
		onConnectionStateChanged: {
			if (connected) {
				reconnectTimer.interval = 1500
				write("\"EventStream\"\n")
				flush()
			} else {
				root.watchAlive = false
				reconnectTimer.start()
			}
		}
		onError: reconnectTimer.start()
	}

	Socket {
		id: commandSocket
		path: root.socketPath
		connected: root.socketPath !== ""
		parser: SplitParser {
			splitMarker: "\n"
			onRead: data => {
				if ((data || "").indexOf("\"Err\"") !== -1)
					console.warn("niri action failed:", data)
			}
		}
		onConnectionStateChanged: {
			if (!connected)
				reconnectTimer.start()
		}
		onError: reconnectTimer.start()
	}

	Timer {
		id: reconnectTimer
		interval: 1500
		onTriggered: {
			if (root.socketPath === "")
				return
			if (!eventSocket.connected)
				eventSocket.connected = true
			if (!commandSocket.connected)
				commandSocket.connected = true
			// Back off to 30 s while niri is unreachable.
			interval = Math.min(30000, interval * 2)
		}
	}

	// Fallback when $NIRI_SOCKET is unset: one long-lived event-stream process.
	// It prints the same JSON events, one per line, without the Ok reply.
	Process {
		id: watch
		command: ["niri", "msg", "--json", "event-stream"]
		running: root.socketPath === ""
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: data => root.handleLine(data)
		}
		onExited: {
			root.watchAlive = false
			if (root.socketPath === "")
				retryTimer.start()
		}
	}

	Timer {
		id: retryTimer
		interval: 1500
		onTriggered: {
			if (!watch.running)
				watch.running = true
		}
	}
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Same bar contract as the Mango singleton: monitors, tags, and clients.
// State comes from `niri msg` instead of `mmsg`.
Singleton {
	id: root

	property var monitors: []
	property var clients: []
	readonly property var layouts: [{ symbol: "n", name: "niri" }]
	property bool watchAlive: false

	property var workspaces: []
	property var windows: []

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

	function onOutput(output, action) {
		const out = output || root.focusedOutput()
		let cmd = "niri msg action " + action
		if (out)
			cmd = "niri msg action focus-monitor " + root.shQuote(out) + " && " + cmd
		actionProc.exec(["sh", "-c", cmd])
	}

	function viewTag(index, output) {
		const n = parseInt(index, 10)
		if (!n)
			return
		root.onOutput(output, "focus-workspace " + n)
	}

	function focusClient(client) {
		const id = parseInt(client && client.id, 10)
		if (!id)
			return
		actionProc.exec(["niri", "msg", "action", "focus-window", "--id", String(id)])
	}

	function viewLeft(output) {
		root.onOutput(output, "focus-workspace-up")
	}

	function viewRight(output) {
		root.onOutput(output, "focus-workspace-down")
	}

	function switchLayout() {
		actionProc.exec(["niri", "msg", "action", "toggle-overview"])
	}

	function scheduleRefresh() {
		refreshTimer.restart()
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
		const spaces = root.workspaces || []
		const wins = root.windows || []
		const counts = {}
		for (let i = 0; i < wins.length; i++) {
			const key = String(wins[i].workspace_id)
			counts[key] = (counts[key] || 0) + 1
		}

		let focusName = ""
		for (let i = 0; i < spaces.length; i++) {
			if (spaces[i].is_focused && spaces[i].output) {
				focusName = spaces[i].output
				break
			}
		}

		const byOutput = {}
		const order = []
		for (let i = 0; i < spaces.length; i++) {
			const name = spaces[i].output || ""
			if (!byOutput[name]) {
				byOutput[name] = []
				order.push(name)
			}
			byOutput[name].push(spaces[i])
		}

		const nextMonitors = []
		for (let i = 0; i < order.length; i++) {
			const name = order[i]
			const group = byOutput[name].slice().sort(function(a, b) {
				return (a.idx || 0) - (b.idx || 0)
			})
			const tags = []
			for (let j = 0; j < group.length; j++) {
				const ws = group[j]
				tags.push({
					index: ws.idx,
					is_active: !!ws.is_active,
					is_urgent: !!ws.is_urgent,
					client_count: counts[String(ws.id)] || 0
				})
			}
			nextMonitors.push({
				name: name,
				active: !!name && name === focusName,
				tags: tags,
				layout_symbol: "n"
			})
		}
		if (nextMonitors.length === 1 && !focusName)
			nextMonitors[0].active = true

		const spaceById = {}
		for (let i = 0; i < spaces.length; i++)
			spaceById[String(spaces[i].id)] = spaces[i]

		const nextClients = []
		for (let i = 0; i < wins.length; i++) {
			const win = wins[i]
			const space = spaceById[String(win.workspace_id)]
			nextClients.push({
				id: win.id,
				appid: win.app_id || "",
				title: win.title || "",
				pid: win.pid || 0,
				monitor: space && space.output ? space.output : "",
				tags: space ? [space.idx] : [],
				is_focused: !!win.is_focused,
				is_urgent: !!win.is_urgent,
				is_minimized: false,
				is_scratchpad: false,
				is_visible: !!(space && space.is_active)
			})
		}

		root.monitors = nextMonitors
		root.clients = nextClients
		root.watchAlive = true
	}

	Process {
		id: actionProc
	}

	Process {
		id: wsProc
		command: ["niri", "msg", "--json", "workspaces"]
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				const list = root.parseList(text)
				if (list) {
					root.workspaces = list
					if (!winProc.running)
						winProc.running = true
				}
			}
		}
		onExited: exitCode => {
			if (exitCode !== 0)
				retryTimer.start()
		}
	}

	Process {
		id: winProc
		command: ["niri", "msg", "--json", "windows"]
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				const list = root.parseList(text)
				if (list) {
					root.windows = list
					root.publish()
				}
			}
		}
	}

	Process {
		id: watch
		command: ["niri", "msg", "--json", "event-stream"]
		running: true
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: root.scheduleRefresh()
		}
		onExited: retryTimer.start()
	}

	Timer {
		id: refreshTimer
		interval: 40
		onTriggered: {
			if (!wsProc.running)
				wsProc.running = true
		}
	}

	Timer {
		id: retryTimer
		interval: 1500
		onTriggered: {
			if (!watch.running)
				watch.running = true
			root.scheduleRefresh()
		}
	}

	Component.onCompleted: root.scheduleRefresh()
}

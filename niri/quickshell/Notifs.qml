pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
	id: root

	property bool dnd: false
	property var received: ({})
	property var origins: ({})
	property var originClient: ({})
	property var focusedAt: ({})
	property int focusSerial: 0
	property var popups: []
	property double now: Date.now()
	property int revision: 0

	function handle(notification) {
		const stamp = Object.assign({}, received)
		if (!stamp[notification.id])
			stamp[notification.id] = Date.now()
		received = stamp
		notification.tracked = true
		root.revision = root.revision + 1
		if (!notification.lastGeneration)
			pinHint(notification)
		if (notification.lastGeneration || root.dnd)
			return
		pushPopup(notification)
	}

	function pack(notification) {
		const src = notification && notification.actions ? notification.actions : []
		const actions = []
		for (let i = 0; i < src.length; i++) {
			actions.push({
				identifier: "" + (src[i].identifier || ""),
				text: "" + (src[i].text || "")
			})
		}
		return {
			id: Number(notification.id),
			appName: notification.appName || "",
			appIcon: "" + (notification.appIcon || ""),
			summary: notification.summary || "",
			body: notification.body || "",
			image: "" + (notification.image || ""),
			actions: actions
		}
	}

	function pushPopup(notification) {
		const timeout = timeoutMs(notification)
		const entry = pack(notification)
		entry.until = timeout === 0 ? 0 : Date.now() + timeout
		const next = [entry]
		for (let i = 0; i < popups.length; i++) {
			if (Number(popups[i].id) !== entry.id)
				next.push(popups[i])
		}
		popups = next.slice(0, 4)
	}

	function timeoutMs(notification) {
		const urgency = NotificationUrgency.toString(notification.urgency)
		if (urgency === "Critical")
			return 0
		let seconds = notification.expireTimeout
		if (seconds > 120)
			seconds = seconds / 1000
		if (seconds > 0)
			return seconds * 1000
		return urgency === "Low" ? 5000 : 10000
	}

	readonly property var tracked: server.trackedNotifications

	function find(id) {
		const values = server.trackedNotifications.values
		const want = Number(id)
		for (let i = 0; i < values.length; i++) {
			if (Number(values[i].id) === want)
				return values[i]
		}
		return null
	}

	function actionSnapshots(id) {
		const notification = find(id)
		const src = notification && notification.actions ? notification.actions : []
		const actions = []
		for (let i = 0; i < src.length; i++) {
			actions.push({
				identifier: src[i].identifier,
				text: src[i].text
			})
		}
		return actions
	}

	function history() {
		const values = server.trackedNotifications.values
		const copy = []
		for (let i = 0; i < values.length; i++)
			copy.push(values[i])
		// Newest first. Ids break ties when several land in the same millisecond,
		// so a stack face is the latest note rather than whichever arrived first.
		copy.sort((a, b) => {
			const delta = (received[b.id] || 0) - (received[a.id] || 0)
			if (delta)
				return delta
			return Number(b.id) - Number(a.id)
		})
		return copy
	}

	function visiblePopups() {
		return popups
	}

	property var pendingDismiss: []
	property var pendingHistory: []
	property var readyToDismiss: []

	function dismissPopup(id, removeHistory) {
		id = Number(id)
		if (!id)
			return
		const queued = pendingDismiss.slice()
		queued.push(id)
		pendingDismiss = queued
		if (removeHistory) {
			const hist = pendingHistory.slice()
			hist.push(id)
			pendingHistory = hist
		}
		historyDismiss.restart()
	}

	function clearAll() {
		const values = server.trackedNotifications.values
		const queued = pendingDismiss.slice()
		const hist = pendingHistory.slice()
		for (let i = 0; i < values.length; i++) {
			queued.push(values[i].id)
			hist.push(values[i].id)
		}
		pendingDismiss = queued
		pendingHistory = hist
		historyDismiss.restart()
	}

	function openId(id) {
		const notification = find(Number(id))
		if (notification)
			open(notification)
	}

	function activateId(id, actionId) {
		const notification = find(Number(id))
		if (!notification)
			return
		let action = null
		const actions = notification.actions || []
		for (let i = 0; i < actions.length; i++) {
			if (actions[i].identifier === actionId) {
				action = actions[i]
				break
			}
		}
		activate(notification, action)
	}

	function age(id) {
		const stamp = received[id]
		if (!stamp)
			return ""
		const seconds = Math.max(0, Math.floor((now - stamp) / 1000))
		if (seconds < 10)
			return "now"
		if (seconds < 60)
			return seconds + "s"
		const minutes = Math.floor(seconds / 60)
		if (minutes < 60)
			return minutes + "m"
		const hours = Math.floor(minutes / 60)
		if (hours < 24)
			return hours + "h"
		return Math.floor(hours / 24) + "d"
	}

	function hintPid(notification) {
		const hints = notification && notification.hints ? notification.hints : {}
		const pid = parseInt(hints["sender-pid"], 10)
		return pid > 0 ? pid : 0
	}

	function pin(notification, pids) {
		if (!notification || !pids || !pids.length)
			return
		const next = Object.assign({}, origins)
		next[notification.id] = pids
		origins = next
		const pool = candidates(notification)
		const ids = Object.assign({}, originClient)
		if (pool.length === 1)
			ids[notification.id] = pool[0].id
		else
			delete ids[notification.id]
		originClient = ids
	}

	function pinHint(notification) {
		const pid = hintPid(notification)
		if (pid)
			pin(notification, [pid])
	}

	function noteOrigin(app, summary, body, pids) {
		const values = server.trackedNotifications.values
		let match = null
		for (let i = values.length - 1; i >= 0; i--) {
			const notification = values[i]
			if ((notification.appName || "") !== app)
				continue
			if ((notification.summary || "") !== summary)
				continue
			if ((notification.body || "") !== body)
				continue
			match = notification
			break
		}
		if (!match)
			return
		const have = origins[match.id] || []
		if (have.length >= pids.length && have.length > 1)
			return
		pin(match, pids)
	}

	function ingestOrigin(line) {
		const text = (line || "").trim()
		if (!text || text[0] !== "{")
			return
		let data
		try {
			data = JSON.parse(text)
		} catch (error) {
			return
		}
		if (!data.pids || !data.pids.length)
			return
		noteOrigin(data.app || "", data.summary || "", data.body || "", data.pids)
	}

	function noteFocus() {
		const clients = Niri.clients || []
		for (let i = 0; i < clients.length; i++) {
			const client = clients[i]
			if (!client.is_focused)
				continue
			if ((focusedAt[client.id] || 0) === focusSerial && focusSerial > 0)
				return
			focusSerial++
			const next = Object.assign({}, focusedAt)
			next[client.id] = focusSerial
			focusedAt = next
			return
		}
	}

	function norm(text) {
		return (text || "").toLowerCase()
	}

	function sameId(appid, key) {
		if (!appid || !key)
			return false
		if (appid === key)
			return true
		if (key.indexOf(".") !== -1 && (appid.endsWith("." + key) || key.endsWith("." + appid)))
			return true
		if (appid.indexOf(".") !== -1 && key.indexOf(".") === -1 && key.length >= 3 && appid.endsWith("." + key))
			return true
		return false
	}

	function entryFor(notification) {
		const hints = notification.hints || {}
		const id = notification.desktopEntry || hints["desktop-entry"] || ""
		if (id) {
			const entry = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
			if (entry)
				return entry
		}
		const name = norm(notification.appName)
		if (!name)
			return null
		const apps = DesktopEntries.applications.values
		for (let i = 0; i < apps.length; i++) {
			if (apps[i] && norm(apps[i].name) === name)
				return apps[i]
		}
		return DesktopEntries.heuristicLookup(notification.appName || "")
	}

	function clientMatches(client, notification, entry) {
		const appid = norm(client.appid)
		if (!appid || client.is_scratchpad)
			return false
		const hints = notification.hints || {}
		const desktop = norm(notification.desktopEntry || hints["desktop-entry"] || "")
		if (desktop && sameId(appid, desktop))
			return true
		if (entry && (sameId(appid, norm(entry.id)) || sameId(appid, norm(entry.startupClass))))
			return true
		const clientEntry = DesktopEntries.heuristicLookup(client.appid || "")
		if (entry && clientEntry && clientEntry.id === entry.id)
			return true
		const appName = norm(notification.appName)
		if (appName && appName.length >= 2) {
			if (appid === appName)
				return true
			if (clientEntry && norm(clientEntry.name) === appName)
				return true
		}
		return false
	}

	function clientsSharingPid(clients, pids) {
		for (let p = 0; p < pids.length; p++) {
			const pid = parseInt(pids[p], 10)
			const found = []
			for (let i = 0; i < clients.length; i++) {
				if (parseInt(clients[i].pid, 10) === pid && !clients[i].is_scratchpad)
					found.push(clients[i])
			}
			if (found.length)
				return found
		}
		return []
	}

	function candidates(notification) {
		const clients = Niri.clients || []
		const pids = origins[notification.id] || []
		if (pids.length) {
			const byPid = clientsSharingPid(clients, pids)
			if (byPid.length)
				return byPid
		}
		const entry = entryFor(notification)
		const found = []
		for (let i = 0; i < clients.length; i++) {
			if (clientMatches(clients[i], notification, entry))
				found.push(clients[i])
		}
		return found
	}

	function clientById(id) {
		const want = parseInt(id, 10)
		const clients = Niri.clients || []
		for (let i = 0; i < clients.length; i++) {
			if (parseInt(clients[i].id, 10) === want)
				return clients[i]
		}
		return null
	}

	function titleMatches(pool, notification) {
		const blob = norm((notification.summary || "") + "\n" + (notification.body || ""))
		const found = []
		for (let i = 0; i < pool.length; i++) {
			const title = norm(pool[i].title)
			if (title.length >= 3 && blob.indexOf(title) !== -1)
				found.push(pool[i])
		}
		return found
	}

	function pickClient(pool, notification) {
		const titled = titleMatches(pool, notification)
		const list = titled.length ? titled : pool
		if (list.length === 1)
			return list[0]
		for (let i = 0; i < list.length; i++) {
			if (list[i].is_focused)
				return list[i]
		}
		const urgent = []
		for (let i = 0; i < list.length; i++) {
			if (list[i].is_urgent)
				urgent.push(list[i])
		}
		const ranked = urgent.length === 1 ? urgent : list
		if (ranked.length === 1)
			return ranked[0]
		let best = ranked[0]
		let bestAt = focusedAt[best.id] || 0
		for (let i = 1; i < ranked.length; i++) {
			const at = focusedAt[ranked[i].id] || 0
			if (at > bestAt) {
				best = ranked[i]
				bestAt = at
			}
		}
		return best
	}

	function sourceClient(notification) {
		if (!notification)
			return null
		const saved = originClient[notification.id]
		if (saved) {
			const live = clientById(saved)
			if (live && !live.is_scratchpad)
				return live
		}
		const pool = candidates(notification)
		if (!pool.length)
			return null
		return pickClient(pool, notification)
	}

	function focusOrigin(notification) {
		const client = sourceClient(notification)
		if (!client)
			return false
		if (!(client.is_focused && client.is_visible))
			Niri.focusClient(client)
		console.log("notification open", client.appid || "", "tag", (client.tags || []).join(","))
		return true
	}

	function defaultAction(notification) {
		const actions = notification && notification.actions ? notification.actions : []
		for (let i = 0; i < actions.length; i++) {
			if (actions[i].identifier === "default")
				return actions[i]
		}
		return null
	}

	function activate(notification, action) {
		const id = notification ? notification.id : 0
		const jumped = focusOrigin(notification)
		if (action)
			action.invoke()
		if (id)
			dismissPopup(id, false)
		if (jumped)
			ShellState.centerOpen = false
	}

	function open(notification) {
		activate(notification, defaultAction(notification))
	}

	function icon() {
		const count = server.trackedNotifications.values.length
		if (dnd && count > 0)
			return "🐌💤"
		if (dnd)
			return "💤"
		if (count > 0)
			return "🐌💬"
		return "🐌"
	}

	NotificationServer {
		id: server
		keepOnReload: true
		bodySupported: true
		bodyMarkupSupported: false
		actionsSupported: true
		imageSupported: true
		persistenceSupported: true
		onNotification: notification => root.handle(notification)
	}

	Timer {
		id: historyDismiss
		interval: 1
		onTriggered: {
			const popupIds = root.pendingDismiss
			const histIds = root.pendingHistory
			root.pendingDismiss = []
			root.pendingHistory = []
			const next = []
			for (let i = 0; i < root.popups.length; i++) {
				if (popupIds.indexOf(root.popups[i].id) === -1)
					next.push(root.popups[i])
			}
			root.popups = next
			root.readyToDismiss = histIds
			if (histIds.length)
				objectDismiss.restart()
		}
	}

	Timer {
		id: objectDismiss
		interval: 1
		onTriggered: {
			const ids = root.readyToDismiss
			root.readyToDismiss = []
			for (let i = 0; i < ids.length; i++) {
				const notification = root.find(Number(ids[i]))
				if (notification)
					notification.dismiss()
			}
		}
	}

	Timer {
		interval: 250
		repeat: true
		running: root.popups.length > 0
		onTriggered: {
			const time = Date.now()
			const keep = []
			for (let i = 0; i < root.popups.length; i++) {
				const entry = root.popups[i]
				if (entry.until !== 0 && time >= entry.until) {
					const notification = root.find(entry.id)
					if (notification && notification.transient)
						notification.expire()
					continue
				}
				keep.push(entry)
			}
			if (keep.length !== root.popups.length)
				root.popups = keep
		}
	}

	Timer {
		interval: 30000
		running: true
		repeat: true
		onTriggered: root.now = Date.now()
	}

	Process {
		id: originWatch
		command: ["python3", Quickshell.shellPath("notif-origin.py")]
		running: true
		stdout: SplitParser {
			splitMarker: "\n"
			onRead: data => root.ingestOrigin(data)
		}
		stderr: SplitParser {
			splitMarker: "\n"
			onRead: data => {
				const line = (data || "").trim()
				if (line)
					console.warn("notif-origin:", line)
			}
		}
		onExited: originRetry.start()
	}

	Timer {
		id: originRetry
		interval: 1500
		onTriggered: {
			if (!originWatch.running)
				originWatch.running = true
		}
	}

	Connections {
		target: Niri
		function onClientsChanged() {
			root.noteFocus()
		}
	}

	Component.onCompleted: root.noteFocus()
}

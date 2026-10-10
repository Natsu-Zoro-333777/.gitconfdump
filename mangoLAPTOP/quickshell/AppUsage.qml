pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
	id: root

	// id -> { count, last }. Reloaded from the cache file.
	property var apps: ({})
	property bool armed: false
	property var pending: []
	readonly property int promoteLimit: 16

	// Frequent launches stay high, and a recent launch still beats an old one.
	// The weight halves every 3 days.
	function recordScore(rec) {
		if (!rec || !rec.count)
			return 0
		const ageHours = Math.max(0, (Date.now() - (rec.last || 0)) / 3600000)
		return rec.count * Math.pow(0.5, ageHours / 72)
	}

	function score(id) {
		if (!id || !root.apps)
			return 0
		return root.recordScore(root.apps[id])
	}

	function readEntries(list) {
		const map = {}
		if (list) {
			for (let i = 0; i < list.length; i++) {
				const rec = list[i]
				if (!rec || !rec.id)
					continue
				map[rec.id] = {
					count: rec.count || 0,
					last: rec.last || 0
				}
			}
		}
		root.apps = map
	}

	function prune(map) {
		const keys = Object.keys(map)
		if (keys.length <= 200)
			return
		keys.sort((a, b) => root.recordScore(map[a]) - root.recordScore(map[b]))
		const extra = keys.length - 200
		for (let i = 0; i < extra; i++)
			delete map[keys[i]]
	}

	function commit(id) {
		const next = {}
		const current = root.apps || {}
		const keys = Object.keys(current)
		for (let i = 0; i < keys.length; i++)
			next[keys[i]] = current[keys[i]]
		const prev = next[id] || {}
		next[id] = {
			count: (prev.count || 0) + 1,
			last: Date.now()
		}
		root.prune(next)
		const saved = []
		const savedKeys = Object.keys(next)
		for (let i = 0; i < savedKeys.length; i++) {
			const rec = next[savedKeys[i]]
			saved.push({
				id: savedKeys[i],
				count: rec.count,
				last: rec.last
			})
		}
		root.apps = next
		adapter.entries = saved
	}

	function note(id) {
		if (!id)
			return
		if (!root.armed) {
			const queued = []
			for (let i = 0; i < root.pending.length; i++)
				queued.push(root.pending[i])
			queued.push(id)
			root.pending = queued
			return
		}
		root.commit(id)
	}

	function arm() {
		if (root.armed)
			return
		root.armed = true
		const queued = []
		for (let i = 0; i < root.pending.length; i++)
			queued.push(root.pending[i])
		root.pending = []
		for (let i = 0; i < queued.length; i++)
			root.commit(queued[i])
	}

	Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Quickshell.cacheDir])

	FileView {
		id: usageFile
		path: Quickshell.cachePath("launcher-usage.json")
		atomicWrites: true
		printErrors: false
		onAdapterUpdated: {
			if (root.armed)
				writeAdapter()
		}
		onLoaded: {
			root.readEntries(adapter.entries)
			root.arm()
		}
		onLoadFailed: function(error) {
			if (error === FileViewError.FileNotFound) {
				root.apps = {}
				root.arm()
				return
			}
			console.log("launcher cache load failed:", FileViewError.toString(error))
		}

		JsonAdapter {
			id: adapter
			property var entries: []
		}
	}
}


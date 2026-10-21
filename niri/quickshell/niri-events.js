.pragma library

// Pure reducers for the niri IPC event stream (niri-ipc Event enum).
// State is { workspaces: [...], windows: [...] } in niri's JSON shape.
// Each reducer returns { workspaces, windows, changed } without mutating its input.

function replaceById(list, id, update) {
	const out = []
	for (let i = 0; i < list.length; i++)
		out.push(list[i].id === id ? update(list[i]) : list[i])
	return out
}

function with_(obj, extra) {
	return Object.assign({}, obj, extra)
}

function reduce(state, event) {
	const spaces = state.workspaces || []
	const wins = state.windows || []
	const same = { workspaces: spaces, windows: wins, changed: false }
	if (!event || typeof event !== "object")
		return same

	if (event.WorkspacesChanged)
		return { workspaces: event.WorkspacesChanged.workspaces || [], windows: wins, changed: true }

	if (event.WorkspaceUrgencyChanged) {
		const e = event.WorkspaceUrgencyChanged
		return { workspaces: replaceById(spaces, e.id, w => with_(w, { is_urgent: !!e.urgent })), windows: wins, changed: true }
	}

	// Active on its output; every other workspace on that output becomes inactive.
	// focused=true makes it the single focused workspace.
	if (event.WorkspaceActivated) {
		const e = event.WorkspaceActivated
		let output = null
		for (let i = 0; i < spaces.length; i++) {
			if (spaces[i].id === e.id)
				output = spaces[i].output
		}
		const next = []
		for (let i = 0; i < spaces.length; i++) {
			const w = spaces[i]
			if (w.id === e.id)
				next.push(with_(w, { is_active: true, is_focused: e.focused ? true : w.is_focused }))
			else if (w.output === output || e.focused)
				next.push(with_(w, {
					is_active: w.output === output ? false : w.is_active,
					is_focused: e.focused ? false : w.is_focused
				}))
			else
				next.push(w)
		}
		return { workspaces: next, windows: wins, changed: true }
	}

	if (event.WorkspaceActiveWindowChanged) {
		const e = event.WorkspaceActiveWindowChanged
		return {
			workspaces: replaceById(spaces, e.workspace_id, w => with_(w, { active_window_id: e.active_window_id })),
			windows: wins,
			changed: true
		}
	}

	if (event.WindowsChanged)
		return { workspaces: spaces, windows: event.WindowsChanged.windows || [], changed: true }

	// A focused window means every other window is no longer focused.
	if (event.WindowOpenedOrChanged) {
		const win = event.WindowOpenedOrChanged.window
		if (!win)
			return same
		const next = []
		let found = false
		for (let i = 0; i < wins.length; i++) {
			if (wins[i].id === win.id) {
				next.push(win)
				found = true
			} else if (win.is_focused && wins[i].is_focused) {
				next.push(with_(wins[i], { is_focused: false }))
			} else {
				next.push(wins[i])
			}
		}
		if (!found)
			next.push(win)
		return { workspaces: spaces, windows: next, changed: true }
	}

	if (event.WindowClosed) {
		const id = event.WindowClosed.id
		return { workspaces: spaces, windows: wins.filter(w => w.id !== id), changed: true }
	}

	if (event.WindowFocusChanged) {
		const id = event.WindowFocusChanged.id
		const next = []
		for (let i = 0; i < wins.length; i++) {
			const focused = id !== null && id !== undefined && wins[i].id === id
			next.push(!!wins[i].is_focused === focused ? wins[i] : with_(wins[i], { is_focused: focused }))
		}
		return { workspaces: spaces, windows: next, changed: true }
	}

	if (event.WindowUrgencyChanged) {
		const e = event.WindowUrgencyChanged
		return { workspaces: spaces, windows: replaceById(wins, e.id, w => with_(w, { is_urgent: !!e.urgent })), changed: true }
	}

	// WindowLayoutsChanged, WindowFocusTimestampChanged, keyboard, overview, config,
	// screenshot, cast and unknown future events do not affect the bar contract.
	return same
}

// The bar contract (monitors/tags/clients), same shape the bar always used.
function buildBar(spaces, wins) {
	spaces = spaces || []
	wins = wins || []
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

	const monitors = []
	for (let i = 0; i < order.length; i++) {
		const name = order[i]
		const group = byOutput[name].slice().sort((a, b) => (a.idx || 0) - (b.idx || 0))
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
		monitors.push({
			name: name,
			active: !!name && name === focusName,
			tags: tags,
			layout_symbol: "n"
		})
	}
	if (monitors.length === 1 && !focusName)
		monitors[0].active = true

	const spaceById = {}
	for (let i = 0; i < spaces.length; i++)
		spaceById[String(spaces[i].id)] = spaces[i]

	const clients = []
	for (let i = 0; i < wins.length; i++) {
		const win = wins[i]
		const space = spaceById[String(win.workspace_id)]
		clients.push({
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
	return { monitors: monitors, clients: clients }
}

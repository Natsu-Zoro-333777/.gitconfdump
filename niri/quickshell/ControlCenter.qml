import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

PopupWindow {
	id: win

	property var anchorWindow: null
	property var anchorItem: null
	property var dismissIds: []
	property var pendingIds: []
	readonly property var streams: streamList()
	property var networks: []
	property bool wifiScanning: false
	property string focusedSource: ""
	property string focusedAppName: ""
	property var focusedNotes: []

	// Playback streams only. Quickshell marks Stream/Output/Audio as a sink.
	// Volume and application.name stay empty until the node is bound.
	function streamList() {
		const nodes = Pipewire.nodes.values
		const out = []
		for (let i = 0; i < nodes.length; i++) {
			const node = nodes[i]
			if (node.isStream && node.isSink && node.audio)
				out.push(node)
		}
		return out
	}

	function streamName(node) {
		if (!node)
			return "App"
		if (node.ready) {
			const props = node.properties || {}
			const app = props["application.name"] || ""
			if (app)
				return app
		}
		return node.description || node.name || "App"
	}

	function scheduleSync() {
		syncTimer.restart()
	}

	function stillPending() {
		const keep = []
		for (let i = 0; i < pendingIds.length; i++) {
			const id = Number(pendingIds[i])
			if (id && Notifs.find(id))
				keep.push(id)
		}
		if (keep.length !== pendingIds.length)
			pendingIds = keep
		return keep
	}

	function held(id, hide) {
		id = Number(id)
		for (let i = 0; i < hide.length; i++) {
			if (Number(hide[i]) === id)
				return true
		}
		return false
	}

	// Same application name, else the same desktop entry. A notification
	// with neither stays on its own so unrelated blanks do not pile up.
	function sourceKeyOf(notification) {
		const name = (notification.appName || "").trim().toLowerCase()
		if (name)
			return "app:" + name
		const hints = notification.hints || {}
		const desktop = ((notification.desktopEntry || hints["desktop-entry"] || "") + "").trim().toLowerCase()
		if (desktop)
			return "desktop:" + desktop
		return "id:" + Number(notification.id)
	}

	function publishFocus() {
		let notes = []
		let name = ""
		for (let i = 0; i < decks.count; i++) {
			const row = decks.get(i)
			if (!row || row.sourceKey !== focusedSource)
				continue
			name = row.appName || "Notification"
			try {
				notes = JSON.parse(row.itemsJson || "[]")
			} catch (e) {
				notes = []
			}
			break
		}
		focusedAppName = name
		focusedNotes = notes
	}

	function focusDeck(key) {
		if (!key)
			return
		focusedSource = key
		publishFocus()
		if (pageScroll)
			pageScroll.contentY = 0
	}

	function leaveFocus() {
		focusedSource = ""
		focusedAppName = ""
		focusedNotes = []
		if (pageScroll)
			pageScroll.contentY = 0
	}

	function syncNotices() {
		const live = Notifs.history()
		const hide = stillPending()
		const keys = []
		const buckets = {}
		let used = 0
		for (let i = 0; i < live.length; i++) {
			if (used >= 300)
				break
			const notification = live[i]
			if (!notification || held(notification.id, hide))
				continue
			const key = sourceKeyOf(notification)
			if (!buckets[key]) {
				buckets[key] = []
				keys.push(key)
			}
			buckets[key].push(Notifs.pack(notification))
			used++
		}
		decks.clear()
		let focusedLive = false
		for (let k = 0; k < keys.length; k++) {
			const slice = buckets[keys[k]]
			if (keys[k] === focusedSource && slice.length > 1)
				focusedLive = true
			decks.append({
				sourceKey: keys[k],
				appName: slice[0].appName || "Notification",
				appIcon: slice[0].appIcon || "",
				count: slice.length,
				itemsJson: JSON.stringify(slice)
			})
		}
		if (focusedSource && !focusedLive)
			leaveFocus()
		else if (focusedSource)
			publishFocus()
	}

	function remember(id) {
		id = Number(id)
		if (!id || held(id, pendingIds))
			return
		const next = []
		for (let i = 0; i < pendingIds.length; i++)
			next.push(Number(pendingIds[i]))
		next.push(id)
		pendingIds = next
	}

	function requestDismiss(id) {
		id = Number(id)
		if (!id)
			return
		remember(id)
		if (!held(id, dismissIds)) {
			const next = []
			for (let i = 0; i < dismissIds.length; i++)
				next.push(Number(dismissIds[i]))
			next.push(id)
			dismissIds = next
		}
		// Rebuild after the press returns. Clearing the list here leaves the card painted.
		dismissLater.restart()
	}

	function requestDismissAll() {
		const live = Notifs.history()
		const ids = []
		for (let i = 0; i < live.length; i++) {
			const id = Number(live[i].id)
			if (!id)
				continue
			remember(id)
			ids.push(id)
		}
		dismissIds = ids
		dismissLater.restart()
	}

	function splitNmcli(line) {
		const parts = []
		let buf = ""
		let escaped = false
		for (let i = 0; i < line.length; i++) {
			const ch = line.charAt(i)
			if (escaped) {
				buf += ch
				escaped = false
			} else if (ch === "\\") {
				escaped = true
			} else if (ch === ":") {
				parts.push(buf)
				buf = ""
			} else {
				buf += ch
			}
		}
		parts.push(buf)
		return parts
	}

	function applyWifi(text) {
		const chunks = text.split("---SAVED---")
		const saved = {}
		const savedLines = (chunks[1] || "").split("\n")
		for (let i = 0; i < savedLines.length; i++) {
			const name = savedLines[i].trim()
			if (name)
				saved[name] = true
		}
		const best = {}
		const lines = (chunks[0] || "").split("\n")
		for (let i = 0; i < lines.length; i++) {
			if (!lines[i])
				continue
			const parts = splitNmcli(lines[i])
			if (parts.length < 4)
				continue
			const signal = parseInt(parts[1], 10) || 0
			const security = parts[2]
			const name = parts.slice(3).join(":")
			if (!name)
				continue
			const open = security === "" || security === "--"
			const connected = parts[0] === "*"
			const prev = best[name]
			if (!prev || signal > prev.signalStrength) {
				best[name] = {
					name: name,
					signalStrength: signal,
					securityLabel: open ? "open" : security,
					connected: connected || (prev ? prev.connected : false),
					known: !!saved[name],
					open: open
				}
			} else if (connected) {
				prev.connected = true
			}
		}
		const out = []
		for (const name in best)
			out.push(best[name])
		out.sort((a, b) => b.signalStrength - a.signalStrength)
		networks = out
		wifiScanning = false
	}

	function connectNet(net) {
		if (!net)
			return
		if (!net.known && !net.connected && !net.open) {
			ShellState.wifiTarget = net.name
			password.text = ""
			password.forceActiveFocus()
			return
		}
		ShellState.wifiTarget = ""
		if (net.known)
			Quickshell.execDetached(["nmcli", "connection", "up", "id", net.name])
		else
			Quickshell.execDetached(["nmcli", "device", "wifi", "connect", net.name])
	}

	function nativeNetwork(name) {
		const device = Theme.wifiDevice()
		if (!device || !device.networks)
			return null
		const nets = device.networks.values
		for (let i = 0; i < nets.length; i++) {
			if (nets[i].name === name)
				return nets[i]
		}
		return null
	}

	// The password never goes on a command line (it would be readable in
	// /proc/<pid>/cmdline). Prefer Quickshell's NetworkManager backend; fall
	// back to nmcli reading the secret from stdin.
	function submitPassword() {
		if (!ShellState.wifiTarget || !password.text)
			return
		const ssid = ShellState.wifiTarget
		const psk = password.text
		password.text = ""
		ShellState.wifiTarget = ""
		const net = nativeNetwork(ssid)
		if (net && (net.security === WifiSecurityType.WpaPsk
				|| net.security === WifiSecurityType.Wpa2Psk
				|| net.security === WifiSecurityType.Sae)) {
			net.connectWithPsk(psk)
			return
		}
		if (pskProc.running)
			return
		pskProc.secret = psk
		pskProc.exec(["nmcli", "--ask", "device", "wifi", "connect", ssid])
	}

	function refreshMullvad() {
		Mullvad.refresh()
	}

	// Several bars each own a control center; only the one on the target
	// screen opens. No target means the focused niri output.
	function ownsOpen() {
		if (!anchorWindow || !anchorWindow.screen)
			return false
		const name = anchorWindow.screen.name
		if (ShellState.centerMonitor)
			return ShellState.centerMonitor === name
		const focused = Niri.focusedOutput()
		if (focused)
			return focused === name
		const screens = Quickshell.screens
		return screens.length === 0 || screens[0].name === name
	}

	// Stay this size while open. Resizing the popup on Clear All left it
	// squished and it stopped taking clicks.
	implicitWidth: 400
	implicitHeight: 560
	color: "transparent"
	visible: ShellState.centerOpen && anchorItem !== null && ownsOpen()
	grabFocus: true
	anchor.window: anchorWindow
	anchor.item: anchorItem
	anchor.edges: Edges.Bottom
	anchor.gravity: Edges.Bottom
	anchor.margins.top: 6
	anchor.adjustment: PopupAdjustment.Slide

	onVisibleChanged: {
		if (!visible) {
			leaveFocus()
			// Only a dismissal of this screen's popup closes the center. A popup
			// hidden because the center moved to another screen leaves it open.
			if (ShellState.centerOpen && ownsOpen())
				ShellState.centerOpen = false
			return
		}
		syncNotices()
		keyGrab.forceActiveFocus()
		if (ShellState.centerPage === "gear")
			refreshMullvad()
		if (ShellState.centerPage === "wifi")
			enableScan()
	}

	function enableScan() {
		if (wifiProc.running)
			return
		wifiScanning = networks.length === 0
		wifiProc.running = true
	}

	Connections {
		target: ShellState
		function onCenterPageChanged() {
			if (ShellState.centerPage !== "main")
				win.leaveFocus()
			if (!ShellState.centerOpen)
				return
			if (ShellState.centerPage === "gear")
				win.refreshMullvad()
			if (ShellState.centerPage === "wifi")
				win.enableScan()
		}
	}

	PwObjectTracker {
		objects: win.streams
	}

	Timer {
		id: syncTimer
		interval: 1
		onTriggered: win.syncNotices()
	}

	Timer {
		id: dismissLater
		interval: 1
		onTriggered: {
			const ids = win.dismissIds
			win.dismissIds = []
			win.syncNotices()
			for (let i = 0; i < ids.length; i++)
				Notifs.dismissPopup(Number(ids[i]), true)
		}
	}

	Connections {
		target: Notifs.tracked
		function onValuesChanged() {
			win.scheduleSync()
		}
	}

	Connections {
		target: Notifs
		function onRevisionChanged() {
			win.scheduleSync()
		}
	}

	ListModel {
		id: decks
	}

	Rectangle {
		id: panel
		anchors.fill: parent
		radius: 0
		color: Theme.bg
		border.width: 3
		border.color: Theme.red

		MouseArea {
			z: -1
			anchors.fill: parent
			onClicked: {}
		}

		Item {
			id: keyGrab
			anchors.fill: parent
			focus: true
			Keys.onEscapePressed: {
				if (ShellState.wifiTarget)
					ShellState.wifiTarget = ""
				else if (win.focusedSource)
					win.leaveFocus()
				else if (ShellState.centerPage !== "main")
					ShellState.centerPage = "main"
				else
					ShellState.closeTransient()
			}
		}

		ColumnLayout {
			id: body
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: parent.top
			anchors.bottom: parent.bottom
			anchors.margins: 12
			spacing: 10

			RowLayout {
				Layout.fillWidth: true

				Rectangle {
					visible: ShellState.centerPage !== "main" || win.focusedSource !== ""
					Layout.preferredWidth: 32
					Layout.preferredHeight: 32
					radius: 0
					color: backMouse.containsMouse ? Theme.orange : Theme.bgAlt

					Text {
						anchors.centerIn: parent
						text: "󰁍"
						color: backMouse.containsMouse ? Theme.bg : Theme.yellow
						font.family: Theme.fontFamily
						font.pixelSize: 16
					}

					MouseArea {
						id: backMouse
						anchors.fill: parent
						hoverEnabled: true
						onClicked: {
							if (win.focusedSource) {
								win.leaveFocus()
								return
							}
							ShellState.wifiTarget = ""
							ShellState.centerPage = "main"
						}
					}
				}

				Text {
					Layout.fillWidth: true
					text: {
						if (ShellState.centerPage === "wifi")
							return "Wi-Fi"
						if (ShellState.centerPage === "gear")
							return "Settings"
						if (win.focusedSource)
							return (win.focusedAppName || "Notifications") + "  " + win.focusedNotes.length
						return "Notifications"
					}
					color: Theme.yellow
					font.family: Theme.fontFamily
					font.pixelSize: 18
					font.bold: true
				}

				Rectangle {
					visible: ShellState.centerPage === "main"
					Layout.preferredWidth: clearLabel.implicitWidth + 16
					Layout.preferredHeight: 32
					radius: 0
					color: clearMouse.containsMouse ? Theme.orange : Theme.bgAlt
					border.width: 2
					border.color: Theme.red

					Text {
						id: clearLabel
						anchors.centerIn: parent
						text: "Clear All"
						color: clearMouse.containsMouse ? Theme.bg : Theme.yellow
						font.family: Theme.fontFamily
						font.pixelSize: 13
					}

					MouseArea {
						id: clearMouse
						anchors.fill: parent
						hoverEnabled: true
						onClicked: win.requestDismissAll()
					}
				}
			}

			StackLayout {
				Layout.fillWidth: true
				Layout.fillHeight: true
				currentIndex: ShellState.centerPage === "gear" ? 1 : ShellState.centerPage === "wifi" ? 2 : 0

			Item {
				id: pageFrame
				Layout.fillWidth: true
				Layout.fillHeight: true

				Flickable {
					id: pageScroll
					anchors.fill: parent
					anchors.rightMargin: 8
					clip: true
					boundsBehavior: Flickable.StopAtBounds
					flickableDirection: Flickable.VerticalFlick
					contentWidth: width
					// The column's implicit height is the real list. Do not bind the
					// column's height to that value: the binding loop freezes the
					// scroll range short of the last cards.
					contentHeight: pageCol.implicitHeight

					Item {
						id: scrollBox
						width: pageScroll.width
						height: pageCol.implicitHeight

						ColumnLayout {
							id: pageCol
							width: scrollBox.width
							spacing: 10

						ColumnLayout {
							id: dashCol
							visible: win.focusedSource === ""
							Layout.fillWidth: true
							spacing: 10

				Repeater {
					model: Mpris.players

					Rectangle {
						required property var modelData
						Layout.fillWidth: true
						implicitHeight: 76
						radius: 0
						color: Theme.bgAlt
						border.width: 2
						border.color: Theme.red

						RowLayout {
							anchors.fill: parent
							anchors.margins: 8
							spacing: 8

							Image {
								Layout.preferredWidth: 56
								Layout.preferredHeight: 56
								fillMode: Image.PreserveAspectCrop
								source: modelData.trackArtUrl || ""
								visible: source.toString() !== ""
							}

							ColumnLayout {
								Layout.fillWidth: true
								spacing: 2

								Text {
									Layout.fillWidth: true
									text: modelData.trackTitle || modelData.identity || "Media"
									color: Theme.yellow
									font.family: Theme.fontFamily
									font.pixelSize: 14
									font.bold: true
									elide: Text.ElideRight
								}

								Text {
									Layout.fillWidth: true
									text: modelData.trackArtist || ""
									color: Theme.gray
									font.family: Theme.fontFamily
									font.pixelSize: 12
									elide: Text.ElideRight
								}
							}

							MediaButton {
								label: "󰒮"
								canUse: modelData.canGoPrevious
								onTriggered: modelData.previous()
							}
							MediaButton {
								label: modelData.isPlaying ? "󰏤" : "󰐊"
								canUse: modelData.canTogglePlaying
								onTriggered: modelData.togglePlaying()
							}
							MediaButton {
								label: "󰒭"
								canUse: modelData.canGoNext
								onTriggered: modelData.next()
							}
						}
					}
				}

				RowLayout {
					Layout.fillWidth: true
					spacing: 8

					ActionButton {
						Layout.fillWidth: true
						label: Networking.wifiEnabled ? "󰖩" : "󰖪"
						active: Networking.wifiEnabled
						onTriggered: Networking.wifiEnabled = !Networking.wifiEnabled
					}
					ActionButton {
						Layout.fillWidth: true
						label: "󰒓"
						onTriggered: ShellState.centerPage = "gear"
					}
					ActionButton {
						Layout.fillWidth: true
						label: "󰕾"
						onTriggered: {
							ShellState.closeTransient()
							Quickshell.execDetached(["env", "GTK_THEME=Adwaita:dark", "pavucontrol"])
						}
					}
				}

				RowLayout {
					Layout.fillWidth: true
					spacing: 8

					Text {
						text: Theme.audioIcon()
						color: Theme.yellow
						font.family: Theme.fontFamily
						font.pixelSize: 16
					}

					Vol {
						value: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : 0
						onMoved: volume => {
							const sink = Pipewire.defaultAudioSink
							if (sink && sink.ready && sink.audio) {
								sink.audio.muted = false
								sink.audio.volume = volume
							}
						}
					}

					Text {
						text: {
							const sink = Pipewire.defaultAudioSink
							if (sink && sink.audio && sink.audio.muted)
								return "muted"
							return Theme.audioPercent() + "%"
						}
						color: Theme.gray
						font.family: Theme.fontFamily
						font.pixelSize: 12
					}
				}

				Repeater {
					model: win.streams

					RowLayout {
						required property var modelData
						Layout.fillWidth: true
						spacing: 8

						Text {
							Layout.preferredWidth: 120
							text: win.streamName(modelData)
							color: Theme.fg
							font.family: Theme.fontFamily
							font.pixelSize: 12
							elide: Text.ElideRight
						}

						Vol {
							maxValue: 1.5
							value: modelData.ready && modelData.audio ? modelData.audio.volume : 0
							onMoved: volume => {
								if (modelData.ready && modelData.audio) {
									modelData.audio.muted = false
									modelData.audio.volume = volume
								}
							}
						}
					}
				}

				RowLayout {
					Layout.fillWidth: true

					Text {
						text: "Do Not Disturb"
						color: Theme.fg
						font.family: Theme.fontFamily
						font.pixelSize: 14
					}

					Item { Layout.fillWidth: true }

					Rectangle {
						Layout.preferredWidth: 44
						Layout.preferredHeight: 24
						radius: 0
						color: Notifs.dnd ? Theme.orange : Theme.bgAlt
						border.width: 2
						border.color: Theme.red

						Rectangle {
							width: 16
							height: 16
							radius: 0
							anchors.verticalCenter: parent.verticalCenter
							x: Notifs.dnd ? parent.width - width - 3 : 3
							color: Notifs.dnd ? Theme.bg : Theme.fg
						}

						MouseArea {
							anchors.fill: parent
							preventStealing: true
							onClicked: Notifs.dnd = !Notifs.dnd
						}
					}
				}

							Repeater {
								model: decks
								Item {
									id: deckRow
									required property string sourceKey
									required property string appName
									required property string appIcon
									required property int count
									required property string itemsJson
									Layout.fillWidth: true
									implicitHeight: deck.implicitHeight

									NotifDeck {
										id: deck
										width: deckRow.width
										height: implicitHeight
										sourceKey: deckRow.sourceKey
										appName: deckRow.appName
										appIcon: deckRow.appIcon
										count: deckRow.count
										itemsJson: deckRow.itemsJson
										onFocusRequested: win.focusDeck(deckRow.sourceKey)
										onCloseRequested: function(nid) { win.requestDismiss(nid) }
									}
								}
							}

							Text {
								visible: decks.count === 0
								Layout.fillWidth: true
								horizontalAlignment: Text.AlignHCenter
								text: "No Notifications"
								color: Theme.gray
								font.family: Theme.fontFamily
								font.pixelSize: 14
							}
						}

						ColumnLayout {
							id: focusCol
							visible: win.focusedSource !== ""
							Layout.fillWidth: true
							spacing: 8

							Repeater {
								model: win.focusedNotes
								NotifCard {
									required property var modelData
									Layout.fillWidth: true
									notification: modelData
									onCloseRequested: win.requestDismiss(modelData.id)
								}
							}
						}
					}
					}
				}

				Rectangle {
					visible: pageScroll.contentHeight > pageScroll.height + 1
					width: 4
					color: Theme.red
					x: pageFrame.width - width
					z: 2
					height: Math.max(28, pageScroll.height * pageScroll.height / Math.max(pageScroll.contentHeight, 1))
					y: {
						const span = pageScroll.contentHeight - pageScroll.height
						const travel = Math.max(0, pageScroll.height - height)
						if (span <= 0)
							return 0
						return pageScroll.contentY / span * travel
					}
				}
			}
			ColumnLayout {
				Layout.fillWidth: true
				spacing: 8

				ActionButton {
					Layout.fillWidth: true
					label: "󰖩  Wi-Fi networks"
					onTriggered: ShellState.centerPage = "wifi"
				}
				ActionButton {
					Layout.fillWidth: true
					label: "󰲝  Advanced network"
					onTriggered: {
						ShellState.closeTransient()
						Quickshell.execDetached(["ghostty", "--class=org.nmtui.nmtui", "-e", "nmtui"])
					}
				}
				ActionButton {
					Layout.fillWidth: true
					label: Mullvad.on ? "󰖂  Mullvad disconnect" : "󰖂  Mullvad connect"
					onTriggered: Mullvad.toggle()
				}
				ActionButton {
					Layout.fillWidth: true
					label: "󰏖  Mullvad app"
					onTriggered: {
						ShellState.closeTransient()
						Quickshell.execDetached(["mullvad-vpn"])
					}
				}
				ActionButton {
					Layout.fillWidth: true
					label: "  Lock"
					onTriggered: ShellState.requestLock()
				}
			}

			ColumnLayout {
				Layout.fillWidth: true
				spacing: 8

				RowLayout {
					Layout.fillWidth: true
					Text {
						text: Networking.wifiEnabled ? "Radio on" : "Radio off"
						color: Theme.gray
						font.family: Theme.fontFamily
						font.pixelSize: 13
					}
					Item { Layout.fillWidth: true }
					ActionButton {
						label: "Rescan"
						onTriggered: win.enableScan()
					}
				}

				Text {
					visible: win.wifiScanning || win.networks.length === 0
					text: win.wifiScanning ? "Scanning..." : "No networks"
					color: Theme.gray
					font.family: Theme.fontFamily
					font.pixelSize: 13
				}

				ListView {
					Layout.fillWidth: true
					Layout.preferredHeight: Math.min(200, Math.max(contentHeight, win.networks.length === 0 ? 28 : 0))
					clip: true
					spacing: 4
					model: win.networks

					delegate: Rectangle {
						required property var modelData
						width: ListView.view.width
						height: 40
						radius: 0
						color: netMouse.containsMouse || modelData.connected ? Theme.orange : "transparent"

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: 8
							anchors.rightMargin: 8

							Text {
								text: Theme.signalText(modelData)
								color: netMouse.containsMouse || modelData.connected ? Theme.bg : Theme.yellow
								font.family: Theme.monoFamily
								font.pixelSize: 13
							}
							Text {
								Layout.fillWidth: true
								text: modelData.name + (modelData.connected ? "  ●" : "")
								color: netMouse.containsMouse || modelData.connected ? Theme.bg : Theme.fg
								font.family: Theme.fontFamily
								font.pixelSize: 14
								elide: Text.ElideRight
							}
							Text {
								text: modelData.securityLabel || ""
								color: netMouse.containsMouse || modelData.connected ? Theme.bg : Theme.gray
								font.family: Theme.fontFamily
								font.pixelSize: 12
							}
						}

						MouseArea {
							id: netMouse
							anchors.fill: parent
							hoverEnabled: true
							onClicked: win.connectNet(modelData)
						}
					}
				}

				Rectangle {
					visible: ShellState.wifiTarget !== ""
					Layout.fillWidth: true
					implicitHeight: 42
					radius: 0
					color: Theme.bgAlt
					border.width: 2
					border.color: Theme.red

					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: 10
						anchors.rightMargin: 4
						spacing: 8

						TextInput {
							id: password
							Layout.fillWidth: true
							echoMode: TextInput.Password
							color: Theme.yellow
							font.family: Theme.fontFamily
							font.pixelSize: 14
							clip: true
							Keys.onReturnPressed: win.submitPassword()
							Keys.onEnterPressed: win.submitPassword()
							Keys.onEscapePressed: ShellState.wifiTarget = ""
						}

						ActionButton {
							label: "Connect"
							onTriggered: win.submitPassword()
						}
					}
				}
			}
			}
		}
	}

	Process {
		id: wifiProc
		command: ["sh", "-c", "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan yes; printf '\\n---SAVED---\\n'; nmcli -t -f NAME connection show"]
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: win.applyWifi(text)
		}
	}

	Process {
		id: pskProc
		property string secret: ""
		stdinEnabled: true
		onStarted: {
			pskProc.write(pskProc.secret + "\n")
			pskProc.secret = ""
		}
		onExited: secret = ""
		stderr: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				const err = text.trim()
				if (err)
					console.warn("wifi connect:", err)
			}
		}
	}

	component Vol: Rectangle {
		property real value: 0
		property real maxValue: 1.5
		signal moved(real value)

		Layout.fillWidth: true
		Layout.minimumWidth: 64
		implicitWidth: 120
		implicitHeight: 12
		radius: 0
		color: Theme.bgHover

		Rectangle {
			width: Math.max(0, Math.min(parent.width, parent.width * (parent.value / parent.maxValue)))
			height: parent.height
			radius: 0
			color: Theme.orange
		}

		MouseArea {
			anchors.fill: parent
			preventStealing: true
			onPressed: event => parent.moved(Math.max(0, Math.min(parent.maxValue, event.x / width * parent.maxValue)))
			onPositionChanged: event => {
				if (pressed)
					parent.moved(Math.max(0, Math.min(parent.maxValue, event.x / width * parent.maxValue)))
			}
		}
	}

	component MediaButton: Rectangle {
		property string label: ""
		property bool canUse: true
		signal triggered()

		Layout.preferredWidth: 32
		Layout.preferredHeight: 32
		radius: 0
		color: mouse.containsMouse && canUse ? Theme.orange : "transparent"
		opacity: canUse ? 1 : 0.35

		Text {
			anchors.centerIn: parent
			text: label
			color: mouse.containsMouse && canUse ? Theme.bg : Theme.yellow
			font.family: Theme.fontFamily
			font.pixelSize: 16
		}

		MouseArea {
			id: mouse
			anchors.fill: parent
			hoverEnabled: true
			preventStealing: true
			enabled: parent.canUse
			onClicked: triggered()
		}
	}

	component ActionButton: Rectangle {
		property string label: ""
		property bool active: false
		signal triggered()

		implicitWidth: labelText.implicitWidth + 28
		implicitHeight: 42
		radius: 0
		color: active || mouse.containsMouse ? Theme.orange : Theme.bgAlt
		border.width: 2
		border.color: Theme.red

		Text {
			id: labelText
			anchors.centerIn: parent
			text: label
			color: active || mouse.containsMouse ? Theme.bg : Theme.yellow
			font.family: Theme.fontFamily
			font.pixelSize: 15
		}

		MouseArea {
			id: mouse
			anchors.fill: parent
			hoverEnabled: true
			preventStealing: true
			onClicked: triggered()
		}
	}
}

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
	property var history: Notifs.history()
	readonly property var streams: streamList()
	property var networks: []
	property bool wifiScanning: false

	function streamList() {
		const nodes = Pipewire.nodes.values
		const out = []
		for (let i = 0; i < nodes.length; i++) {
			if (nodes[i].isStream && nodes[i].audio)
				out.push(nodes[i])
		}
		return out
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

	function submitPassword() {
		if (!ShellState.wifiTarget || !password.text)
			return
		Quickshell.execDetached(["nmcli", "device", "wifi", "connect", ShellState.wifiTarget, "password", password.text])
		password.text = ""
		ShellState.wifiTarget = ""
	}

	function refreshMullvad() {
		if (!mullvadProc.running)
			mullvadProc.running = true
	}

	implicitWidth: 400
	implicitHeight: Math.min(460, Math.max(180, body.implicitHeight + 24))
	color: "transparent"
	visible: ShellState.centerOpen && anchorItem !== null
	grabFocus: true
	anchor.window: anchorWindow
	anchor.item: anchorItem
	anchor.edges: Edges.Bottom
	anchor.gravity: Edges.Bottom
	anchor.margins.top: 6
	anchor.adjustment: PopupAdjustment.Slide

	onVisibleChanged: {
		if (!visible) {
			if (ShellState.centerOpen)
				ShellState.centerOpen = false
			return
		}
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
			if (!ShellState.centerOpen)
				return
			if (ShellState.centerPage === "gear")
				win.refreshMullvad()
			if (ShellState.centerPage === "wifi")
				win.enableScan()
		}
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
			anchors.margins: 12
			spacing: 10

			RowLayout {
				Layout.fillWidth: true

				Rectangle {
					visible: ShellState.centerPage !== "main"
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
							ShellState.wifiTarget = ""
							ShellState.centerPage = "main"
						}
					}
				}

				Text {
					Layout.fillWidth: true
					text: ShellState.centerPage === "wifi" ? "Wi-Fi" : ShellState.centerPage === "gear" ? "Settings" : "Notifications"
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
						onClicked: Notifs.clearAll()
					}
				}
			}

			StackLayout {
				Layout.fillWidth: true
				currentIndex: ShellState.centerPage === "gear" ? 1 : ShellState.centerPage === "wifi" ? 2 : 0

			ColumnLayout {
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
							text: modelData.description || modelData.name || "Stream"
							color: Theme.fg
							font.family: Theme.fontFamily
							font.pixelSize: 12
							elide: Text.ElideRight
						}

						Vol {
							maxValue: 1
							value: modelData.audio ? modelData.audio.volume : 0
							onMoved: volume => {
								if (modelData.ready && modelData.audio)
									modelData.audio.volume = volume
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
							onClicked: Notifs.dnd = !Notifs.dnd
						}
					}
				}

				ListView {
					id: notifList
					Layout.fillWidth: true
					Layout.preferredHeight: Math.min(200, Math.max(contentHeight, notifList.count === 0 && contentHeight < 1 ? 28 : 0))
					clip: true
					spacing: 8
					// A fresh javascript array makes ListView destroy and recreate every card.
					// That runs inside the close click and takes the popup down with it.
					// ScriptModel removes only the dismissed row, so the rest of the center stays.
					model: ScriptModel {
						values: win.history
						objectProp: "id"
						comparisonMode: ObjectComparison.Identity
					}

					delegate: Item {
						id: row
						required property var modelData
						width: ListView.view.width
						height: shownHeight
						clip: true
						opacity: 1
						property bool leaving: false
						property real shownHeight: card.implicitHeight

						ParallelAnimation {
							id: leaveAnim
							NumberAnimation {
								target: row
								property: "shownHeight"
								to: 0
								duration: 180
								easing.type: Easing.OutCubic
							}
							NumberAnimation {
								target: row
								property: "opacity"
								to: 0
								duration: 140
								easing.type: Easing.OutCubic
							}
							onFinished: {
								const id = row.modelData ? row.modelData.id : 0
								Qt.callLater(() => {
									const notification = Notifs.find(id)
									if (notification)
										notification.dismiss()
								})
							}
						}

						NotifCard {
							id: card
							width: parent.width
							notification: row.modelData
							onCloseRequested: {
								if (row.leaving)
									return
								row.leaving = true
								// Drop the height binding so the collapse can run.
								row.shownHeight = card.implicitHeight
								leaveAnim.start()
							}
						}
					}

					Text {
						anchors.centerIn: parent
						visible: notifList.count === 0 && notifList.contentHeight < 1
						text: "No Notifications"
						color: Theme.gray
						font.family: Theme.fontFamily
						font.pixelSize: 14
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
					label: ShellState.mullvadOn ? "󰖂  Mullvad disconnect" : "󰖂  Mullvad connect"
					onTriggered: {
						Quickshell.execDetached(["mullvad", ShellState.mullvadOn ? "disconnect" : "connect"])
						retryMullvad.start()
					}
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
		id: mullvadProc
		command: ["mullvad", "status"]
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				const value = text.toLowerCase()
				ShellState.mullvadOn = value.indexOf("disconnected") === -1 && value.indexOf("connected") !== -1
			}
		}
	}

	Timer {
		id: retryMullvad
		interval: 1500
		onTriggered: win.refreshMullvad()
	}

	component Vol: Rectangle {
		property real value: 0
		property real maxValue: 1.5
		signal moved(real value)

		Layout.fillWidth: true
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
			onClicked: triggered()
		}
	}
}

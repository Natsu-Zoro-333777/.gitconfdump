import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets

Variants {
	model: Quickshell.screens

	PanelWindow {
		id: win

		required property var modelData

		property var monitor: Mango.monitorFor(modelData.name)
		property var tags: monitor && monitor.tags ? monitor.tags : []
		property string layoutSymbol: monitor && monitor.layout_symbol ? monitor.layout_symbol : ""
		property var device: UPower.displayDevice
		property int shownTasks: taskCount()
		property int desktopRev: 0

		Connections {
			target: DesktopEntries
			function onApplicationsChanged() {
				win.desktopRev++
			}
		}

		function clientOnActiveTag(client) {
			if (!client || !client.tags)
				return false
			const active = tags
			for (let i = 0; i < client.tags.length; i++) {
				for (let j = 0; j < active.length; j++) {
					if (active[j].is_active && active[j].index == client.tags[i])
						return true
				}
			}
			return false
		}

		function clientFor(toplevel) {
			if (!toplevel)
				return null
			const appId = toplevel.appId || ""
			const title = toplevel.title || ""
			const screen = modelData.name
			const clients = Mango.clients
			let onlyApp = null
			let appCount = 0
			let titleMatch = null
			for (let i = 0; i < clients.length; i++) {
				const client = clients[i]
				if (client.is_minimized || client.is_scratchpad)
					continue
				if (screen && client.monitor && client.monitor !== screen)
					continue
				if ((client.appid || "") !== appId)
					continue
				appCount++
				if (!onlyApp)
					onlyApp = client
				if ((client.title || "") !== title)
					continue
				if (clientOnActiveTag(client))
					return client
				if (!titleMatch)
					titleMatch = client
			}
			if (titleMatch)
				return titleMatch
			return appCount === 1 ? onlyApp : null
		}

		function taskVisible(toplevel) {
			if (!toplevel || toplevel.minimized)
				return false
			const screens = toplevel.screens
			if (screens && screens.length > 0) {
				let here = false
				for (let i = 0; i < screens.length; i++) {
					if (screens[i].name === modelData.name)
						here = true
				}
				if (!here)
					return false
			}
			return clientOnActiveTag(clientFor(toplevel))
		}

		function taskCount() {
			const values = ToplevelManager.toplevels.values
			let count = 0
			for (let i = 0; i < values.length; i++) {
				if (taskVisible(values[i]))
					count++
			}
			return count
		}

		screen: modelData
		color: "transparent"
		implicitHeight: 72
		anchors.top: true
		anchors.left: true
		anchors.right: true
		exclusionMode: ExclusionMode.Auto
		WlrLayershell.namespace: "quickshell-bar"
		WlrLayershell.layer: WlrLayer.Top

		component Sep: Item {
			property color ink: Theme.orange
			width: 14
			height: 44

			Rectangle {
				anchors.centerIn: parent
				width: 2
				height: 22
				radius: 0
				color: ink
			}
		}

		RowLayout {
			anchors.fill: parent
			anchors.leftMargin: 10
			anchors.rightMargin: 10
			anchors.topMargin: 10
			anchors.bottomMargin: 6
			spacing: 0

			Rectangle {
				id: barBox
				Layout.fillWidth: true
				Layout.fillHeight: true
				radius: 0
				color: "#1a282828"
				border.width: 3
				border.color: Theme.red
				clip: true

				Row {
					id: leftRow
					anchors.left: parent.left
					anchors.leftMargin: 4
					anchors.verticalCenter: parent.verticalCenter
					spacing: 0

					Rectangle {
						id: start
						width: 52
						height: 42
						color: startMouse.containsMouse || ShellState.launcherOpen ? Theme.orange : "transparent"
						topLeftRadius: 0
						bottomLeftRadius: 0
						topRightRadius: 0
						bottomRightRadius: 0

						Image {
							id: startIcon
							anchors.centerIn: parent
							width: 28
							height: 28
							sourceSize.width: 64
							sourceSize.height: 64
							fillMode: Image.PreserveAspectFit
							source: "file:///usr/share/pixmaps/archlinux-logo.svg"
							visible: status === Image.Ready
						}

						Text {
							anchors.centerIn: parent
							visible: !startIcon.visible
							text: "A"
							color: startMouse.containsMouse || ShellState.launcherOpen ? Theme.bg : Theme.yellow
							font.family: Theme.fontFamily
							font.pixelSize: 20
							font.bold: true
						}

						Rectangle {
							anchors.right: parent.right
							anchors.verticalCenter: parent.verticalCenter
							width: 2
							height: 22
							radius: 0
							color: startMouse.containsMouse || ShellState.launcherOpen ? Theme.bg : Theme.orange
						}

						MouseArea {
							id: startMouse
							anchors.fill: parent
							hoverEnabled: true
							onClicked: ShellState.toggleLauncher(modelData.name)
							onContainsMouseChanged: {
								if (containsMouse)
									TipState.show(start, "Arch Linux", false)
								else
									TipState.hide(start)
							}
						}
					}

					Item { width: 8; height: 42 }

					Item {
						width: wsRow.implicitWidth
						height: 42

						Row {
							id: wsRow
							anchors.verticalCenter: parent.verticalCenter
							spacing: 2

							Repeater {
								model: win.tags

								Rectangle {
									required property var modelData
									width: 34
									height: 32
									radius: 0
									color: modelData.is_active ? Theme.orange : "transparent"

									Text {
										anchors.centerIn: parent
										text: Theme.tagIcons[modelData.index] || ("" + modelData.index)
										color: {
											if (modelData.is_urgent)
												return Theme.red
											if (modelData.is_active)
												return Theme.bg
											if (modelData.client_count > 0)
												return Theme.orange
											return Theme.muted
										}
										font.family: Theme.fontFamily
										font.pixelSize: 18
									}

									MouseArea {
										anchors.fill: parent
										hoverEnabled: true
										onClicked: Mango.viewTag(modelData.index)
										onWheel: event => event.angleDelta.y > 0 ? Mango.viewLeft() : Mango.viewRight()
										onEntered: parent.color = Theme.orange
										onExited: parent.color = modelData.is_active ? Theme.orange : "transparent"
									}
								}
							}
						}
					}

					Sep { visible: win.shownTasks > 0 }

					Item {
						visible: win.shownTasks > 0
						width: visible ? taskRow.implicitWidth : 0
						height: 42

						Row {
							id: taskRow
							anchors.verticalCenter: parent.verticalCenter
							spacing: 4

							Repeater {
								id: taskRepeater
								model: ToplevelManager.toplevels

								Item {
									id: taskItem
									required property var modelData
									visible: win.taskVisible(modelData)
									width: visible ? 32 : 0
									height: 32

									Rectangle {
										anchors.fill: parent
										radius: 0
										color: modelData.activated ? Theme.orange : "transparent"
									}

									IconImage {
										id: taskIcon
										anchors.centerIn: parent
										implicitSize: 24
										source: {
											void win.desktopRev
											const entry = DesktopEntries.heuristicLookup(modelData.appId || "")
											return entry && entry.icon ? Theme.iconSource(entry.icon) : ""
										}
									}

									Text {
										anchors.centerIn: parent
										visible: taskIcon.status !== Image.Ready
										text: (modelData.appId || "?").charAt(0).toUpperCase()
										color: modelData.activated ? Theme.bg : Theme.orange
										font.family: Theme.fontFamily
										font.pixelSize: 16
									}

									MouseArea {
										anchors.fill: parent
										hoverEnabled: true
										acceptedButtons: Qt.LeftButton | Qt.MiddleButton
										onContainsMouseChanged: {
											const label = modelData.title || modelData.appId || ""
											if (containsMouse && label)
												TipState.show(taskItem, label, false)
											else
												TipState.hide(taskItem)
										}
										onClicked: event => {
											if (event.button === Qt.MiddleButton)
												modelData.close()
											else
												modelData.activate()
										}
									}
								}
							}
						}
					}

					Sep { visible: trayRepeater.count > 0 }

					Item {
						visible: trayRepeater.count > 0
						width: visible ? trayRow.implicitWidth : 0
						height: 42

						Row {
							id: trayRow
							anchors.verticalCenter: parent.verticalCenter
							spacing: 4

							Repeater {
								id: trayRepeater
								model: SystemTray.items

								Item {
									id: trayItem
									required property var modelData
									width: 28
									height: 28

									IconImage {
										anchors.fill: parent
										source: modelData.icon
									}

									MouseArea {
										anchors.fill: parent
										hoverEnabled: true
										acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
										onClicked: event => {
											if (event.button === Qt.RightButton || modelData.onlyMenu)
												modelData.display(win, width / 2, height)
											else if (event.button === Qt.MiddleButton)
												modelData.secondaryActivate()
											else
												modelData.activate()
										}
										onPressAndHold: modelData.display(win, width / 2, height)
										onContainsMouseChanged: {
											const label = modelData.tooltipTitle || modelData.title || ""
											if (containsMouse && label)
												TipState.show(trayItem, label, false)
											else
												TipState.hide(trayItem)
										}
									}
								}
							}
						}
					}

					Sep {}

					Item {
						id: notifCell
						width: 40
						height: 42

						Rectangle {
							anchors.fill: parent
							color: ShellState.centerOpen ? Theme.orange : "transparent"
						}

						Text {
							anchors.centerIn: parent
							text: Notifs.icon()
							color: ShellState.centerOpen ? Theme.bg : Theme.yellow
							font.family: Theme.fontFamily
							font.pixelSize: 18
						}

						MouseArea {
							anchors.fill: parent
							hoverEnabled: true
							acceptedButtons: Qt.LeftButton | Qt.RightButton
							onClicked: event => {
								if (event.button === Qt.RightButton)
									Notifs.dnd = !Notifs.dnd
								else
									ShellState.toggleCenter()
							}
							onContainsMouseChanged: {
								if (containsMouse)
									TipState.show(notifCell, Notifs.dnd ? "Do not disturb" : "Notifications", false)
								else
									TipState.hide(notifCell)
							}
						}
					}

					Item { width: 8; height: 42 }
				}

				SystemClock {
					id: clock
					precision: SystemClock.Minutes
				}

				Text {
					id: timeText
					z: 2
					anchors.centerIn: parent
					text: Qt.formatDateTime(clock.date, "hh:mm")
					color: Theme.yellow
					font.family: Theme.monoFamily
					font.pixelSize: 22
					font.kerning: false
				}

				MouseArea {
					id: clockHover
					z: 2
					anchors.fill: timeText
					hoverEnabled: true
					onContainsMouseChanged: {
						if (containsMouse)
							TipState.show(clockHover, Theme.calendar(clock.date), true)
						else
							TipState.hide(clockHover)
					}
				}

				Row {
					id: rightRow
					anchors.right: parent.right
					anchors.rightMargin: 4
					anchors.verticalCenter: parent.verticalCenter
					spacing: 0

					Item { width: 8; height: 42 }

					Item {
						id: layoutCell
						width: 44
						height: 42

						Text {
							anchors.centerIn: parent
							text: win.layoutSymbol || "·"
							color: Theme.yellow
							font.family: Theme.fontFamily
							font.pixelSize: 18
							font.bold: true
						}

						MouseArea {
							anchors.fill: parent
							hoverEnabled: true
							onClicked: Mango.switchLayout()
							onContainsMouseChanged: {
								const label = Mango.layoutName(win.layoutSymbol) || win.layoutSymbol
								if (containsMouse && label)
									TipState.show(layoutCell, label, false)
								else
									TipState.hide(layoutCell)
							}
						}
					}

					Sep { ink: Theme.red }

					Item {
						id: audioCell
						width: 44
						height: 42

						Text {
							anchors.centerIn: parent
							text: Theme.audioIcon(Pipewire.defaultAudioSink)
							color: Theme.yellow
							font.family: Theme.fontFamily
							font.pixelSize: 20
						}

						MouseArea {
							id: audioMouse
							anchors.fill: parent
							hoverEnabled: true
							acceptedButtons: Qt.LeftButton | Qt.RightButton

							function tip() {
								const sink = Pipewire.defaultAudioSink
								if (!sink || !sink.ready || !sink.audio)
									return "Audio"
								const name = sink.description || sink.name || "Audio"
								const level = sink.audio.muted ? "Muted" : Theme.audioPercent(sink) + "%"
								return name + "\n" + level
							}

							function showTip() {
								if (containsMouse)
									TipState.show(audioCell, tip(), false)
							}

							onClicked: event => {
								const sink = Pipewire.defaultAudioSink
								if (event.button === Qt.RightButton && sink && sink.ready && sink.audio)
									sink.audio.muted = !sink.audio.muted
								else
									Quickshell.execDetached(["env", "GTK_THEME=Adwaita:dark", "pavucontrol"])
								showTip()
							}
							onWheel: event => {
								const sink = Pipewire.defaultAudioSink
								if (!sink || !sink.ready || !sink.audio)
									return
								const step = event.angleDelta.y > 0 ? 0.05 : -0.05
								sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + step))
								showTip()
							}
							onContainsMouseChanged: {
								if (containsMouse)
									showTip()
								else
									TipState.hide(audioCell)
							}
						}

						Connections {
							target: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio : null
							function onVolumesChanged() { audioMouse.showTip() }
							function onMutedChanged() { audioMouse.showTip() }
						}
					}

					Sep { ink: Theme.red }

					Item {
						id: netCell
						width: 44
						height: 42

						Text {
							anchors.centerIn: parent
							text: Theme.networkIcon()
							color: Theme.yellow
							font.family: Theme.fontFamily
							font.pixelSize: 20
						}

						MouseArea {
							id: netMouse
							anchors.fill: parent
							hoverEnabled: true
							acceptedButtons: Qt.LeftButton | Qt.RightButton
							onClicked: event => {
								if (event.button === Qt.RightButton)
									Networking.wifiEnabled = !Networking.wifiEnabled
								else
									ShellState.openCenter("wifi")
							}
							onContainsMouseChanged: {
								if (containsMouse)
									TipState.show(netCell, Theme.networkTip(), false)
								else
									TipState.hide(netCell)
							}
						}

						Connections {
							target: Sysmon
							function onNetRatesChanged() {
								if (netMouse.containsMouse)
									TipState.show(netCell, Theme.networkTip(), false)
							}
						}
					}

					Sep { ink: Theme.red }

					Item {
						id: cpuCell
						width: cpuRow.implicitWidth + 16
						height: 42

						Row {
							id: cpuRow
							anchors.centerIn: parent
							spacing: 6

							Text {
								height: 24
								verticalAlignment: Text.AlignVCenter
								text: ""
								color: Theme.yellow
								font.family: Theme.fontFamily
								font.pixelSize: 20
							}

							Text {
								height: 24
								verticalAlignment: Text.AlignVCenter
								text: Sysmon.cpuLabel()
								color: Theme.yellow
								font.family: Theme.fontFamily
								font.pixelSize: 15
							}
						}

						MouseArea {
							anchors.fill: parent
							hoverEnabled: true
							onContainsMouseChanged: {
								if (containsMouse)
									TipState.show(cpuCell, Sysmon.cpuTip(), true)
								else
									TipState.hide(cpuCell)
							}
						}
					}

					Sep { ink: Theme.red }

					Item {
						id: memCell
						width: memRow.implicitWidth + 16
						height: 42

						Row {
							id: memRow
							anchors.centerIn: parent
							spacing: 6

							Text {
								height: 24
								verticalAlignment: Text.AlignVCenter
								text: ""
								color: Theme.yellow
								font.family: Theme.fontFamily
								font.pixelSize: 20
							}

							Text {
								height: 24
								verticalAlignment: Text.AlignVCenter
								text: Sysmon.memLabel()
								color: Theme.yellow
								font.family: Theme.fontFamily
								font.pixelSize: 15
							}
						}

						MouseArea {
							anchors.fill: parent
							hoverEnabled: true
							onContainsMouseChanged: {
								if (containsMouse)
									TipState.show(memCell, Sysmon.memTip(), true)
								else
									TipState.hide(memCell)
							}
						}
					}

					Sep {
						ink: Theme.red
						visible: battCell.visible
					}

					Item {
						id: battCell
						visible: win.device && win.device.ready && win.device.isPresent && win.device.percentage >= 0
						width: visible ? battRow.implicitWidth + 16 : 0
						height: 42

						Row {
							id: battRow
							anchors.centerIn: parent
							spacing: 6

							Text {
								height: 24
								verticalAlignment: Text.AlignVCenter
								text: Sysmon.batteryIcon()
								color: {
									const state = win.device ? UPowerDeviceState.toString(win.device.state) : ""
									if (state === "Discharging" && Sysmon.batteryPercent(win.device) <= 15)
										return Theme.red
									if (Sysmon.charging)
										return Theme.orange
									return Theme.yellow
								}
								font.family: Theme.fontFamily
								font.pixelSize: 20
							}

							Text {
								height: 24
								verticalAlignment: Text.AlignVCenter
								text: Math.round(Sysmon.batteryPercent(win.device)) + "%"
								color: Theme.yellow
								font.family: Theme.fontFamily
								font.pixelSize: 15
							}
						}

						MouseArea {
							anchors.fill: parent
							hoverEnabled: true
							onContainsMouseChanged: {
								if (!containsMouse || !win.device) {
									TipState.hide(battCell)
									return
								}
								TipState.show(battCell, Sysmon.batteryLife(win.device), false)
							}
						}
					}

					Sep { ink: Theme.red }

					Item {
						id: weatherCell
						width: 44
						height: 42

						Text {
							id: weatherText
							anchors.centerIn: parent
							text: Sysmon.weatherIcon
							color: Theme.yellow
							font.family: "Noto Color Emoji"
							font.pixelSize: 18
						}

						MouseArea {
							id: weatherMouse
							anchors.fill: parent
							hoverEnabled: true
							acceptedButtons: Qt.LeftButton | Qt.RightButton
							onClicked: event => {
								if (event.button === Qt.RightButton)
									Sysmon.refreshWeather(true)
								else
									Quickshell.execDetached(["xdg-open", "https://wttr.in/" + Sysmon.weatherLocation])
							}
							onContainsMouseChanged: {
								if (containsMouse)
									TipState.show(weatherCell, Sysmon.weatherTip(), true)
								else
									TipState.hide(weatherCell)
							}
						}

						Connections {
							target: Sysmon
							function onWeatherChanged() {
								if (weatherMouse.containsMouse)
									TipState.show(weatherCell, Sysmon.weatherTip(), true)
							}
						}
					}

					Item { width: 8; height: 42 }
				}
			}
		}

		Launcher {
			anchorWindow: win
			anchorItem: start
		}

		ControlCenter {
			anchorWindow: win
			anchorItem: notifCell
		}

		PopupWindow {
			id: tipWindow
			visible: TipState.text !== "" && TipState.item !== null
			color: "transparent"
			implicitWidth: tipLabel.implicitWidth + 18
			implicitHeight: tipLabel.implicitHeight + 12
			anchor.window: win
			anchor.item: TipState.item
			anchor.edges: Edges.Bottom
			anchor.gravity: Edges.Bottom
			anchor.margins.top: 6

			Rectangle {
				anchors.fill: parent
				radius: 0
				color: Theme.bg
				border.width: 2
				border.color: Theme.red

				Text {
					id: tipLabel
					anchors.centerIn: parent
					text: TipState.text
					color: Theme.fg
					font.family: TipState.mono ? Theme.monoFamily : Theme.fontFamily
					font.pixelSize: 13
					wrapMode: Text.NoWrap
				}
			}
		}
	}
}

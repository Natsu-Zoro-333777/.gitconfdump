import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
	id: win

	property var entries: []
	property int selected: 0
	property string query: ""

	function load() {
		if (!listProc.running)
			listProc.running = true
	}

	function filtered() {
		const needle = query.toLowerCase().trim()
		if (!needle)
			return entries
		const out = []
		for (let i = 0; i < entries.length; i++) {
			if (entries[i].preview.toLowerCase().indexOf(needle) !== -1)
				out.push(entries[i])
		}
		return out
	}

	function copy(entry) {
		if (!entry)
			return
		Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | cliphist decode | wl-copy", "cliphist", entry.raw])
		ShellState.closeTransient()
	}

	function remove(entry) {
		if (!entry)
			return
		Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | cliphist delete", "cliphist", entry.raw])
		const next = []
		for (let i = 0; i < entries.length; i++) {
			if (entries[i].raw !== entry.raw)
				next.push(entries[i])
		}
		entries = next
	}

	anchors.top: true
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	visible: ShellState.clipboardOpen
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell-clipboard"
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

	onVisibleChanged: {
		if (visible) {
			query = ""
			selected = 0
			input.text = ""
			load()
			input.forceActiveFocus()
		}
	}

	MouseArea {
		anchors.fill: parent
		onClicked: ShellState.closeTransient()
	}

	Rectangle {
		id: box
		width: 700
		height: 420
		anchors.centerIn: parent
		radius: 0
		color: Theme.bg
		border.width: 3
		border.color: Theme.red

		MouseArea {
			z: -1
			anchors.fill: parent
			onClicked: {}
		}

		Column {
			anchors.fill: parent

			RowLayout {
				width: parent.width
				height: 48
				spacing: 8

				Item { width: 4 }

				Text {
					text: ""
					color: Theme.yellow
					font.family: Theme.fontFamily
					font.pixelSize: 16
				}

				TextInput {
					id: input
					Layout.fillWidth: true
					color: Theme.yellow
					selectionColor: Theme.orange
					selectedTextColor: Theme.bg
					font.family: Theme.fontFamily
					font.pixelSize: 16
					clip: true
					onTextChanged: {
						win.query = text
						win.selected = 0
					}
					Keys.onEscapePressed: ShellState.closeTransient()
					Keys.onUpPressed: event => {
						win.selected = Math.max(0, win.selected - 1)
						event.accepted = true
					}
					Keys.onDownPressed: event => {
						const rows = win.filtered()
						win.selected = Math.min(Math.max(0, rows.length - 1), win.selected + 1)
						event.accepted = true
					}
					Keys.onReturnPressed: {
						const rows = win.filtered()
						win.copy(rows[win.selected])
					}
					Keys.onEnterPressed: {
						const rows = win.filtered()
						win.copy(rows[win.selected])
					}
				}
			}

			Rectangle {
				width: parent.width
				height: 2
				color: Theme.red
			}

			ListView {
				id: list
				width: parent.width
				height: parent.height - 50
				clip: true
				spacing: 4
				topMargin: 8
				bottomMargin: 8
				leftMargin: 8
				rightMargin: 8
				model: win.filtered()
				currentIndex: win.selected

				delegate: Rectangle {
					required property int index
					required property var modelData
					width: list.width - 16
					height: 40
					radius: 0
					color: index === win.selected ? Theme.orange : "transparent"

					Text {
						anchors.fill: parent
						anchors.leftMargin: 10
						anchors.rightMargin: 10
						verticalAlignment: Text.AlignVCenter
						text: modelData.preview
						color: index === win.selected ? Theme.bg : Theme.fg
						font.family: Theme.fontFamily
						font.pixelSize: 14
						elide: Text.ElideRight
					}

					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						acceptedButtons: Qt.LeftButton | Qt.MiddleButton
						onEntered: win.selected = index
						onClicked: event => {
							if (event.button === Qt.MiddleButton)
								win.remove(modelData)
							else
								win.copy(modelData)
						}
					}
				}

				Text {
					anchors.centerIn: parent
					visible: list.count === 0
					text: "Clipboard is empty"
					color: Theme.gray
					font.family: Theme.fontFamily
					font.pixelSize: 14
				}
			}
		}
	}

	Process {
		id: listProc
		command: ["cliphist", "list"]
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				const rows = []
				const lines = text.split("\n")
				for (let i = 0; i < lines.length; i++) {
					const line = lines[i]
					if (!line)
						continue
					const tab = line.indexOf("\t")
					let preview = tab >= 0 ? line.slice(tab + 1) : line
					preview = preview.replace(/\s+/g, " ").trim()
					if (!preview)
						preview = "(empty)"
					rows.push({
						raw: line,
						preview: preview
					})
				}
				win.entries = rows
			}
		}
	}
}

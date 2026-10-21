import QtQuick
import Quickshell
import Quickshell.Wayland
import "usage-rank.js" as UsageRank

// An exclusive overlay gets the keyboard. The layer stays mapped and fades
// in place, so closing it does not leave a ghost of the menu.
PanelWindow {
	id: win

	property var anchorWindow: null
	property var anchorItem: null
	property string query: ""
	property string category: "all"
	property int selected: 0
	property int rev: 0
	property real grow: 0.08
	property real fade: 0

	readonly property int menuWidth: 700
	readonly property int menuHeight: 520
	readonly property int catWidth: 232
	readonly property string shownCategory: query.trim() ? "all" : category
	readonly property var catalog: buildCatalog()
	readonly property var categories: buildCategories()
	readonly property var entries: buildEntries()

	// Top-level menus follow plasma-applications.menu. An app is listed in
	// every menu it matches, and in Lost & Found when it matches none.
	function menuSpecs() {
		return [
			{ id: "development", name: "Development", icon: "", keys: ["Development"] },
			{ id: "science", name: "Science & Math", icon: "", keys: ["Science", "Math", "Astronomy", "Biology", "Chemistry", "Geology", "MedicalSoftware", "Physics"], exclude: ["Education"] },
			{ id: "education", name: "Education", icon: "", keys: ["Education"] },
			{ id: "games", name: "Games", icon: "", keys: ["Game"], suffix: "Game" },
			{ id: "graphics", name: "Graphics", icon: "", keys: ["Graphics"] },
			{ id: "internet", name: "Internet", icon: "", keys: ["Network"] },
			{ id: "multimedia", name: "Multimedia", icon: "", keys: ["AudioVideo", "Audio", "Video"] },
			{ id: "office", name: "Office", icon: "", keys: ["Office"] },
			{ id: "system", name: "System", icon: "", keys: ["System", "Settings", "Monitor", "TerminalEmulator"] },
			{ id: "utilities", name: "Utilities", icon: "", keys: ["Utility", "TextEditor", "Accessibility", "FileManager", "FileTools"] },
			{ id: "help", name: "Help", icon: "", keys: ["Documentation"] }
		]
	}

	function matchesSpec(cats, spec) {
		if (spec.exclude) {
			for (let i = 0; i < spec.exclude.length; i++) {
				if (cats.indexOf(spec.exclude[i]) !== -1)
					return false
			}
		}
		for (let i = 0; i < cats.length; i++) {
			const cat = cats[i]
			if (spec.keys.indexOf(cat) !== -1)
				return true
			if (spec.suffix && cat.length > spec.suffix.length && cat.endsWith(spec.suffix))
				return true
		}
		return false
	}

	function buildCatalog() {
		void rev
		void ShellState.launcherOpen
		void AppUsage.apps
		const specs = menuSpecs()
		const apps = DesktopEntries.applications.values
		const items = []
		for (let i = 0; i < apps.length; i++) {
			const app = apps[i]
			if (!app || app.noDisplay || !(app.name || ""))
				continue
			const raw = app.categories || []
			const cats = []
			for (let c = 0; c < raw.length; c++) {
				if (raw[c])
					cats.push(raw[c])
			}
			const homeIds = []
			const homeNames = []
			for (let s = 0; s < specs.length; s++) {
				if (!matchesSpec(cats, specs[s]))
					continue
				homeIds.push(specs[s].id)
				homeNames.push(specs[s].name)
			}
			if (homeIds.length === 0) {
				homeIds.push("lost")
				homeNames.push("Lost & Found")
			}
			let keywords = ""
			if (app.keywords) {
				for (let k = 0; k < app.keywords.length; k++)
					keywords += " " + app.keywords[k]
			}
			items.push({
				id: app.id || "",
				title: app.name || "",
				subtitle: app.genericName || app.comment || "",
				icon: app.icon || "",
				app: app,
				homes: homeIds,
				homeNames: homeNames.join(" · "),
				keywords: keywords
			})
		}
		// Most-used apps first (frequency with recency decay), the rest alphabetical.
		return UsageRank.rank(items, id => AppUsage.score(id), AppUsage.promoteLimit)
	}

	function buildCategories() {
		const items = catalog
		const specs = menuSpecs()
		const counts = { lost: 0 }
		for (let s = 0; s < specs.length; s++)
			counts[specs[s].id] = 0
		for (let i = 0; i < items.length; i++) {
			const homes = items[i].homes
			for (let h = 0; h < homes.length; h++)
				counts[homes[h]] = (counts[homes[h]] || 0) + 1
		}
		const out = [{
			id: "all",
			name: "All Applications",
			icon: "󰶻",
			count: items.length
		}]
		for (let s = 0; s < specs.length; s++) {
			if (counts[specs[s].id] > 0) {
				out.push({
					id: specs[s].id,
					name: specs[s].name,
					icon: specs[s].icon,
					count: counts[specs[s].id]
				})
			}
		}
		if (counts.lost > 0) {
			out.push({
				id: "lost",
				name: "Lost & Found",
				icon: "",
				count: counts.lost
			})
		}
		return out
	}

	function buildEntries() {
		const needle = query.toLowerCase().trim()
		const cat = needle ? "all" : category
		const items = catalog
		const out = []
		for (let i = 0; i < items.length; i++) {
			const item = items[i]
			if (cat !== "all" && item.homes.indexOf(cat) === -1)
				continue
			if (needle) {
				const blob = (item.title + " " + item.subtitle + " " + item.homeNames + " " + item.keywords).toLowerCase()
				if (blob.indexOf(needle) === -1)
					continue
			}
			out.push(item)
		}
		return out
	}

	function categoryName() {
		if (query.trim())
			return "Search"
		const list = categories
		for (let i = 0; i < list.length; i++) {
			if (list[i].id === category)
				return list[i].name
		}
		return "All Applications"
	}

	function entrySubtitle(item) {
		if (!item)
			return ""
		if (query.trim() || category === "all")
			return item.homeNames || ""
		return item.subtitle || ""
	}

	function activate(index) {
		const item = entries[index]
		if (!item)
			return
		const app = item.app || DesktopEntries.byId(item.id)
		if (!app)
			return
		AppUsage.note(item.id || app.id || "")
		if (app.runInTerminal) {
			const cmd = ["ghostty", "-e"]
			const parts = app.command
			for (let i = 0; i < parts.length; i++)
				cmd.push(parts[i])
			Quickshell.execDetached(cmd)
		} else {
			app.execute()
		}
		ShellState.closeTransient()
	}

	function move(step) {
		if (entries.length === 0) {
			selected = 0
			return
		}
		selected = (selected + step + entries.length) % entries.length
	}

	function moveCategory(step) {
		const list = categories
		if (list.length === 0)
			return
		let index = 0
		for (let i = 0; i < list.length; i++) {
			if (list[i].id === shownCategory) {
				index = i
				break
			}
		}
		const next = list[(index + step + list.length) % list.length]
		query = ""
		input.text = ""
		category = next.id
		selected = 0
		catList.positionViewAtIndex((index + step + list.length) % list.length, ListView.Contain)
	}

	function monitorActive(name) {
		const list = Niri.monitors
		for (let i = 0; i < list.length; i++) {
			if (list[i].name === name)
				return !!list[i].active
		}
		return list.length <= 1
	}

	function ownsOpen() {
		if (!ShellState.launcherOpen || !anchorWindow || !anchorWindow.screen)
			return false
		const name = anchorWindow.screen.name
		if (ShellState.launcherMonitor)
			return ShellState.launcherMonitor === name
		return monitorActive(name)
	}

	function place() {
		if (!anchorItem)
			return
		const global = anchorItem.mapToGlobal(0, anchorItem.height + 16)
		const local = dismiss.mapFromGlobal(global.x, global.y)
		panel.x = Math.round(local.x)
		panel.y = Math.round(local.y)
	}

	function openMenu() {
		if (!ownsOpen())
			return
		grow = 0.08
		fade = 0
		query = ""
		category = "all"
		selected = 0
		input.text = ""
		place()
		popAnim.restart()
		focusTimer.tries = 0
		focusTimer.start()
		Qt.callLater(place)
	}

	readonly property bool shown: ownsOpen()
	// Full-screen pointer target only while the menu is open. An empty mask
	// makes the rest of the time pass clicks through.
	property bool interactive: false

	screen: anchorWindow ? anchorWindow.screen : null
	anchors.top: true
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	visible: true
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell-launcher"
	WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	mask: Region {
		item: win.interactive ? dismiss : null
	}

	onShownChanged: {
		if (shown) {
			closeAnim.stop()
			interactive = true
			openMenu()
		} else {
			focusTimer.stop()
			interactive = false
			closeAnim.restart()
		}
	}

	onWidthChanged: {
		if (shown)
			place()
	}

	Timer {
		id: focusTimer
		interval: 40
		repeat: true
		property int tries: 0
		onTriggered: {
			if (!win.shown) {
				stop()
				return
			}
			input.forceActiveFocus()
			tries++
			if (input.activeFocus || tries > 15)
				stop()
		}
	}

	Connections {
		target: DesktopEntries
		function onApplicationsChanged() {
			win.rev++
		}
	}

	onSelectedChanged: {
		if (appList && entries.length > 0)
			appList.positionViewAtIndex(selected, ListView.Contain)
	}

	ParallelAnimation {
		id: popAnim
		NumberAnimation {
			target: win
			property: "grow"
			to: 1
			duration: 180
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: win
			property: "fade"
			to: 1
			duration: 120
			easing.type: Easing.OutCubic
		}
	}

	ParallelAnimation {
		id: closeAnim
		NumberAnimation {
			target: win
			property: "grow"
			to: 0.08
			duration: 140
			easing.type: Easing.InCubic
		}
		NumberAnimation {
			target: win
			property: "fade"
			to: 0
			duration: 100
			easing.type: Easing.InCubic
		}
	}

	MouseArea {
		id: dismiss
		anchors.fill: parent
		enabled: win.shown
		onClicked: ShellState.closeTransient()
	}

	MouseArea {
		x: panel.x
		y: panel.y
		width: panel.width
		height: panel.height
		z: 1
		enabled: win.shown
		onClicked: {}
	}

	Rectangle {
		id: panel
		z: 2
		width: win.menuWidth
		height: win.menuHeight
		radius: 0
		color: Theme.bg
		border.width: 3
		border.color: Theme.red
		scale: win.grow
		transformOrigin: Item.TopLeft
		opacity: win.fade
		clip: true

		Rectangle {
			anchors.left: parent.left
			anchors.top: searchBox.bottom
			anchors.bottom: parent.bottom
			width: win.catWidth
			color: Theme.bgAlt
		}

		Item {
			id: searchBox
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: parent.top
			height: 48

			Text {
				anchors.left: parent.left
				anchors.leftMargin: 16
				anchors.verticalCenter: parent.verticalCenter
				text: ""
				color: Theme.yellow
				font.family: Theme.fontFamily
				font.pixelSize: 16
			}

			Text {
				anchors.left: input.left
				anchors.right: input.right
				anchors.verticalCenter: parent.verticalCenter
				visible: input.text === ""
				text: "Search"
				color: Theme.muted
				font.family: Theme.fontFamily
				font.pixelSize: 16
			}

			TextInput {
				id: input
				anchors.left: parent.left
				anchors.leftMargin: 44
				anchors.right: parent.right
				anchors.rightMargin: 12
				anchors.verticalCenter: parent.verticalCenter
				color: Theme.yellow
				selectionColor: Theme.orange
				selectedTextColor: Theme.bg
				font.family: Theme.fontFamily
				font.pixelSize: 16
				clip: true
				focus: win.shown
				onTextChanged: win.query = text
				Keys.onUpPressed: event => {
					win.move(-1)
					event.accepted = true
				}
				Keys.onDownPressed: event => {
					win.move(1)
					event.accepted = true
				}
				Keys.onEscapePressed: event => {
					ShellState.closeTransient()
					event.accepted = true
				}
				Keys.onReturnPressed: win.activate(win.selected)
				Keys.onEnterPressed: win.activate(win.selected)
				Keys.onTabPressed: event => {
					win.moveCategory(1)
					event.accepted = true
				}
				Keys.onBacktabPressed: event => {
					win.moveCategory(-1)
					event.accepted = true
				}
				Keys.onLeftPressed: event => {
					if (cursorPosition === 0) {
						win.moveCategory(-1)
						event.accepted = true
					}
				}
				Keys.onRightPressed: event => {
					if (cursorPosition === text.length) {
						win.moveCategory(1)
						event.accepted = true
					}
				}
			}
		}

		Rectangle {
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: searchBox.bottom
			height: 2
			color: Theme.red
		}

		ListView {
			id: catList
			anchors.left: parent.left
			anchors.top: searchBox.bottom
			anchors.topMargin: 2
			anchors.bottom: parent.bottom
			width: win.catWidth
			clip: true
			spacing: 0
			model: win.categories

			delegate: Rectangle {
				required property int index
				required property var modelData
				width: catList.width
				height: 40
				radius: 0
				color: modelData.id === win.shownCategory ? Theme.orange : (catMouse.containsMouse ? Theme.bgHover : "transparent")

				Rectangle {
					visible: modelData.id === "all"
					anchors.left: parent.left
					anchors.right: parent.right
					anchors.bottom: parent.bottom
					height: 2
					color: Theme.red
				}

				Row {
					anchors.fill: parent
					anchors.leftMargin: 12
					anchors.rightMargin: 10
					spacing: 8

					Text {
						anchors.verticalCenter: parent.verticalCenter
						width: 22
						horizontalAlignment: Text.AlignHCenter
						text: modelData.icon
						color: modelData.id === win.shownCategory ? Theme.bg : Theme.yellow
						font.family: Theme.fontFamily
						font.pixelSize: 16
					}

					Text {
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width - 64
						text: modelData.name
						color: modelData.id === win.shownCategory ? Theme.bg : Theme.fg
						font.family: Theme.fontFamily
						font.pixelSize: 14
						elide: Text.ElideRight
					}

					Text {
						anchors.verticalCenter: parent.verticalCenter
						width: 26
						horizontalAlignment: Text.AlignRight
						text: "" + modelData.count
						color: modelData.id === win.shownCategory ? Theme.bg : Theme.muted
						font.family: Theme.fontFamily
						font.pixelSize: 12
					}
				}

				MouseArea {
					id: catMouse
					anchors.fill: parent
					hoverEnabled: true
					onEntered: {
						if (win.query.trim())
							return
						if (win.category !== modelData.id) {
							win.category = modelData.id
							win.selected = 0
						}
					}
					onClicked: {
						win.query = ""
						input.text = ""
						win.category = modelData.id
						win.selected = 0
					}
				}
			}
		}

		Rectangle {
			anchors.left: parent.left
			anchors.leftMargin: win.catWidth
			anchors.top: searchBox.bottom
			anchors.bottom: parent.bottom
			width: 2
			color: Theme.red
		}

		Text {
			anchors.left: parent.left
			anchors.leftMargin: win.catWidth + 16
			anchors.right: parent.right
			anchors.rightMargin: 12
			anchors.top: searchBox.bottom
			anchors.topMargin: 10
			height: 22
			text: win.categoryName()
			color: Theme.yellow
			font.family: Theme.fontFamily
			font.pixelSize: 13
			elide: Text.ElideRight
		}

		ListView {
			id: appList
			anchors.left: parent.left
			anchors.leftMargin: win.catWidth + 2
			anchors.right: parent.right
			anchors.top: searchBox.bottom
			anchors.topMargin: 36
			anchors.bottom: parent.bottom
			clip: true
			spacing: 2
			topMargin: 4
			bottomMargin: 8
			leftMargin: 8
			rightMargin: 8
			model: win.entries

			delegate: Rectangle {
				required property int index
				required property var modelData
				width: appList.width - 16
				height: 46
				radius: 0
				color: index === win.selected ? Theme.orange : "transparent"

				Row {
					anchors.fill: parent
					anchors.leftMargin: 8
					anchors.rightMargin: 8
					spacing: 10

					Image {
						id: entryIcon
						anchors.verticalCenter: parent.verticalCenter
						width: 28
						height: 28
						source: Theme.iconSource(modelData.icon)
						fillMode: Image.PreserveAspectFit
						sourceSize.width: 56
						sourceSize.height: 56
						visible: status === Image.Ready
					}

					Text {
						anchors.verticalCenter: parent.verticalCenter
						visible: !entryIcon.visible
						width: 28
						horizontalAlignment: Text.AlignHCenter
						text: (modelData.title || "?").charAt(0).toUpperCase()
						color: index === win.selected ? Theme.bg : Theme.orange
						font.family: Theme.fontFamily
						font.pixelSize: 16
					}

					Column {
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width - 46
						spacing: 1

						Text {
							width: parent.width
							text: modelData.title
							color: index === win.selected ? Theme.bg : Theme.fg
							font.family: Theme.fontFamily
							font.pixelSize: 15
							elide: Text.ElideRight
						}

						Text {
							width: parent.width
							visible: text !== ""
							text: win.entrySubtitle(modelData)
							color: index === win.selected ? Theme.bg : Theme.gray
							font.family: Theme.fontFamily
							font.pixelSize: 12
							elide: Text.ElideRight
						}
					}
				}

				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					onEntered: win.selected = index
					onClicked: win.activate(index)
				}
			}
		}

		Text {
			anchors.left: parent.left
			anchors.leftMargin: win.catWidth
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			visible: win.entries.length === 0
			horizontalAlignment: Text.AlignHCenter
			text: win.query.trim() ? "No matches" : "No applications"
			color: Theme.gray
			font.family: Theme.fontFamily
			font.pixelSize: 14
		}
	}
}

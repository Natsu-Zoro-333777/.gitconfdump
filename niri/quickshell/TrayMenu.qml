import QtQuick
import Quickshell
import Quickshell.Widgets

// StatusNotifier menus are DBus menus. Quickshell's platform menu
// (SystemTrayItem.display) refuses to open unless the shell root sets
// UseQApplication, so the bar draws the menu itself.
PopupWindow {
	id: menuWin

	property var anchorWindow: null
	property var trayItem: null
	property var anchorItem: null
	property bool wantOpen: false
	property bool pointerInside: false
	property int depth: 0
	property var subEntry: null
	property var subEntry2: null
	property string subTitle: ""
	property string subTitle2: ""
	property int shownW: 0
	property int shownH: 0
	property int hoverIndex: -1
	property bool hoverBack: false
	property real lastY: 0

	readonly property int rowH: 30
	readonly property int sepH: 9
	readonly property int capW: 480
	readonly property int maxH: {
		const screenH = anchorWindow && anchorWindow.screen ? anchorWindow.screen.height : 900
		const barH = anchorWindow ? anchorWindow.height : 72
		return Math.max(rowH * 4, screenH - barH - 12)
	}
	readonly property var activeModel: {
		if (depth >= 2)
			return subOpener2.children
		if (depth === 1)
			return subOpener.children
		return rootOpener.children
	}
	readonly property string backLabel: depth >= 2 ? subTitle2 : subTitle

	function show(item, icon) {
		if (!item || !item.hasMenu || !icon)
			return
		cancelClose()
		cancelOpen()
		if (trayItem !== item) {
			wantOpen = false
			shownW = 0
			shownH = 0
			depth = 0
			subEntry = null
			subEntry2 = null
			subTitle = ""
			subTitle2 = ""
			hoverIndex = -1
			hoverBack = false
			trayItem = item
		}
		anchorItem = icon
		wantOpen = true
		ShellState.closeTransient()
		TipState.hide(icon)
		syncTimer.tries = 0
		syncTimer.restart()
	}

	function scheduleShow(item, icon) {
		openTimer.item = item
		openTimer.icon = icon
		openTimer.restart()
	}

	function cancelOpen() {
		openTimer.stop()
	}

	function hideSoon() {
		closeTimer.restart()
	}

	function cancelClose() {
		closeTimer.stop()
	}

	function dismiss() {
		wantOpen = false
		cancelOpen()
		cancelClose()
	}

	function contentSize() {
		const values = activeModel && activeModel.values ? activeModel.values : []
		let h = depth > 0 ? rowH : 0
		let w = 180
		for (let i = 0; i < values.length; i++) {
			const entry = values[i]
			if (!entry)
				continue
			if (entry.isSeparator) {
				h += sepH
				continue
			}
			const text = Theme.plain(entry.text || "")
			w = Math.max(w, Math.ceil(text.length * 8.4) + (entry.hasChildren ? 48 : 28))
			h += rowH
		}
		return {
			w: Math.min(capW, w),
			h: h
		}
	}

	function syncSize() {
		const size = contentSize()
		const w = size.w + 4
		const h = Math.min(maxH, Math.max(0, size.h + 4))
		if (!wantOpen) {
			shownW = w
			shownH = h
			return
		}
		// Shrinking an open xdg popup makes it stop taking clicks.
		if (w > shownW)
			shownW = w
		if (h > shownH)
			shownH = h
	}

	function hitAt(viewY) {
		const local = viewY - 2 + flick.contentY
		if (local < 0)
			return null
		let cursor = 0
		if (depth > 0) {
			if (local < rowH)
				return { kind: "back" }
			cursor = rowH
		}
		const values = activeModel && activeModel.values ? activeModel.values : []
		for (let i = 0; i < values.length; i++) {
			const entry = values[i]
			const h = entry && entry.isSeparator ? sepH : rowH
			if (local >= cursor && local < cursor + h)
				return { kind: "entry", entry: entry, index: i }
			cursor += h
		}
		return null
	}

	function hoverAt(viewY) {
		lastY = viewY
		const hit = hitAt(viewY)
		hoverBack = !!(hit && hit.kind === "back")
		hoverIndex = hit && hit.kind === "entry" ? hit.index : -1
	}

	function openChild(entry) {
		if (!entry || depth >= 2)
			return
		const title = Theme.plain(entry.text || "Menu")
		if (depth === 0) {
			subTitle = title
			subEntry = entry
			depth = 1
		} else {
			subTitle2 = title
			subEntry2 = entry
			depth = 2
		}
		hoverIndex = -1
		hoverBack = false
		Qt.callLater(() => hoverAt(lastY))
	}

	function back() {
		if (depth >= 2) {
			subEntry2 = null
			subTitle2 = ""
			depth = 1
		} else if (depth === 1) {
			subEntry = null
			subTitle = ""
			depth = 0
		}
		hoverIndex = -1
		hoverBack = false
		Qt.callLater(() => hoverAt(lastY))
	}

	function activateHit(hit) {
		if (!hit)
			return
		if (hit.kind === "back") {
			back()
			return
		}
		const row = menuRepeater.itemAt(hit.index)
		if (row)
			row.fire()
	}

	color: "transparent"
	implicitWidth: Math.max(shownW, 8)
	implicitHeight: Math.max(shownH, 8)
	visible: wantOpen && shownH > rowH && trayItem !== null && anchorItem !== null
	anchor.window: anchorWindow
	anchor.item: anchorItem
	anchor.edges: Edges.Bottom
	anchor.gravity: Edges.Bottom
	anchor.adjustment: PopupAdjustment.Slide

	QsMenuOpener {
		id: rootOpener
		menu: menuWin.trayItem && menuWin.trayItem.menu ? menuWin.trayItem.menu : null
	}

	QsMenuOpener {
		id: subOpener
		menu: menuWin.subEntry
	}

	QsMenuOpener {
		id: subOpener2
		menu: menuWin.subEntry2
	}

	Timer {
		id: openTimer
		interval: 120
		property var item: null
		property var icon: null
		onTriggered: menuWin.show(item, icon)
	}

	Timer {
		id: closeTimer
		interval: 280
		onTriggered: {
			const iconHeld = menuWin.anchorWindow && menuWin.anchorWindow.trayHoverItem === menuWin.anchorItem
			if (!menuWin.pointerInside && !iconHeld)
				menuWin.wantOpen = false
		}
	}

	Timer {
		id: syncTimer
		interval: 16
		repeat: true
		property int tries: 0
		onTriggered: {
			tries++
			menuWin.syncSize()
			if (menuWin.shownH > menuWin.rowH || tries > 50)
				stop()
		}
	}

	Connections {
		target: col
		function onImplicitWidthChanged() { menuWin.syncSize() }
		function onImplicitHeightChanged() { menuWin.syncSize() }
	}

	onWantOpenChanged: {
		if (wantOpen)
			return
		shownW = 0
		shownH = 0
		depth = 0
		subEntry = null
		subEntry2 = null
		subTitle = ""
		subTitle2 = ""
		hoverIndex = -1
		hoverBack = false
		pointerInside = false
	}

	onDepthChanged: {
		syncTimer.tries = 0
		syncTimer.restart()
	}

	Rectangle {
		anchors.fill: parent
		radius: 0
		color: Theme.bg
		border.width: 2
		border.color: Theme.red

		Flickable {
			id: flick
			anchors.fill: parent
			anchors.margins: 2
			contentWidth: width
			contentHeight: col.implicitHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds
			interactive: false

			Column {
				id: col
				width: flick.width

				Rectangle {
					visible: menuWin.depth > 0
					width: col.width
					implicitWidth: backText.implicitWidth + 28
					implicitHeight: menuWin.rowH
					height: visible ? menuWin.rowH : 0
					color: menuWin.hoverBack ? Theme.orange : "transparent"

					Text {
						id: backText
						anchors.verticalCenter: parent.verticalCenter
						anchors.left: parent.left
						anchors.leftMargin: 10
						text: "‹  " + (menuWin.backLabel || "Back")
						color: menuWin.hoverBack ? Theme.bg : Theme.yellow
						font.family: Theme.fontFamily
						font.pixelSize: 13
					}
				}

				Repeater {
					id: menuRepeater
					model: menuWin.activeModel

					Rectangle {
						required property var modelData
						required property int index

						function fire() {
							if (!modelData || modelData.isSeparator || modelData.enabled === false)
								return
							if (modelData.hasChildren) {
								menuWin.openChild(modelData)
								return
							}
							modelData.triggered()
							menuWin.dismiss()
						}
						readonly property bool hot: menuWin.hoverIndex === index && !modelData.isSeparator && modelData.enabled !== false
						width: col.width
						implicitWidth: modelData.isSeparator ? 160 : label.implicitWidth + (modelData.hasChildren ? 36 : 24)
						implicitHeight: modelData.isSeparator ? menuWin.sepH : menuWin.rowH
						height: implicitHeight
						color: hot ? Theme.orange : "transparent"

						Rectangle {
							visible: modelData.isSeparator
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.right: parent.right
							anchors.leftMargin: 8
							anchors.rightMargin: 8
							height: 2
							color: Theme.orange
						}

						IconImage {
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 8
							implicitSize: 16
							visible: !modelData.isSeparator && (modelData.icon || "") !== ""
							source: visible ? modelData.icon : ""
						}

						Rectangle {
							visible: !modelData.isSeparator && modelData.buttonType !== 0
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 8
							width: 12
							height: 12
							radius: 0
							color: "transparent"
							border.width: 1
							border.color: hot ? Theme.bg : Theme.yellow

							Rectangle {
								anchors.centerIn: parent
								width: 6
								height: 6
								visible: modelData.checkState !== 0
								color: parent.border.color
							}
						}

						Text {
							id: label
							visible: !modelData.isSeparator
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: modelData.buttonType !== 0 || (modelData.icon || "") !== "" ? 26 : 10
							anchors.right: caret.left
							anchors.rightMargin: 6
							text: Theme.plain(modelData.text || "")
							color: {
								if (modelData.enabled === false)
									return Theme.muted
								return hot ? Theme.bg : Theme.fg
							}
							font.family: Theme.fontFamily
							font.pixelSize: 13
							elide: Text.ElideRight
						}

						Text {
							id: caret
							visible: !modelData.isSeparator && modelData.hasChildren
							anchors.verticalCenter: parent.verticalCenter
							anchors.right: parent.right
							anchors.rightMargin: 8
							width: visible ? implicitWidth : 0
							text: "›"
							color: hot ? Theme.bg : Theme.yellow
							font.family: Theme.fontFamily
							font.pixelSize: 16
						}
					}
				}
			}
		}
	}

	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		onPositionChanged: menuWin.hoverAt(mouseY)
		onContainsMouseChanged: {
			if (containsMouse) {
				menuWin.pointerInside = true
				menuWin.cancelClose()
				menuWin.hoverAt(mouseY)
			} else {
				menuWin.pointerInside = false
				menuWin.hoverIndex = -1
				menuWin.hoverBack = false
				menuWin.hideSoon()
			}
		}
		onClicked: menuWin.activateHit(menuWin.hitAt(mouseY))
		onWheel: event => {
			const limit = Math.max(0, flick.contentHeight - flick.height)
			const step = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
			flick.contentY = Math.max(0, Math.min(limit, flick.contentY - step))
		}
	}
}

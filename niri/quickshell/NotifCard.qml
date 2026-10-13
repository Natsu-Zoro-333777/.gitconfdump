import QtQuick
import QtQuick.Layouts

Rectangle {
	id: root

	property var notification: null
	property bool compact: false
	readonly property var actionList: noteActions()

	signal closeRequested()

	function noteActions() {
		const note = notification
		if (!note)
			return []
		if (typeof note.actionsJson === "string") {
			if (note.actionsJson === "")
				return []
			try {
				return JSON.parse(note.actionsJson)
			} catch (e) {
				return []
			}
		}
		const actions = note.actions
		return actions && actions.length ? actions : []
	}

	radius: 0
	color: openMouse.containsMouse ? Theme.bgHover : Theme.bg
	border.width: 3
	border.color: Theme.red
	implicitWidth: 420
	implicitHeight: row.implicitHeight + 16

	RowLayout {
		id: row
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.top: parent.top
		anchors.margins: 8
		spacing: 8

		Item {
			id: textSide
			Layout.fillWidth: true
			implicitHeight: textCol.implicitHeight

			MouseArea {
				id: openMouse
				z: -1
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				preventStealing: true
				onClicked: {
					if (root.notification)
						Notifs.openId(root.notification.id)
				}
			}

			ColumnLayout {
			id: textCol
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: parent.top
			spacing: 6

			RowLayout {
				Layout.fillWidth: true
				spacing: 8

				Image {
					visible: source.toString() !== ""
					source: root.notification ? Theme.iconSource(root.notification.appIcon) : ""
					Layout.preferredWidth: 28
					Layout.preferredHeight: 28
					fillMode: Image.PreserveAspectFit
					sourceSize.width: 56
					sourceSize.height: 56
				}

				ColumnLayout {
					Layout.fillWidth: true
					spacing: 0

					Text {
						Layout.fillWidth: true
						text: root.notification ? (root.notification.appName || "Notification") : ""
						color: Theme.gray
						font.family: Theme.fontFamily
						font.pixelSize: 12
						elide: Text.ElideRight
					}

					Text {
						Layout.fillWidth: true
						text: root.notification ? Theme.plain(root.notification.summary) : ""
						color: Theme.yellow
						font.family: Theme.fontFamily
						font.pixelSize: 15
						font.bold: true
						wrapMode: Text.WordWrap
						maximumLineCount: root.compact ? 2 : 4
						elide: Text.ElideRight
					}
				}

				Text {
					text: root.notification ? Notifs.age(root.notification.id) : ""
					color: Theme.gray
					font.family: Theme.fontFamily
					font.pixelSize: 12
				}
			}

			Text {
				visible: text !== ""
				Layout.fillWidth: true
				text: root.notification ? Theme.plain(root.notification.body) : ""
				color: Theme.fg
				font.family: Theme.fontFamily
				font.pixelSize: 14
				wrapMode: Text.WordWrap
				maximumLineCount: root.compact ? 4 : 8
				elide: Text.ElideRight
			}

			Image {
				visible: source.toString() !== "" && status === Image.Ready
				Layout.preferredHeight: 72
				Layout.preferredWidth: 160
				fillMode: Image.PreserveAspectFit
				source: root.notification && root.notification.image ? Theme.iconSource(root.notification.image) : ""
			}

			Flow {
				Layout.fillWidth: true
				spacing: 6
				visible: actionList.length > 0

				Repeater {
					model: root.actionList

					Rectangle {
						required property var modelData
						width: actionLabel.implicitWidth + 16
						height: 28
						radius: 0
						color: actionMouse.containsMouse ? Theme.orange : Theme.bgAlt
						border.width: 2
						border.color: Theme.red

						Text {
							id: actionLabel
							anchors.centerIn: parent
							text: Theme.plain(modelData.text)
							color: actionMouse.containsMouse ? Theme.bg : Theme.yellow
							font.family: Theme.fontFamily
							font.pixelSize: 13
						}

						MouseArea {
							id: actionMouse
							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							preventStealing: true
							onClicked: {
								if (root.notification)
									Notifs.activateId(root.notification.id, modelData.identifier)
							}
						}
					}
				}
			}
		}
		}

		Rectangle {
			id: closeBox
			Layout.preferredWidth: 36
			Layout.preferredHeight: 36
			Layout.alignment: Qt.AlignTop
			color: closeMouse.containsMouse ? Theme.red : Theme.bgHover

			Text {
				anchors.centerIn: parent
				text: ""
				color: closeMouse.containsMouse ? Theme.bg : Theme.fg
				font.family: Theme.fontFamily
				font.pixelSize: 16
			}

			MouseArea {
				id: closeMouse
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				preventStealing: true
				onClicked: root.closeRequested()
			}
		}
	}
}

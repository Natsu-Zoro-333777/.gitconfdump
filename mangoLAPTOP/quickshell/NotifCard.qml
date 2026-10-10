import QtQuick
import QtQuick.Layouts

Rectangle {
	id: root

	property var notification: null
	property bool compact: false

	signal closeRequested()

	radius: 0
	color: openMouse.containsMouse ? Theme.bgHover : Theme.bg
	border.width: 3
	border.color: Theme.red
	implicitWidth: 420
	implicitHeight: bodyCol.implicitHeight + 16

	MouseArea {
		id: openMouse
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: {
			if (root.notification)
				Notifs.open(root.notification)
		}

	ColumnLayout {
		id: bodyCol
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.top: parent.top
		anchors.margins: 8
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

			Rectangle {
				Layout.preferredWidth: 22
				Layout.preferredHeight: 22
				radius: 0
				color: closeMouse.containsMouse ? Theme.red : Theme.bgHover

				Text {
					anchors.centerIn: parent
					text: ""
					color: closeMouse.containsMouse ? Theme.bg : Theme.fg
					font.family: Theme.fontFamily
					font.pixelSize: 12
				}

				MouseArea {
					id: closeMouse
					anchors.fill: parent
					hoverEnabled: true
					preventStealing: true
					cursorShape: Qt.PointingHandCursor
					onPressed: mouse => mouse.accepted = true
					onClicked: root.closeRequested()
				}
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
			visible: root.notification && root.notification.actions && root.notification.actions.length > 0

			Repeater {
				model: root.notification ? root.notification.actions : []

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
						onClicked: {
							if (root.notification)
								Notifs.activate(root.notification, modelData)
						}
					}
				}
			}
		}
	}
	}
}

import QtQuick
import QtQuick.Layouts

// One source. A single notification is a normal card. Two or more draw a
// collapsed deck; the click focuses that source and the center expands it.
Item {
	id: root

	property string sourceKey: ""
	property string appName: ""
	property string appIcon: ""
	property int count: 0
	property string itemsJson: "[]"

	signal focusRequested()
	signal closeRequested(int nid)

	readonly property var notes: {
		try {
			const parsed = JSON.parse(itemsJson || "[]")
			return parsed && parsed.length ? parsed : []
		} catch (e) {
			return []
		}
	}
	readonly property var newest: notes.length ? notes[0] : null

	implicitWidth: 360
	implicitHeight: count > 1 ? pile.implicitHeight : singleCard.implicitHeight

	NotifCard {
		id: singleCard
		visible: root.count < 2
		width: parent.width
		height: implicitHeight
		notification: root.newest
		onCloseRequested: {
			if (root.newest)
				root.closeRequested(Number(root.newest.id))
		}
	}

	Column {
		id: pile
		visible: root.count > 1
		width: parent.width
		height: implicitHeight
		spacing: 0

		Rectangle {
			id: face
			width: parent.width
			height: faceRow.implicitHeight + 16
			radius: 0
			color: faceMouse.containsMouse ? Theme.bgHover : Theme.bg
			border.width: 3
			border.color: Theme.red

			RowLayout {
				id: faceRow
				anchors.left: parent.left
				anchors.right: parent.right
				anchors.top: parent.top
				anchors.margins: 8
				spacing: 8

				Image {
					visible: source.toString() !== ""
					source: Theme.iconSource(root.appIcon)
					Layout.preferredWidth: 28
					Layout.preferredHeight: 28
					Layout.alignment: Qt.AlignTop
					fillMode: Image.PreserveAspectFit
					sourceSize.width: 56
					sourceSize.height: 56
				}

				ColumnLayout {
					Layout.fillWidth: true
					spacing: 2

					Text {
						Layout.fillWidth: true
						text: root.appName || "Notification"
						color: Theme.gray
						font.family: Theme.fontFamily
						font.pixelSize: 12
						elide: Text.ElideRight
					}

					Text {
						Layout.fillWidth: true
						text: root.newest ? Theme.plain(root.newest.summary) : ""
						color: Theme.yellow
						font.family: Theme.fontFamily
						font.pixelSize: 15
						font.bold: true
						wrapMode: Text.WordWrap
						maximumLineCount: 2
						elide: Text.ElideRight
					}

					Text {
						visible: text !== ""
						Layout.fillWidth: true
						text: root.newest ? Theme.plain(root.newest.body) : ""
						color: Theme.fg
						font.family: Theme.fontFamily
						font.pixelSize: 13
						wrapMode: Text.WordWrap
						maximumLineCount: 2
						elide: Text.ElideRight
					}
				}

				Rectangle {
					Layout.preferredWidth: Math.max(28, countText.implicitWidth + 12)
					Layout.preferredHeight: 28
					Layout.alignment: Qt.AlignTop
					radius: 0
					color: Theme.orange

					Text {
						id: countText
						anchors.centerIn: parent
						text: "" + root.count
						color: Theme.bg
						font.family: Theme.fontFamily
						font.pixelSize: 14
						font.bold: true
					}
				}
			}

			MouseArea {
				id: faceMouse
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				preventStealing: true
				onClicked: root.focusRequested()
			}
		}

		Item {
			width: parent.width
			height: 7

			Rectangle {
				x: 6
				width: parent.width - 12
				height: 7
				color: Theme.bgAlt
				border.width: 2
				border.color: Theme.red
			}
		}

		Item {
			visible: root.count > 2
			width: parent.width
			height: root.count > 2 ? 7 : 0

			Rectangle {
				x: 12
				width: parent.width - 24
				height: 7
				color: Theme.bgHover
				border.width: 2
				border.color: Theme.red
			}
		}
	}
}

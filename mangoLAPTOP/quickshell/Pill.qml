import QtQuick

Rectangle {
	id: root

	property color borderColor: Theme.orange
	property string tip: ""
	property bool monoTip: false
	default property alias content: row.data

	signal clicked(var mouse)
	signal wheel(var angle)

	implicitWidth: Math.max(40, row.implicitWidth + 16)
	implicitHeight: 40
	radius: 0
	color: Theme.bg
	border.width: 3
	border.color: borderColor

	Row {
		id: row
		anchors.centerIn: parent
		spacing: 2
	}

	MouseArea {
		id: mouse
		z: -1
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		onClicked: event => root.clicked(event)
		onWheel: event => root.wheel(event.angleDelta.y)
		onContainsMouseChanged: {
			if (containsMouse)
				TipState.show(root, root.tip, root.monoTip)
			else
				TipState.hide(root)
		}
	}

	onTipChanged: {
		if (mouse.containsMouse)
			TipState.show(root, root.tip, root.monoTip)
	}
}

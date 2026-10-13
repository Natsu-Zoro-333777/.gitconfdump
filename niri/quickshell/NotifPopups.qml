import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
	id: win

	anchors.top: true
	anchors.right: true
	margins.top: 64
	margins.right: 8
	implicitWidth: 440
	implicitHeight: Math.max(1, column.implicitHeight)
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	visible: Notifs.popups.length > 0 && !ShellState.centerOpen && !ShellState.launcherOpen && !ShellState.clipboardOpen
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "quickshell-notifications"

	Column {
		id: column
		width: parent.width
		spacing: 8

		Repeater {
			model: Notifs.popups

			NotifCard {
				required property var modelData
				width: column.width
				compact: true
				notification: modelData
				onCloseRequested: Notifs.dismissPopup(modelData.id, true)
			}
		}
	}
}

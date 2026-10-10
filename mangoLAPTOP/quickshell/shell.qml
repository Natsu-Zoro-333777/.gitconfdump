//@ pragma Env QT_QPA_PLATFORMTHEME=qt6ct
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

ShellRoot {
	IpcHandler {
		target: "launcher"
		function toggle() {
			ShellState.toggleLauncher()
			return ShellState.launcherOpen ? "open" : "closed"
		}
		function open() {
			ShellState.closeTransient()
			ShellState.launcherOpen = true
			return "open"
		}
		function close() {
			ShellState.launcherOpen = false
			return "closed"
		}
	}

	IpcHandler {
		target: "clipboard"
		function toggle() {
			ShellState.toggleClipboard()
			return ShellState.clipboardOpen ? "open" : "closed"
		}
	}

	IpcHandler {
		target: "center"
		function toggle() {
			ShellState.toggleCenter()
			return ShellState.centerOpen ? "open" : "closed"
		}
		function open() {
			ShellState.openCenter("main")
			return "open"
		}
		function close() {
			ShellState.centerOpen = false
			return "closed"
		}
	}

	IpcHandler {
		target: "dnd"
		function toggle() {
			Notifs.dnd = !Notifs.dnd
			return Notifs.dnd ? "on" : "off"
		}
	}

	IpcHandler {
		target: "lock"
		function lock() {
			ShellState.requestLock()
			return "locking"
		}
	}

	PwObjectTracker {
		objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
	}

	readonly property bool usbWatch: Usb.open

	Bar {}
	Clipboard {}
	NotifPopups {}
	Lock {}
}

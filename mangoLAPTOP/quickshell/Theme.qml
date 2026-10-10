pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.Pipewire

Singleton {
	id: root

	readonly property color bg: "#282828"
	readonly property color bgAlt: "#1d2021"
	readonly property color bgHover: "#504945"
	readonly property color fg: "#ebdbb2"
	readonly property color yellow: "#fabd2f"
	readonly property color orange: "#fe8019"
	readonly property color red: "#fb4934"
	readonly property color gray: "#a89984"
	readonly property color muted: "#928374"
	readonly property color black: "#282828"

	readonly property string fontFamily: "JetBrainsMono Nerd Font"
	readonly property string monoFamily: "JetBrainsMono Nerd Font Mono"
	readonly property int fontPx: 14

	readonly property var tagIcons: [
		"",
		"󱇐",
		"󰞇",
		"󰣉",
		"󰺾",
		"󰩰",
		"󰐂",
		"",
		"󱌣",
		"",
		"󱙴"
	]

	function iconSource(icon) {
		if (!icon)
			return ""
		const value = "" + icon
		if (value.indexOf("://") !== -1 || value.startsWith("image:"))
			return value
		if (value.startsWith("/"))
			return "file://" + value
		const path = Quickshell.iconPath(value)
		if (!path)
			return ""
		if (("" + path).indexOf("://") !== -1)
			return path
		if (("" + path).startsWith("/"))
			return "file://" + path
		return path
	}

	function plain(text) {
		return (text || "")
			.replace(/<br\s*\/?>/gi, "\n")
			.replace(/<[^>]+>/g, "")
			.replace(/&nbsp;/g, " ")
			.replace(/&amp;/g, "&")
			.replace(/&lt;/g, "<")
			.replace(/&gt;/g, ">")
			.replace(/&quot;/g, "\"")
			.replace(/&#39;/g, "'")
	}

	function audioSink() {
		return Pipewire.defaultAudioSink
	}

	function audioIcon(sink) {
		sink = sink || root.audioSink()
		if (!sink || !sink.ready || !sink.audio)
			return "󰖁"
		const props = sink.properties || {}
		const blob = ((props["device.form-factor"] || "") + " " + (sink.description || "") + " " + (sink.name || "")).toLowerCase()
		const headphones = blob.indexOf("headphone") !== -1 || blob.indexOf("headset") !== -1
		if (sink.audio.muted || sink.audio.volume <= 0.001)
			return headphones ? "󰟎" : "󰝟"
		if (headphones)
			return ""
		const volume = sink.audio.volume
		if (volume < 0.15)
			return "󰖁"
		if (volume < 0.45)
			return ""
		if (volume < 0.8)
			return "󰕾"
		return ""
	}

	function audioPercent(sink) {
		sink = sink || root.audioSink()
		if (!sink || !sink.ready || !sink.audio)
			return 0
		return Math.round(sink.audio.volume * 100)
	}

	function wifiDevice() {
		const devices = Networking.devices.values
		for (let i = 0; i < devices.length; i++) {
			if (DeviceType.toString(devices[i].type) === "Wifi")
				return devices[i]
		}
		return null
	}

	function wiredDevice() {
		const devices = Networking.devices.values
		for (let i = 0; i < devices.length; i++) {
			if (DeviceType.toString(devices[i].type) === "Wired" && devices[i].connected)
				return devices[i]
		}
		return null
	}

	function connectedWifi() {
		const device = root.wifiDevice()
		if (!device || !device.networks)
			return null
		const nets = device.networks.values
		for (let i = 0; i < nets.length; i++) {
			if (nets[i].connected)
				return nets[i]
		}
		return null
	}

	function networkIcon() {
		if (root.connectedWifi() || (root.wifiDevice() && root.wifiDevice().connected))
			return "󰖩"
		if (root.wiredDevice())
			return "󰈀"
		return "󰖪"
	}

	function networkTip() {
		const wifi = root.connectedWifi()
		const device = root.wifiDevice()
		let head = "Disconnected"
		let iface = ""
		if (wifi) {
			head = wifi.name + (device ? "\n" + device.name : "")
			iface = device ? device.name : ""
		} else if (device && device.connected) {
			head = device.name
			iface = device.name
		} else {
			const wired = root.wiredDevice()
			if (wired) {
				head = wired.name + (wired.address ? "\n" + wired.address : "")
				iface = wired.name
			}
		}
		return head + "\n" + Sysmon.netSpeedLines(iface)
	}

	function signalText(net) {
		let strength = net ? net.signalStrength : 0
		if (strength > 0 && strength <= 1)
			strength *= 100
		return Math.round(strength) + "%"
	}

	function securityText(net) {
		if (!net)
			return ""
		const label = WifiSecurityType.toString(net.security)
		if (label === "Open" || label === "Owe" || label === "Unknown")
			return label === "Unknown" ? "" : "open"
		return label
	}

	function needsPassword(net) {
		if (!net || net.known || net.connected)
			return false
		const label = WifiSecurityType.toString(net.security)
		return label !== "Open" && label !== "Owe"
	}

	function calendar(date) {
		const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
		const year = date.getFullYear()
		const month = date.getMonth()
		const today = date.getDate()
		const first = new Date(year, month, 1).getDay()
		const count = new Date(year, month + 1, 0).getDate()
		const lines = [months[month] + " " + year, "Su Mo Tu We Th Fr Sa"]
		let line = "   ".repeat(first)
		for (let day = 1; day <= count; day++) {
			const cell = (day < 10 ? " " : "") + day
			line += day === today ? cell.replace(/^./, ">") : cell
			if ((first + day) % 7 === 0 || day === count) {
				lines.push(line)
				line = ""
			} else {
				line += " "
			}
		}
		return lines.join("\n")
	}
}

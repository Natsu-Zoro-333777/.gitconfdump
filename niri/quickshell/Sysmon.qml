pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "procparse.js" as ProcParse
// Laptop battery service. Inactive on this desktop, which has no battery.
// import Quickshell.Services.UPower

Singleton {
	id: root

	property real cpuUsage: 0
	property real cpuFreqMhz: 0
	property var coreUsage: []
	property real memUsed: 0
	property real memAvail: 0
	property real memTotal: 0
	property real swapUsed: 0
	property real swapTotal: 0
	property string weather: "…"
	property string weatherIcon: "…"
	property string weatherLocation: "Tucson"
	readonly property int weatherInterval: 6 * 60 * 60 * 1000
	property bool weatherFileReady: false
	property bool weatherStampReady: false
	property string weatherPendingReport: ""
	property var netRates: ({})
	property string netIface: ""
	property var _netRx: ({})
	property var _netTx: ({})
	property real _netStamp: 0

	// Bar icons, in the order sun, lightning, rain, snow.
	readonly property var weatherIcons: ["☀️", "⚡", "🌧️", "❄️"]
	// Laptop battery state. Inactive on this desktop, which has no battery.
	// property string batteryBucket: ""
	// property int chargeFrame: 0
	// property bool charging: false

	property real _idle: 0
	property real _total: 0
	property var _coreIdle: []
	property var _coreTotal: []

	function gib(kb) {
		return (kb / 1024 / 1024).toFixed(1)
	}

	function memLabel() {
		return root.gib(root.memUsed) + " gb / " + root.gib(root.memTotal) + " gb"
	}

	function memTip() {
		const free = Math.max(0, root.swapTotal - root.swapUsed)
		return "SWAP used  " + root.gib(root.swapUsed) + " gb\n"
			+ "SWAP free  " + root.gib(free) + " gb"
	}

	function cpuLabel() {
		let text = Math.round(root.cpuUsage) + "%"
		if (root.cpuFreqMhz > 0)
			text += "  " + (root.cpuFreqMhz / 1000).toFixed(2) + " GHz"
		return text
	}

	function cpuTip() {
		const lines = []
		for (let i = 0; i < root.coreUsage.length; i++) {
			const pct = Math.round(root.coreUsage[i])
			lines.push("core " + i + "  " + (pct < 10 ? " " : "") + pct + "%")
		}
		return lines.join("\n")
	}

	// Laptop battery time-remaining text. Inactive on this desktop (no battery).
	/*
	function formatDuration(seconds) {
		const total = Math.round(seconds || 0)
		if (total <= 0)
			return ""
		const hours = Math.floor(total / 3600)
		const minutes = Math.floor((total % 3600) / 60)
		if (hours > 0)
			return hours + "h " + minutes + "m"
		return minutes + "m"
	}

	function batteryLife(device) {
		device = device || UPower.displayDevice
		if (!device || !device.ready)
			return ""
		const state = UPowerDeviceState.toString(device.state)
		if (state === "FullyCharged")
			return "Full"
		if (state === "Charging" || state === "PendingCharge") {
			const untilFull = root.formatDuration(device.timeToFull)
			return untilFull ? untilFull + " until full" : "Charging"
		}
		const left = root.formatDuration(device.timeToEmpty)
		return left ? left + " left" : "Discharging"
	}
	*/

	function plainForecast(raw) {
		return String(raw || "")
			.replace(/\r/g, "")
			.replace(/\u001b\[[0-9;]*[A-Za-z]/g, "")
			.replace(/\n+$/, "")
	}

	function weatherStampMs() {
		const stamp = Number(String(weatherStamp.text() || "").trim())
		return stamp > 0 ? stamp : 0
	}

	function weatherStale() {
		const report = root.plainForecast(weatherFile.text())
		if (!report || report === "No Connection")
			return true
		const stamp = root.weatherStampMs()
		if (!stamp)
			return true
		return Date.now() - stamp >= root.weatherInterval
	}

	function armWeatherTimer(wait) {
		weatherTimer.interval = Math.max(1000, wait || root.weatherInterval)
		weatherTimer.restart()
	}

	function considerWeatherFetch() {
		if (!root.weatherFileReady || !root.weatherStampReady)
			return
		if (root.weatherStale()) {
			root.refreshWeather(false)
			return
		}
		const remain = root.weatherInterval - (Date.now() - root.weatherStampMs())
		root.armWeatherTimer(remain)
	}

	function applyWeather(report) {
		const text = root.plainForecast(report)
		root.weather = text || "No Connection"
		root.weatherIcon = root.weatherIconFor(root.weatherSky(root.weather))
	}

	function finishWeatherFailure() {
		const cached = root.plainForecast(weatherFile.text())
		if (cached && cached !== "No Connection") {
			root.applyWeather(cached)
			const remain = root.weatherInterval - (Date.now() - root.weatherStampMs())
			root.armWeatherTimer(remain > 0 ? remain : root.weatherInterval)
			return
		}
		root.weather = "No Connection"
		root.weatherIcon = root.weatherIconFor(root.weather)
		root.armWeatherTimer(15 * 60 * 1000)
	}

	function refreshWeather(force) {
		if (weatherProc.running)
			return
		if (!force && root.weatherFileReady && root.weatherStampReady && !root.weatherStale()) {
			const remain = root.weatherInterval - (Date.now() - root.weatherStampMs())
			root.armWeatherTimer(remain)
			return
		}
		weatherProc.running = true
	}

	// Current conditions only. Later days in the report must not pick the icon.
	function weatherSky(report) {
		const lines = (report || "").split("\n")
		const sky = []
		for (let i = 0; i < lines.length; i++) {
			if (lines[i].indexOf("┌") !== -1 || lines[i].indexOf("Morning") !== -1)
				break
			sky.push(lines[i])
		}
		return sky.join("\n")
	}

	function weatherIconFor(value) {
		const text = value || ""
		if (!text || text === "…" || /no connection/i.test(text))
			return "…"
		if (/⚡|⛈|🌩|thunder/i.test(text))
			return root.weatherIcons[1]
		if (/❄|☃|🌨|snow/i.test(text))
			return root.weatherIcons[3]
		if (/🌧|🌦|rain|drizzle/i.test(text))
			return root.weatherIcons[2]
		return root.weatherIcons[0]
	}

	function weatherTip() {
		const report = (root.weather || "").replace(/\n+$/, "")
		if (!report || report === "…")
			return "…"
		return report
	}

	function formatRate(bytesPerSec) {
		const n = Math.max(0, bytesPerSec || 0)
		if (n < 1024)
			return Math.round(n) + " b/s"
		if (n < 1024 * 1024)
			return (n / 1024).toFixed(1) + " kb/s"
		return (n / 1024 / 1024).toFixed(1) + " mb/s"
	}

	function netSpeedLines(iface) {
		const rates = root.netRates || {}
		let rate = iface && rates[iface] ? rates[iface] : null
		if (!rate && root.netIface && rates[root.netIface])
			rate = rates[root.netIface]
		if (!rate) {
			const names = Object.keys(rates)
			if (names.length === 1)
				rate = rates[names[0]]
		}
		if (!rate)
			return "down  …\nup    …"
		return "down  " + root.formatRate(rate.down) + "\nup    " + root.formatRate(rate.up)
	}

	function applyNet(counters, iface) {
		const now = Date.now()
		const dt = root._netStamp > 0 ? (now - root._netStamp) / 1000 : 0
		const nextRx = {}
		const nextTx = {}
		const rates = {}
		const names = Object.keys(counters || {})
		for (let i = 0; i < names.length; i++) {
			const name = names[i]
			const rx = Number(counters[name].rx) || 0
			const tx = Number(counters[name].tx) || 0
			nextRx[name] = rx
			nextTx[name] = tx
			const prevRx = root._netRx[name]
			const prevTx = root._netTx[name]
			if (dt > 0.2 && prevRx !== undefined && rx >= prevRx && tx >= prevTx)
				rates[name] = { down: (rx - prevRx) / dt, up: (tx - prevTx) / dt }
			else if (root.netRates[name])
				rates[name] = root.netRates[name]
			else
				rates[name] = { down: 0, up: 0 }
		}
		root._netRx = nextRx
		root._netTx = nextTx
		root._netStamp = now
		root.netIface = iface || ""
		root.netRates = rates
	}

	// Laptop battery percent, icon, and health notifications.
	// Inactive on this desktop (no battery).
	/*
	function batteryPercent(device) {
		device = device || UPower.displayDevice
		if (!device || !device.ready)
			return 0
		// UPower's Percentage is 0–100. Quickshell exposes it as a fraction of capacity.
		return device.percentage * 100
	}

	function checkBattery() {
		const device = UPower.displayDevice
		if (!device || !device.ready || !device.isPresent)
			return
		const state = UPowerDeviceState.toString(device.state)
		const pct = root.batteryPercent(device)
		root.charging = (state === "Charging" || state === "PendingCharge") && pct < 100
		let bucket = "ok"
		if (state === "Discharging" && pct <= 15)
			bucket = "critical"
		else if (state === "Discharging" && pct <= 30)
			bucket = "warning"
		else if (state === "FullyCharged" || pct >= 100)
			bucket = "full"
		if (bucket === root.batteryBucket)
			return
		const previous = root.batteryBucket
		root.batteryBucket = bucket
		if (!previous)
			return
		if (bucket === "warning")
			Quickshell.execDetached(["notify-send", "-u", "normal", "Low Battery", Math.round(pct) + "%"])
		else if (bucket === "critical")
			Quickshell.execDetached(["notify-send", "-u", "critical", "Very Low Battery", Math.round(pct) + "%"])
		else if (bucket === "full")
			Quickshell.execDetached(["notify-send", "-u", "normal", "Battery Full", Math.round(pct) + "%"])
	}

	function batteryIcon() {
		const frame = root.chargeFrame
		const icons = ["", "", "", "", ""]
		const device = UPower.displayDevice
		if (!device || !device.ready)
			return icons[4]
		const level = Math.max(0, Math.min(4, Math.floor(root.batteryPercent(device) / 20)))
		if (!root.charging)
			return icons[level]
		const span = Math.max(2, level + 1)
		return icons[frame % span]
	}
	*/

	function usageOf(parts, prevIdle, prevTotal) {
		if (!parts || parts.length <= 3)
			return { usage: -1, idle: prevIdle, total: prevTotal }
		let total = 0
		for (let i = 0; i < parts.length; i++)
			total += parts[i]
		const idle = parts[3] + (parts[4] || 0)
		let usage = -1
		if (prevTotal > 0 && total > prevTotal) {
			const totalDelta = total - prevTotal
			const idleDelta = idle - prevIdle
			usage = Math.max(0, Math.min(100, (1 - idleDelta / totalDelta) * 100))
		}
		return { usage: usage, idle: idle, total: total }
	}

	// Number of procfs reads still outstanding for the current sample.
	property int _pending: 0
	property double _sampleStarted: 0

	function sampleNow() {
		// A read normally lands in well under a second; give up on a stuck one after 10 s.
		if (root._pending > 0 && Date.now() - root._sampleStarted < 10000)
			return
		root._sampleStarted = Date.now()
		root._pending = procFiles.length
		for (let i = 0; i < procFiles.length; i++)
			procFiles[i].reload()
	}

	function fileDone() {
		// Ignore the initial preload; samples start from the timer.
		if (root._pending <= 0)
			return
		root._pending = Math.max(0, root._pending - 1)
		if (root._pending > 0)
			return
		root.applySample(ProcParse.sample(
			statFile.loaded ? statFile.text() : "",
			memFile.loaded ? memFile.text() : "",
			freqFile.loaded ? freqFile.text() : "",
			routeFile.loaded ? routeFile.text() : "",
			netFile.loaded ? netFile.text() : ""))
	}

	function applySample(data) {
		if (!data)
			return
		const parts = data.cpu || []
		const agg = root.usageOf(parts, root._idle, root._total)
		if (agg.usage >= 0)
			root.cpuUsage = agg.usage
		root._idle = agg.idle
		root._total = agg.total

		const cores = data.cores || []
		const nextUsage = []
		const nextIdle = []
		const nextTotal = []
		for (let i = 0; i < cores.length; i++) {
			const sample = root.usageOf(cores[i], root._coreIdle[i] || 0, root._coreTotal[i] || 0)
			nextIdle.push(sample.idle)
			nextTotal.push(sample.total)
			if (sample.usage >= 0)
				nextUsage.push(sample.usage)
			else
				nextUsage.push(root.coreUsage[i] || 0)
		}
		root._coreIdle = nextIdle
		root._coreTotal = nextTotal
		root.coreUsage = nextUsage

		if (data.freq)
			root.cpuFreqMhz = data.freq / 1000
		const mem = data.mem || {}
		root.memTotal = mem.MemTotal || 0
		root.memAvail = mem.MemAvailable || 0
		root.memUsed = Math.max(0, root.memTotal - root.memAvail)
		root.swapTotal = mem.SwapTotal || 0
		root.swapUsed = Math.max(0, root.swapTotal - (mem.SwapFree || 0))
		root.applyNet(data.net || {}, data.route || "")
	}

	Timer {
		interval: 3000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: root.sampleNow()
	}

	Timer {
		id: weatherTimer
		interval: root.weatherInterval
		repeat: true
		onTriggered: root.refreshWeather(false)
	}

	FileView {
		id: weatherFile
		path: Quickshell.cachePath("weather.txt")
		printErrors: false
		atomicWrites: true
		onLoaded: {
			root.weatherFileReady = true
			root.applyWeather(text())
			root.considerWeatherFetch()
		}
		onLoadFailed: function(error) {
			root.weatherFileReady = true
			if (error !== FileViewError.FileNotFound)
				console.log("weather cache load failed:", FileViewError.toString(error))
			root.considerWeatherFetch()
		}
		onSaveFailed: function(error) {
			console.log("weather cache save failed:", FileViewError.toString(error))
		}
	}

	FileView {
		id: weatherStamp
		path: Quickshell.cachePath("weather-at")
		printErrors: false
		atomicWrites: true
		onLoaded: {
			root.weatherStampReady = true
			root.considerWeatherFetch()
		}
		onLoadFailed: function(error) {
			root.weatherStampReady = true
			if (error !== FileViewError.FileNotFound)
				console.log("weather stamp load failed:", FileViewError.toString(error))
			root.considerWeatherFetch()
		}
	}

	// Laptop battery polling and charge animation. Inactive on this desktop.
	/*
	Timer {
		interval: 30000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: root.checkBattery()
	}

	Timer {
		interval: 420
		repeat: true
		running: root.charging
		onTriggered: root.chargeFrame = (root.chargeFrame + 1) % 5
	}
	*/

	// procfs sources for CPU, memory and network. FileView reads files that
	// report size 0 (like /proc) to EOF. Each sample reloads all of them and
	// parses once the last one has landed.
	readonly property list<FileView> procFiles: [statFile, memFile, freqFile, routeFile, netFile]

	FileView {
		id: statFile
		path: "/proc/stat"
		printErrors: false
		onLoaded: root.fileDone()
		onLoadFailed: root.fileDone()
	}

	FileView {
		id: memFile
		path: "/proc/meminfo"
		printErrors: false
		onLoaded: root.fileDone()
		onLoadFailed: root.fileDone()
	}

	FileView {
		id: freqFile
		path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"
		printErrors: false
		onLoaded: root.fileDone()
		onLoadFailed: root.fileDone()
	}

	FileView {
		id: routeFile
		path: "/proc/net/route"
		printErrors: false
		onLoaded: root.fileDone()
		onLoadFailed: root.fileDone()
	}

	FileView {
		id: netFile
		path: "/proc/net/dev"
		printErrors: false
		onLoaded: root.fileDone()
		onLoadFailed: root.fileDone()
	}

	Process {
		id: weatherProc
		command: ["curl", "-fsS", "--max-time", "20", "https://wttr.in/" + encodeURIComponent(root.weatherLocation)]
		stdout: StdioCollector {
			waitForEnd: true
			onStreamFinished: root.weatherPendingReport = root.plainForecast(text)
		}
		onExited: exitCode => {
			const report = root.weatherPendingReport
			root.weatherPendingReport = ""
			if (exitCode === 0 && report) {
				root.applyWeather(report)
				weatherFile.setText(report + "\n")
				weatherStamp.setText(String(Date.now()))
				root.armWeatherTimer(root.weatherInterval)
				return
			}
			root.finishWeatherFailure()
		}
	}

	// Laptop battery change watcher. Inactive on this desktop (no battery).
	/*
	Connections {
		target: UPower.displayDevice
		function onPercentageChanged() { root.checkBattery() }
		function onStateChanged() { root.checkBattery() }
	}
	*/
}

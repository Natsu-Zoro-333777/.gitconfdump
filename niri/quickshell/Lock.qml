import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

Scope {
	id: root

	property string currentText: ""
	property bool unlockInProgress: false
	property bool showFailure: false
	property bool arming: false
	property string shotStamp: ""
	property int focusTick: 0
	// quickshell 0.3.2 does not emit lockStateChanged after a successful
	// unlock, so onLockedChanged never runs on the way out.
	property bool sawLocked: false
	// Panels we turned off during this lock. Unlock and seat activity turn
	// them back on. A manual Mod+Shift+P is left alone.
	property bool panelsOff: false
	// Earliest moment this lock may blank. The seat clock can already be
	// idle when the lock engages; this keeps the wait a full period from
	// the lock, and from the last wake during the lock.
	property double blankNotBefore: 0

	function lockSleepSeconds() {
		const raw = String(Quickshell.env("NIRI_LOCK_SLEEP_SECONDS") || "")
		const n = parseInt(raw, 10)
		return n > 0 ? n : 900
	}

	function armBlankClock() {
		root.blankNotBefore = Date.now() + root.lockSleepSeconds() * 1000
	}

	function setPanels(off) {
		if (off === root.panelsOff)
			return
		root.panelsOff = off
		Quickshell.execDetached(["/usr/bin/niri", "msg", "action", off ? "power-off-monitors" : "power-on-monitors"])
		console.log("lock sleep:", off ? "panels off" : "panels on")
	}

	// Blank only while locked, after the local wait, and after niri reports
	// the seat idle. Idle inhibitors do not count. Niri 26.04 treats a lid
	// switch as seat activity while the panels are on, so that event restarts
	// the wait. It does not wake panels that are already off.
	function maybeBlank() {
		if (!sessionLock.locked || root.panelsOff || root.blankNotBefore <= 0)
			return
		if (!lockIdle.isIdle || Date.now() < root.blankNotBefore)
			return
		root.setPanels(true)
	}

	function noteActivity() {
		root.armBlankClock()
		if (root.panelsOff)
			root.setPanels(false)
	}

	onCurrentTextChanged: {
		if (currentText !== "")
			showFailure = false
	}

	function quote(value) {
		return "'" + String(value).replace(/'/g, "'\\''") + "'"
	}

	function shotPath(name) {
		const safe = String(name || "screen").replace(/[^A-Za-z0-9._-]/g, "_")
		return Quickshell.cachePath("lock/" + safe + ".png")
	}

	function fileUrl(path) {
		return "file://" + path
	}

	function noteLockState() {
		const active = sessionLock.locked
		if (active === root.sawLocked)
			return
		const was = root.sawLocked
		root.sawLocked = active
		if (!was && active && root.blankNotBefore <= 0)
			root.armBlankClock()
		if (was && !active) {
			root.currentText = ""
			root.showFailure = false
			root.unlockInProgress = false
			root.blankNotBefore = 0
			if (root.panelsOff)
				root.setPanels(false)
			root.clearShots()
		}
	}

	function lock() {
		if (sessionLock.locked || root.arming)
			return
		root.arming = true
		ShellState.closeTransient()
		grabDelay.restart()
	}

	// Capture while the session is still unlocked. A screencopy taken after
	// the lock surface is up would see the lock itself.
	function captureAndLock() {
		const screens = Quickshell.screens
		const lines = [
			"umask 077",
			"mkdir -p " + root.quote(Quickshell.cachePath("lock"))
		]
		for (let i = 0; i < screens.length; i++) {
			const name = screens[i].name
			lines.push("grim -o " + root.quote(name) + " " + root.quote(root.shotPath(name)) + " || true")
		}
		grabTimeout.restart()
		grab.exec(["sh", "-c", lines.join("\n")])
	}

	function engage() {
		if (sessionLock.locked)
			return
		grabTimeout.stop()
		root.arming = false
		root.armBlankClock()
		sessionLock.locked = true
		root.shotStamp = String(Date.now())
		root.noteLockState()
	}

	function clearShots() {
		const screens = Quickshell.screens
		const lines = []
		for (let i = 0; i < screens.length; i++)
			lines.push("rm -f " + root.quote(root.shotPath(screens[i].name)))
		if (lines.length > 0)
			cleanup.exec(["sh", "-c", lines.join("\n")])
	}

	function tryUnlock() {
		if (root.unlockInProgress || root.currentText === "")
			return
		root.unlockInProgress = true
		if (!pam.start()) {
			root.unlockInProgress = false
			root.currentText = ""
			root.showFailure = true
			root.focusTick++
		}
	}

	Timer {
		id: grabDelay
		interval: 100
		onTriggered: root.captureAndLock()
	}

	Timer {
		id: grabTimeout
		interval: 2000
		onTriggered: root.engage()
	}

	Process {
		id: grab
		stderr: StdioCollector {
			waitForEnd: true
			onStreamFinished: {
				const err = text.trim()
				if (err)
					console.warn("lock screenshot:", err)
			}
		}
		onExited: root.engage()
	}

	Process {
		id: cleanup
	}

	Connections {
		target: ShellState
		function onLockRequested() {
			root.lock()
		}
	}

	Component.onCompleted: {
		if (sessionLock.locked)
			root.noteLockState()
	}

	PamContext {
		id: pam
		configDirectory: "pam"
		config: "lock"

		onPamMessage: {
			if (pam.responseRequired)
				pam.respond(root.currentText)
		}

		onError: error => {
			console.warn("lock pam error:", PamError.toString(error))
		}

		onCompleted: result => {
			root.unlockInProgress = false
			if (result == PamResult.Success) {
				root.currentText = ""
				root.showFailure = false
				sessionLock.locked = false
				root.noteLockState()
			} else {
				console.warn("lock pam result:", PamResult.toString(result))
				root.currentText = ""
				root.showFailure = true
				root.focusTick++
			}
		}
	}

	// ext-idle-notify, only while the lock is up. Timeout is seconds.
	// respectInhibitors false uses the input-only notification, so a
	// playing video does not keep the lock screen lit.
	IdleMonitor {
		id: lockIdle
		enabled: sessionLock.locked
		timeout: root.lockSleepSeconds()
		respectInhibitors: false
		onIsIdleChanged: {
			if (!sessionLock.locked)
				return
			if (isIdle)
				root.maybeBlank()
			else
				root.noteActivity()
		}
	}

	Timer {
		interval: 1000
		repeat: true
		running: sessionLock.locked && !root.panelsOff
		onTriggered: root.maybeBlank()
	}

	WlSessionLock {
		id: sessionLock
		locked: false

		onLockedChanged: root.noteLockState()

		Timer {
			interval: 1000
			running: true
			repeat: true
			onTriggered: root.noteLockState()
		}

		WlSessionLockSurface {
			id: surface
			color: Theme.bg

			function loadShot() {
				const name = surface.screen ? surface.screen.name : ""
				background.source = ""
				if (name)
					background.source = root.fileUrl(root.shotPath(name))
			}

			function focusPassword() {
				passwordBox.forceActiveFocus()
			}

			SystemClock {
				id: clock
				precision: SystemClock.Seconds
			}

			Item {
				anchors.fill: parent
				clip: true

				Image {
					id: background
					anchors.centerIn: parent
					width: parent.width * 1.08
					height: parent.height * 1.08
					fillMode: Image.PreserveAspectCrop
					cache: false
					asynchronous: false
					smooth: true
					visible: status === Image.Ready

					layer.enabled: visible
					layer.effect: MultiEffect {
						blurEnabled: true
						blur: 1
						blurMax: 64
						autoPaddingEnabled: false
					}
				}
			}

			Rectangle {
				anchors.fill: parent
				color: background.visible ? "#b3282828" : Theme.bg
			}

			MouseArea {
				anchors.fill: parent
				onClicked: surface.focusPassword()
			}

			Column {
				anchors.centerIn: parent
				spacing: 36

				Column {
					spacing: 2

					Text {
						id: timeText
						text: Qt.formatDateTime(clock.date, "HH:mm:ss")
						color: Theme.yellow
						font.family: Theme.monoFamily
						font.pixelSize: 96
						renderType: Text.NativeRendering
					}

					Item {
						width: timeText.implicitWidth
						height: dateText.implicitHeight

						Text {
							id: dateText
							anchors.horizontalCenter: parent.horizontalCenter
							text: Qt.formatDateTime(clock.date, "MMMM d, yyyy")
							color: Theme.fg
							font.family: Theme.monoFamily
							font.pixelSize: 28
							renderType: Text.NativeRendering
						}
					}
				}

				Column {
					spacing: 10

					Rectangle {
						width: Math.max(timeText.implicitWidth, 320)
						height: 52
						radius: 0
						color: Theme.bgAlt
						border.width: 3
						border.color: root.showFailure ? Theme.red : Theme.orange

						TextInput {
							id: passwordBox
							anchors.fill: parent
							anchors.leftMargin: 16
							anchors.rightMargin: 16
							verticalAlignment: TextInput.AlignVCenter
							color: Theme.yellow
							selectionColor: Theme.orange
							selectedTextColor: Theme.bg
							font.family: Theme.fontFamily
							font.pixelSize: 18
							clip: true
							echoMode: TextInput.Password
							passwordCharacter: "•"
							selectByMouse: true
							enabled: !root.unlockInProgress
							inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

							onTextChanged: root.currentText = text
							onAccepted: root.tryUnlock()

							Keys.onEscapePressed: event => {
								event.accepted = true
							}

							Connections {
								target: root
								function onCurrentTextChanged() {
									if (passwordBox.text !== root.currentText)
										passwordBox.text = root.currentText
								}
								function onFocusTickChanged() {
									surface.focusPassword()
								}
							}
						}

						Text {
							anchors.left: parent.left
							anchors.leftMargin: 16
							anchors.verticalCenter: parent.verticalCenter
							text: "Password"
							color: Theme.muted
							font.family: Theme.fontFamily
							font.pixelSize: 18
							visible: passwordBox.text.length === 0
						}
					}

					Text {
						width: Math.max(timeText.implicitWidth, 320)
						horizontalAlignment: Text.AlignHCenter
						text: root.showFailure ? "Wrong password" : " "
						color: Theme.red
						font.family: Theme.fontFamily
						font.pixelSize: 16
					}
				}
			}

			Component.onCompleted: {
				loadShot()
				focusPassword()
				focusTimer.start()
			}
			onVisibleChanged: {
				if (visible) {
					focusPassword()
					focusTimer.start()
				}
			}
			onScreenChanged: loadShot()

			Timer {
				id: focusTimer
				interval: 80
				onTriggered: surface.focusPassword()
			}

			Connections {
				target: root
				function onShotStampChanged() {
					if (root.shotStamp)
						surface.loadShot()
				}
			}
		}
	}
}

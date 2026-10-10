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
		sessionLock.locked = true
		root.shotStamp = String(Date.now())
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

	PamContext {
		id: pam
		config: "swaylock"

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
			} else {
				console.warn("lock pam result:", PamResult.toString(result))
				root.currentText = ""
				root.showFailure = true
				root.focusTick++
			}
		}
	}

	WlSessionLock {
		id: sessionLock
		locked: false

		property bool wasLocked: false

		onLockedChanged: {
			if (wasLocked && !locked) {
				root.currentText = ""
				root.showFailure = false
				root.unlockInProgress = false
				root.clearShots()
			}
			wasLocked = locked
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

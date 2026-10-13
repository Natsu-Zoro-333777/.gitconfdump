pragma Singleton

import QtQuick
import Quickshell

Singleton {
	property Item item: null
	property string text: ""
	property bool mono: false

	function show(target, value, monospace) {
		if (!value) {
			hide(target)
			return
		}
		item = target
		text = value
		mono = !!monospace
	}

	function hide(target) {
		if (item === target) {
			item = null
			text = ""
			mono = false
		}
	}
}

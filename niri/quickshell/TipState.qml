pragma Singleton

import QtQuick
import Quickshell

Singleton {
	property Item item: null
	property string text: ""
	property bool mono: false
	property bool wide: false

	function show(target, value, monospace, roomy) {
		if (!value) {
			hide(target)
			return
		}
		item = target
		text = value
		mono = !!monospace
		wide = !!roomy
	}

	function hide(target) {
		if (item === target) {
			item = null
			text = ""
			mono = false
			wide = false
		}
	}
}

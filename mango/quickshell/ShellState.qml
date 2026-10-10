pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool launcherOpen: false
    property string launcherMonitor: ""
    property bool clipboardOpen: false
    property bool centerOpen: false
    property string centerPage: "main"
    property string wifiTarget: ""
    property bool mullvadOn: false

    function closeTransient() {
        launcherOpen = false;
        launcherMonitor = "";
        clipboardOpen = false;
        centerOpen = false;
        centerPage = "main";
        wifiTarget = "";
    }

    function toggleLauncher(monitor) {
        const open = !launcherOpen;
        closeTransient();
        if (!open)
            return;
        launcherMonitor = monitor || "";
        launcherOpen = true;
    }

    function toggleClipboard() {
        const open = !clipboardOpen;
        closeTransient();
        clipboardOpen = open;
    }

    function toggleCenter() {
        const open = !centerOpen;
        closeTransient();
        centerPage = "main";
        centerOpen = open;
    }

    function openCenter(page) {
        launcherOpen = false;
        clipboardOpen = false;
        centerPage = page || "main";
        wifiTarget = "";
        centerOpen = true;
    }

    signal lockRequested

    function requestLock() {
        closeTransient();
        lockRequested();
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property var monitors: []
    property var clients: []
    property var layouts: []
    property bool watchAlive: false

    function monitorFor(screenName) {
        for (let i = 0; i < monitors.length; i++) {
            if (monitors[i].name === screenName)
                return monitors[i];

        }
        return monitors.length > 0 ? monitors[0] : null;
    }

    function tagsFor(screenName) {
        const monitor = monitorFor(screenName);
        return monitor && monitor.tags ? monitor.tags : [];
    }

    function clientsFor(screenName) {
        const out = [];
        for (let i = 0; i < clients.length; i++) {
            const client = clients[i];
            if (client.is_minimized || client.is_scratchpad)
                continue;

            if (!screenName || client.monitor === screenName)
                out.push(client);

        }
        return out;
    }

    function layoutName(symbol) {
        for (let i = 0; i < layouts.length; i++) {
            if (layouts[i].symbol === symbol)
                return layouts[i].name;

        }
        return symbol || "";
    }

    function dispatch(args) {
        dispatchProc.exe(["mmsg", "dispatch", args]);
    }

    function viewTag(index) {
        dispatch("view," + index + ",0");
    }

    function focusClient(client) {
        const id = parseInt(client && client.id, 10);
        if (!id)
            return ;

        const tag = client.tags && client.tags.length ? parseInt(client.tags[0], 10) : 0;
        if (client.is_minimized && tag > 0) {
            dispatchProc.exec(["sh", "-c", "mmsg dispatch focusid client," + id + "; mmsg dispatch
view," + tag + ",0" + "; mmsg dispatch focusid client," + id]);
            return ;
        }
        dispatch("focusid client," + id);
    }

    function viewLeft() {
        dispatch("viewtoleft");
    }

    function viewRight() {
        dispatch("viewtoright");
    }

    function switchLayout() {
        dispatch("switch_layout");
    }

    function ingest(line) {
        const text = (line || "").trim()
        if(!text || text[0] !== "{")
            return
        let data
        try{
            data = JSON.parse(text)
        }catch(error){
            return
        }
        if (data.monitors)
            monitors = data.monitors
        if (data.clients)
            clients = data.clients
        if (data.layouts)
            layouts = data.layouts
        if (data.all_tags)
            mergeTags(data.all_tags)
        watchAlive = true
    }

   function mergeTags(allTags) {
       const byName = {}
       for (let i = 0; i < allTags.length; i++)
           byName[allTags[i].monitor] = allTags[i].tags
       const next = []
       const source = monitors.length > 0 ? monitors : []
       if (source legnth === 0){
           for (let i = 0; i < allTags.length;i++){
               next.push({
                   name:allTags[i].monitor,
                   tags:allTags[i].tags,
                   layout_symbol:activeLayout(allTags[i].tags)
            })
        }
        monitors = next
        return
    }
    for (let i = 0; i < source.length; i++){
        const monitor = source[i]
        const tags = byName[monitor.name]
        if(!tags){
            next.push(monitor)
            continue
        }
        const copy = Object.assign({}, monitor)
        copy.tags = tags
        const symbol = activeLayout(tags)
        if(symbol)
            copy.layout_symbol = symbol
        next.push(copy)
    }
    monitors = next
    }

    function activeLayout(tags){
        for(let i = 0; i < tags.length; i++){
            if (tags[i].is_active && tags[i].layout)
                return tags[i].layout
        }
        return ""
    }

    Process {
        id: dispatchProc
    }

    Process {
        id: layoutProc
        command: ["mmsg","get","layouts"]
        running:true
        stdout:StdioCollector {
            waitForEnd:true
            onStreamFinish:root.ingest(text)
        }
    }

    Process {
        id:monitorWatch
        command:["mmsg","watch","all-monitors"]
        running:true
        stdout:SplitParser {
            splitMarker:"\n"
            onRead: data => root.ingest(data)
        }
        stderr:StdioCollector{
            onStreamFinished: {
                if(text.trim())
                    console.warn("mmsg monitors:",text.trim())
            }
        }
        onExited:retryTimer.start()
    }

    Process {
        id:clientWatch
        command:["mmsg","watch","all-clients"]
        running:true
        stdout:SplitParser{
            splitMarker:"\n"
            onRead:data => root.ingest(data)
        }
        onExited:retryTimer.start()
    }

    Process {
        id:tagWatch
        command:["mmsg","watch","all-tags"]
        running:true
        stdout:SplitParser{
            splitMarker:"\n"
            onRead:data => root.ingest(data)
        }
        onExited:retryTimer.start()
    }

    Timer{
        id:retryTimer
        interval:1500
        onTriggered:{
            if(!monitorWatch.running)
                monitorWatch.running = true
            if(!clientWatch.running)
                clientWatch.running = true
            if(!tagWatch.running)
                tagWatch.running = true
        }
    }
}

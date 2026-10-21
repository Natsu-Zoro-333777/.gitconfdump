# Quickshell + niri desktop: exploratory review

Scope: 20 attached files (18 `.qml`, 1 `.py`, 1 PAM config shipped as `.bin`), read in full. The `.docx` files and a stray `.txt` (an unrelated C-course console log) were ignored.
Versions in use, from comments in the code: **Quickshell 0.3.2** (Lock.qml:17) and **niri 26.04** (Lock.qml:47). Docs checked: quickshell.org/docs/v0.3.2 and the niri wiki (Include, IPC, Introduction, Outputs).
No qmllint run: Debian 13 has no quickshell package, and building it just for a lint pass wasn't worth the time.

---

## 1. Architecture map

### Files → probable original names / roles

| Hash prefix | Probable name | Role |
|---|---|---|
| `ce1dde23` | **shell.qml** | `ShellRoot`. `//@ pragma Env QT_QPA_PLATFORMTHEME=qt6ct`. Sets up `IpcHandler`s (`launcher`, `clipboard`, `center`, `dnd`, `lock`), a `PwObjectTracker` for the default sink, and creates `Bar`, `Clipboard`, `NotifPopups`, `Lock`. Line 69 `usbWatch: Usb.open` is there only to force the `Usb` singleton to load. |
| `6c70f89a` | **Bar.qml** | `Variants` over `Quickshell.screens` → one `PanelWindow` per screen (72 px, top, Layer Top). Contains the start button, niri workspaces ("tags"), taskbar (`ToplevelManager`), system tray, notification bell, centered clock with a calendar tooltip, niri logo/overview button, volume, network, CPU, RAM, weather. Each screen's bar also creates its own **TrayMenu, Launcher, ControlCenter and tooltip PopupWindow**. |
| `37f35c90` | **ShellState.qml** | Singleton for UI state: which overlay is open (launcher/clipboard/center), center page, wifi target, `mullvadOn`, the `lockRequested` signal. |
| `20d84a98` | **Theme.qml** | Singleton holding the Gruvbox-dark palette, fonts, workspace glyphs, and helpers (`iconSource`, `plain`, audio icon/percent, wifi/wired lookup through `Quickshell.Networking`, network tooltip, ASCII calendar). |
| `149d81c4` | **TipState.qml** | Singleton for the shared tooltip (target item, text, mono/wide). |
| `15408b4a` | **Niri.qml** | Singleton for the compositor. Runs `niri msg --json event-stream` only as a "something changed" trigger, then re-runs `niri msg --json workspaces` and `windows`, and maps the result to a dwl/mango-style "monitors/tags/clients" shape (`layout_symbol`, `is_scratchpad`, …). Sends actions through `niri msg action …`. |
| `1ea319e5` | **Notifs.qml** | Singleton. `NotificationServer` (keepOnReload, actions, images, persistence), popup queue (max 4) and timeouts, DND, history ordering, and "focus the window that sent this notification" heuristics (pid chain, desktop entry, app-id, title, focus recency). |
| `a2081333` | **notif-origin.py** | Run by Notifs.qml:550 as `python3 Quickshell.shellPath("notif-origin.py")`. Wraps `dbus-monitor` on `org.freedesktop.Notifications.Notify`, resolves the sender PID with `busctl … GetConnectionUnixProcessID` (falling back to the `sender-pid` hint), walks `/proc/<pid>/status` PPid up to 16 levels, and prints JSON lines `{app,summary,body,pids}`. |
| `0c1b658b` | **ControlCenter.qml** | `PopupWindow` (400×560) anchored to the bell. Page "main": MPRIS players, Wi-Fi toggle, settings and pavucontrol buttons, master volume, per-app stream volumes, DND switch, notification "decks" grouped by app with drill-down. Page "gear": Wi-Fi list, nmtui, Mullvad connect/app, Lock. Page "wifi": `nmcli` scan, connect, password entry. |
| `de68321d` | **NotifDeck.qml** | Collapsed stack of notifications from one app, with a count badge. |
| `0a64d991` | **NotifCard.qml** | A single notification card: icon, app, summary, age, body, image, action buttons, close. |
| `d8f32adf` | **NotifPopups.qml** | Overlay `PanelWindow` at top-right that shows `Notifs.popups`. |
| `563d4567` | **Launcher.qml** | Full-screen transparent overlay `PanelWindow` (masked when closed) holding a 700×520 menu: KDE/Plasma-style categories, search, keyboard navigation, launch through `DesktopEntry.execute()` or `ghostty -e`. Calls `AppUsage.note()`. |
| `4501ae87` | **AppUsage.qml** | Singleton. Launch counts with exponential decay (3-day half-life) stored in `cachePath("launcher-usage.json")` through FileView + JsonAdapter, pruned to 200 entries. |
| `960e0ddc` | **Clipboard.qml** | `cliphist` picker overlay (700×420): filter, Enter copies, middle-click deletes. |
| `5def6dab` | **TrayMenu.qml** | Self-drawn DBus menu for SNI tray items (`QsMenuOpener`), three levels deep, opens on hover. |
| `d45e1332` | **Sysmon.qml** | Singleton. CPU (total and per-core), frequency, RAM/swap, and per-interface net rates, from a **python3 one-liner run every 3 s**. Weather from `curl wttr.in/Tucson`, cached in `cachePath("weather.txt")` and `weather-at` for 6 h. UPower battery code is commented out (this is a desktop). |
| `ac5020f0` | **Usb.qml** | Singleton. `udevadm monitor --udev --subsystem-match=usb --property` → `notify-send` on USB add/remove (replaces an old `usb-notify.sh`). |
| `31b5d0e0` | **Lock.qml** | `WlSessionLock` with a blurred `grim` screenshot per output, a clock, and a PAM password field (`PamContext configDirectory:"pam" config:"lock"`). Uses `IdleMonitor` while locked to power off monitors through niri after `NIRI_LOCK_SLEEP_SECONDS` (default 900). |
| `f024bff2…bin` | **pam/lock** | PAM stack loaded with `pam_start_confdir`: `auth required pam_unix.so`. The comment explains why `include login` can't be used there. |
| `e3286954` | **(unused) BarButton/Chip.qml** | Bordered 40 px Rectangle with `tip`, `clicked`, `wheel`. **Not referenced anywhere.** Probably a leftover or the start of a widget refactor. |

Referenced but not attached: `nirilogo.png` (Bar.qml:513), `/usr/share/pixmaps/archlinux-logo.svg` (Bar.qml:174, so the distro is Arch).

### How the files connect

```
shell.qml (ShellRoot, IpcHandlers)
 ├─ Bar (Variants × screens)
 │   ├─ TrayMenu       (per screen)
 │   ├─ Launcher       (per screen, full-screen overlay, ownsOpen() picks one monitor)
 │   ├─ ControlCenter  (per screen popup)  → NotifDeck → NotifCard
 │   └─ tooltip PopupWindow (per screen) ← TipState
 ├─ Clipboard  (overlay)
 ├─ NotifPopups → NotifCard
 └─ Lock (WlSessionLock + PamContext + IdleMonitor) ← pam/lock
Singletons: ShellState, Theme, TipState, Niri, Notifs(+notif-origin.py), Sysmon, Usb, AppUsage
```

### Where configuration lives today

There is no central config. Settings are spread out as:
- **Hardcoded in Theme.qml**: colors, fonts, workspace glyphs. This is the closest thing to a config. Font sizes (12–22 px), border widths (2/3), and sizes are literals in every file.
- **Hardcoded per file**: bar height 72 (Bar:109), popup offset 64 (NotifPopups:10, implicitly tied to the bar height), menu sizes 700×520 / 700×420 / 400×560 / 440, popup cap 4 and timeouts 5 s/10 s (Notifs:64,76), history cap 300 (ControlCenter:129), weather city "Tucson" and 6 h interval (Sysmon:22–23), sampling interval 3 s (Sysmon:369), terminal `ghostty` (Launcher:195, ControlCenter:828), mixer `env GTK_THEME=Adwaita:dark pavucontrol` (Bar:593, ControlCenter:633), Mullvad, nmtui, volume cap 1.5 (Bar:601, ControlCenter:999), Plasma category table (Launcher:29–43), Arch logo path and tooltip, emoji font "Noto Color Emoji" (Bar:818), alpha colors `#1a282828` (Bar:144) and `#b3282828` (Lock:313).
- **Env**: `NIRI_LOCK_SLEEP_SECONDS` (Lock:29), `QT_QPA_PLATFORMTHEME=qt6ct` (shell.qml:1).
- **Runtime state files** (cache, not config): `launcher-usage.json`, `weather.txt`, `weather-at`, `lock/*.png`.
- **Not persisted**: DND (Notifs:11) and notification history across restarts.

### Compositor and modules
- **Compositor: niri** (confirmed). Everything goes through `niri msg` processes. There's no Hyprland usage. The data shape ("tags", "layout_symbol", "scratchpad") suggests the bar was ported from dwl/MangoWC.
- **Quickshell modules used**: `Quickshell` (ShellRoot, Singleton, Variants, PanelWindow, PopupWindow, Scope, SystemClock, DesktopEntries, Region), `Quickshell.Io` (Process, StdioCollector, SplitParser, FileView, JsonAdapter, IpcHandler), `Quickshell.Wayland` (WlrLayershell, ToplevelManager, WlSessionLock(+Surface), IdleMonitor), `Quickshell.Widgets` (IconImage), `Quickshell.Networking`, `Quickshell.Services.Pipewire`, `.Mpris`, `.Notifications`, `.SystemTray`, `.Pam`, and `QtQuick.Effects` (MultiEffect blur). UPower is imported but commented out.
- **External tools**: niri, python3, dbus-monitor, busctl, udevadm, notify-send, cliphist, wl-copy, nmcli, nmtui, ghostty, pavucontrol, mullvad, mullvad-vpn, grim, curl, xdg-open.

---

## 2. Existing features

- **Bar** on every monitor: start/launcher button; niri workspaces with glyphs and active/occupied/urgent states, click to focus and scroll to switch; taskbar of windows on the active workspace for that monitor (click to activate, middle-click to close); SNI tray with a self-drawn hover menu (3 levels, scroll, secondary activate); notification bell (emoji state, right-click toggles DND); clock with a calendar tooltip; niri overview toggle; volume (icon by level and headphones, scroll, right-click mute, click opens pavucontrol); network (wifi/wired icon, tooltip with live up/down rates; click opens the Wi-Fi page, right-click toggles the radio); CPU % and GHz with a per-core tooltip; RAM with a swap tooltip; weather (wttr.in, 6 h cache, right-click refresh).
- **Launcher**: Plasma-style categories with counts, "Lost & Found", search over name/generic/comment/keywords, keyboard navigation (arrows, Tab/Shift-Tab, Left/Right switch category), open/close animation, terminal apps through ghostty, opens on the monitor it was invoked from, usage recording.
- **Control center**: MPRIS cards, Wi-Fi toggle, master and per-app volume, DND, notifications grouped by app with drill-down, Clear All, Wi-Fi scan/connect/password, nmtui, Mullvad toggle and app, Lock.
- **Notifications**: own server, popups (max 4, urgency-based timeouts, critical stays), actions, images, history, relative ages, DND, and **click-to-focus the sending window** (PID chain from the Python helper plus heuristics).
- **Clipboard history** picker (cliphist).
- **Lock screen**: blurred per-output screenshot, clock, PAM, monitors power off after an idle period while locked, cleanup of screenshots.
- **USB plug/unplug notifications**.
- **IPC**: `qs ipc call launcher toggle|open|close`, `clipboard toggle`, `center toggle|open|close`, `dnd toggle`, `lock lock`. These are meant to be bound in niri's `binds {}`.

---

## 3. Issues found

### Bugs
1. **Control center opens on every monitor at once.** ControlCenter.qml:305 `visible: ShellState.centerOpen && anchorItem !== null`, and each bar creates one (Bar:865). The Launcher handles this with `ownsOpen()` but the center doesn't, so with two or more screens you get several popups, all with `grabFocus: true`. Fix: add `ShellState.centerMonitor`, set it in `toggleCenter/openCenter(page, monitor)`, and check `anchorWindow.screen.name`.
2. **Tooltip window is shown on every bar.** Bar.qml:872: each screen's `tipWindow` turns visible whenever `TipState.item` is set, even when that item belongs to another screen's window. That gives mis-anchored popups and warnings on multi-monitor setups. Fix: also require `TipState.item && TipState.item.QsWindow.window === win`, or store the owning window in TipState.
3. **Broken binding on workspace hover.** Bar.qml:253–254: `onEntered: parent.color = …` / `onExited: parent.color = …` overwrite the `color:` binding at line 230. After the first hover, a workspace cell no longer follows `is_active` when focus changes through the keyboard. Fix: `color: modelData.is_active || cellMouse.containsMouse ? Theme.orange : "transparent"`.
4. **Usage tracking never affects ordering.** AppUsage records launches (Launcher:193), but `AppUsage.score()` and `promoteLimit` (AppUsage:14,25) are never used, and the launcher only sorts alphabetically (Launcher:106).
5. **Mullvad state goes stale.** It is only queried when the gear page opens, plus one retry 1.5 s after a toggle (ControlCenter:836,991). Connecting often takes longer than that, so the label is wrong. Fix: `mullvad status listen` as a long-running Process.
6. **Weather URL is not encoded** in Bar.qml:831 (`"https://wttr.in/" + location`), while Sysmon.qml:453 does encode it. A city with spaces will break.

### Security
7. **The Wi-Fi password is passed on the command line.** ControlCenter.qml:290 runs `nmcli device wifi connect <ssid> password <psk>`, so the PSK is readable in `/proc/<pid>/cmdline` by any local process while it runs. Quickshell 0.3.2 has `WifiNetwork.connectWithPsk(psk)` and `Network.connect()` in `Quickshell.Networking`, which Theme.qml already imports. Use those and drop `nmcli` for scanning too (`WifiDevice.scannerEnabled`, `device.networks`). That also removes the duplicate network model: Theme uses native Networking while ControlCenter parses `nmcli` text.

### Performance / polling
8. **Niri.qml spawns two processes on every compositor event.** Line 241 turns each event-stream line into a `wsProc` and then a `winProc` run (debounced 40 ms, lines 200–253). Terminal and browser title changes send `WindowOpenedOrChanged` constantly, so this keeps forking `niri msg`. The event stream already sends full state followed by deltas (niri wiki → IPC). Parse the events directly and use `Quickshell.Io.Socket` on `$NIRI_SOCKET` instead of `niri msg` processes (see §4.1).
9. **Sysmon starts python3 every 3 s** (Sysmon:368–377, 444). That's about 20–40 ms of interpreter start-up per tick for reading 4 procfs files. Better: `FileView`s on `/proc/stat`, `/proc/meminfo`, `/proc/net/dev` and `cpu*/cpufreq/scaling_cur_freq` with `reload()` on a Timer, parsed in JS. If procfs reads through FileView turn out to be unreliable on this version, use a single long-lived helper that prints one JSON line per interval (like notif-origin.py) instead of a new process each time. Also skip sampling when nothing visible needs it (for example while locked or panels are off).
10. **Lock.qml:259–264 polls `noteLockState()` every 1 s forever**, even when unlocked. It works around the 0.3.2 `lockStateChanged` issue noted in the comment. It's cheap, but it should be `running: sessionLock.locked || root.sawLocked`.
11. **ControlCenter rebuilds the whole notification list** on every change: it does `decks.clear()`, `JSON.stringify` per deck (ControlCenter:142–155), and NotifDeck parses it again (NotifDeck:19–26). Hover and scroll state reset, and the cost grows with history (cap 300). Prefer a `ScriptModel` (Quickshell) with `objectProp`, or update the ListModel in place.
12. **Overlays are always instantiated, once per screen.** Launcher (a full-screen layer surface that stays mapped, Launcher:288), ControlCenter and TrayMenu are created for every monitor. Clipboard and Lock surfaces are also always loaded. `LazyLoader` (or `Loader { active: … }`) would cut idle memory. The Launcher's always-mapped fade design is deliberate (see its comment), so keep it, but load it lazily on first open.

### Unbounded growth / missing error handling
13. **Notifs maps are never pruned.** `received`, `origins`, `originClient` and `focusedAt` (Notifs:12–15, 22–25, 204–213, 268) grow for the whole session. Drop entries in an `onClosed` handler or when a notification leaves `trackedNotifications`.
14. Fire-and-forget `execDetached` calls (nmcli, mullvad, pavucontrol, ghostty, grim cleanup, niri power) report no errors, so a missing binary fails silently. Long-running watchers (niri event-stream, notif-origin.py, udevadm) restart every 1.5 s with no backoff and no log cap, so a missing `udevadm` or `python3` makes a restart loop.
15. notif-origin.py matches notifications back by exact `(app, summary, body)` (Notifs:222–242). Two identical notifications race. It's acceptable, but worth knowing.
16. Notification history and DND are lost on a full restart (`keepOnReload` only covers hot reloads).

### Hardcoded / duplicated values
17. `ghostty` in two places (Launcher:195, ControlCenter:828). `pavucontrol` with its env in two places (Bar:593, ControlCenter:633). Volume cap 1.5 in three places (Bar:601, ControlCenter:691,999). `/usr/bin/niri` absolute in Lock:42 while Niri.qml uses `niri` from PATH. Popup margin 64 vs bar height 72 (NotifPopups:10 vs Bar:109). `Theme.black` duplicates `Theme.bg` (Theme:20). Alpha variants of bg are literals (Bar:144, Lock:313). The Arch logo and "Arch Linux" text are hardcoded (Bar:174,204). The niri logo is a relative asset (Bar:513). Weather city "Tucson".

### Dead code
18. `Notifs.actionSnapshots/visiblePopups/clearAll` (Notifs:91,120,143), `Niri.watchAlive/layouts/layoutName` (only used to show "niri"), `Theme.securityText/needsPassword` (Theme:168–182), `AppUsage.promoteLimit`, the commented UPower blocks, and the unused `e3286954` chip component.

---

## 4. Suggested additions (prioritized, niri-native)

All compositor work below goes through **niri IPC**, either `$NIRI_SOCKET` JSON requests or the event stream. Nothing here uses Hyprland. Quickshell 0.3.2 has no official niri module. The type index lists Hyprland, I3, and a generic `Quickshell.WindowManager` (Windowsets, ext-workspace style). Two options:
- **(a)** Stock `Quickshell.Io.Socket` on `$NIRI_SOCKET`. Recommended: no extra dependency.
- **(b)** The third-party C++ plugin `imiric/qml-niri` (used by noctalia-shell). It's more convenient, but it's something extra to build and keep in sync with niri releases.

### P1: foundations (do these first)
1. **Event-driven `Niri.qml` over the socket.** Send `"EventStream"` on one `Socket` and handle `WorkspacesChanged`, `WindowsChanged`, `WindowOpenedOrChanged`, `WindowClosed`, `WindowFocusChanged`, `WorkspaceActivated`, `WorkspaceActiveWindowChanged`, `Workspace/WindowUrgencyChanged`, `KeyboardLayoutsChanged`, `KeyboardLayoutSwitched`, `OverviewOpenedOrClosed` and `ConfigLoaded`, ignoring unknown variants (niri promises additive changes only). Send actions on a second socket as JSON, e.g. `{"Action":{"FocusWorkspace":{"reference":{"Id":8}}}}`. Focusing by **workspace id** removes the `focus-monitor && focus-workspace N` shell chain (Niri.qml:67–73). This fixes issue 8 and enables items 2–4.
2. **Config singleton + settings window** (see §5).
3. **Native Wi-Fi** through `Quickshell.Networking` (`connectWithPsk`, `connect`, `forget`, `scannerEnabled`, `connectionFailed` → "wrong password"). This fixes issue 7.
4. **niri config reload feedback**: on `ConfigLoaded {failed:true}`, show a critical notification ("niri config has errors, kept previous"). Needed as the safety net for GUI writes.
5. **Fix the multi-monitor bugs (1, 2, 3) and add LazyLoader** for the Launcher, ControlCenter, Clipboard and settings windows.

### P2: high value, fits the setup
6. **Keyboard layout indicator/switcher** from `KeyboardLayoutsChanged/Switched`; click sends `{"Action":{"SwitchLayout":{"layout":"Next"}}}`.
7. **Focused-window title** in the bar (from `WindowFocusChanged` + the window map) and an **overview-active** state on the niri logo button.
8. **Launcher ranking**: sort by `AppUsage.score()` (top N "Frequent" section, using `promoteLimit`), plus fuzzy matching. Optional calculator (`=` prefix) and run-command mode, launched through niri `spawn` so the process is parented to the compositor.
9. **Polkit agent**: `Quickshell.Services.Polkit` (`PolkitAgent`, `AuthFlow`, new in 0.3). A bare niri session usually has none, so pkexec and GUI admin prompts don't work without it. It can reuse the Lock password UI.
10. **Bluetooth page**: `Quickshell.Bluetooth` (adapter power, scan, pair/connect, device battery).
11. **Audio device switching**: list `Pipewire.nodes` sinks and sources, set `Pipewire.preferredDefaultAudioSink/Source`, add mic mute plus a mic indicator. This would reduce how often pavucontrol is needed.
12. **OSD** for volume, mic and brightness: a small overlay `PanelWindow` that appears when the Pipewire volume or mute changes, so niri's `XF86Audio*` binds get visual feedback for free.
13. **Idle and auto-lock**: `IdleMonitor` (unlocked) → `ShellState.requestLock()` after N minutes, then `power-off-monitors`. Add an **IdleInhibitor** "caffeine" toggle in the center. Lock before suspend through swayidle `before-sleep "qs ipc call lock lock"` or a logind `PrepareForSleep` watcher.
14. **Power menu**: lock, `{"Action":{"Quit":{"skip_confirmation":false}}}`, `systemctl suspend/reboot/poweroff`, `PowerOffMonitors`.
15. **Persist notification history and DND** (a JSON file through FileView, using `Notifs.pack()`), and add per-app rules (mute, never popup, urgency override).
16. **UPower for peripherals**: even without a laptop battery, UPower reports mouse, keyboard and headset batteries. The commented code can be turned into a "devices" tooltip.

### P3: nice to have
17. **Wallpaper layer**: a `PanelWindow` on `WlrLayer.Background` with an Image. Add a niri `layer-rule { match namespace="^quickshell-wallpaper$"; place-within-backdrop true; }` so it shows behind the overview. `ColorQuantizer` could then generate a palette from the wallpaper for Theme.
18. **Screenshot and recording** buttons that call niri's built-in `screenshot`, `screenshot-window` and `screenshot-screen` actions, plus a "screencast active" bar indicator (`niri msg casts`, recent versions).
19. **Clipboard image previews** (`cliphist decode` to a temp file for `[[ binary data ]]` rows) and pinning.
20. **Sysmon extras**: temperatures (`/sys/class/hwmon`), disk usage, GPU. Weather via `wttr.in/<city>?format=j1` (structured JSON, units and city from Config) instead of scraping the ANSI forecast.
21. **Night light** toggle (wlsunset or gammastep process) and external-monitor brightness through `ddcutil`.
22. **Calendar popup** with month navigation (replacing the ASCII tooltip), and MPRIS in the bar with a seek bar.

---

## 5. Settings front end: recommendation

### Is it time? Yes, with a condition: centralize config first
Nearly everything a user would change is a literal spread across 15 files. Building a GUI on top of that would mean editing QML, so the **single source of truth comes first** and the GUI second.

**Design:**
- `Config.qml` singleton = `FileView` + `JsonAdapter` on `~/.config/qs-desktop/settings.json` (keep it out of the QML directory so writes can't interfere with hot reload). Use `watchChanges: true` with `onFileChanged: reload()` so hand edits apply live, and write back on `adapterUpdated` through a 300 ms debounce timer, so a slider drag doesn't write the file 60 times a second.
- `Theme.qml` keeps its API but reads from `Config.theme.*` (for example `readonly property color bg: Config.theme.bg`). No other file needs to change at first. Then replace the literals file by file (bar height, terminal, mixer, timeouts, city, …).
- Runtime state (DND, last page, history) goes in a separate `state.json` or `PersistentProperties`, so settings stay clean.
- Niri settings are stored in the same JSON under `niri`, and a generator renders them into a GUI-owned KDL file (§5.3).

### 5.1 In-shell vs external app

| | **Inside Quickshell (`FloatingWindow`)** | **External (PySide6/QML or GTK4)** |
|---|---|---|
| Look & feel | Same Theme, same components (ActionButton, Vol…) | Has to re-implement the theme; GTK looks foreign |
| Live preview | Instant, same process binds to `Config.*` | Only through the JSON file / IPC round-trip |
| Access to services | Pipewire, Networking, Bluetooth, niri socket, DesktopEntries already there | Needs its own D-Bus and niri clients |
| Cost when closed | ~0 with `LazyLoader` | Separate process |
| Works if the shell is broken | No | Yes (a rescue tool) |
| Complex forms / KDL parsing | QtQuick.Controls is fine; KDL parsing in JS is painful | Python has KDL libraries and is easier to test |

**Recommendation:** build it **inside Quickshell** as a `FloatingWindow` (niri will tile or float it like any app; add a `window-rule` to open it floating). Open it with `qs ipc call settings toggle` and from the ⚙ button. Put file safety for niri (validate → backup → swap → rollback) in a **small shell/Python helper** called through `Process`, so it's testable and also usable from a terminal when the shell is broken. Move to PySide6 only if the niri editor grows into full keybind and window-rule editing that needs real KDL round-tripping.

### 5.2 Settings categories (mapped to the current code)

| Page | Settings | Where it is hardcoded today |
|---|---|---|
| **Appearance** | palette (bg, bgAlt, bgHover, fg, yellow, orange, red, gray, muted), bar alpha, border widths, radius (currently 0 everywhere), fonts (UI, mono, emoji), base font px, workspace glyphs, start icon path and tooltip | Theme.qml:11–38, Bar:144,174,204,818, Lock:313 |
| **Bar** | height, margins, position (top/bottom), modules on/off and order (workspaces, tasks, tray, clock format, overview, audio, net, cpu, mem, weather), clock format "hh:mm", per-monitor enable | Bar.qml throughout, NotifPopups:10 |
| **Apps** | terminal, mixer command, network-advanced command, VPN (mullvad on/off), file manager | Launcher:195, ControlCenter:633,828,835 |
| **Launcher** | size, category table on/off, sort (alpha / frequency), frequent count, search keywords | Launcher:19–43,106, AppUsage:14 |
| **Notifications** | popup position and width, max popups, timeouts (low/normal), critical sticky, history cap, DND persist, grouping on/off, click-to-focus on/off, per-app rules | Notifs:64,76, ControlCenter:129, NotifPopups:9–12 |
| **Audio** | volume cap (1.5), scroll step (0.05), default devices, per-app volume on/off | Bar:600–601, ControlCenter:691,999 |
| **Network** | backend (native/nmcli), VPN integration | ControlCenter:225–298 |
| **System monitor** | interval, show freq, net iface preference, weather city, units, interval | Sysmon:22–23,369,453 |
| **Lock & idle** | blank delay (NIRI_LOCK_SLEEP_SECONDS), blur on/off and strength, clock format, auto-lock minutes, lock on suspend | Lock:29–31,301–306,330 |
| **USB / misc** | USB notifications on/off, clipboard on/off | Usb.qml |
| **niri** | outputs, input, layout, cursor, binds (GUI-owned), window rules (GUI-owned), animations, spawn-at-startup, misc | §5.3 |

### 5.3 niri: how the GUI should read and write it

**Facts from the docs (niri 26.04):**
- The config is KDL at `$XDG_CONFIG_HOME/niri/config.kdl` (or `$NIRI_CONFIG`, or `-c`). It is **live-reloaded on save**, including binds, outputs and window rules. `niri validate [-c path]` parses a file and reports errors.
- **`include "file.kdl"`** (since 25.11) works at top level only. It is positional (later settings win), included files are also watched for live reload, `~/` paths work since 26.04, and **`include optional=true "file.kdl"`** (26.04) doesn't fail if the file is missing.
- Merging rules: most sections merge per property. `output`, `workspace` and `window-rule` are inserted as-is at the include position. `binds` override earlier conflicting keys. **Non-merging** sections: `struts`, `preset-column-widths`, individual `animations` subsections, and pointing-device sections inside `input`. If the GUI touches one of these, it must write the whole subsection. Special case: an empty `layout { border {} }` in an *included* file does nothing, so always emit `on` or `off` explicitly.
- IPC: `niri msg --json …` is a thin wrapper over JSON-per-line on `$NIRI_SOCKET`. The event stream starts with the full state, and its JSON is additive-stable.

**Recommended approach: a GUI-owned include file. Don't rewrite config.kdl.**
- Add once, by hand (the GUI can offer to do it after showing a diff), **at the end** of `config.kdl`:
  ```kdl
  // Managed by qs-desktop settings. Edit via the GUI; manual edits there are overwritten.
  include optional=true "qs-settings.kdl"
  ```
  At the end, the GUI's values override the user's. Put it at the top instead if the user's hand edits should win.
- The GUI keeps its model as JSON (`Config.niri.*`) and **generates** `qs-settings.kdl` from it every time. Only that file is written. There's no KDL parser in QML, nothing to round-trip, and the user's comments, `/-` blocks and ordering in `config.kdl` are never touched.
- To *show* the user's existing values (for example gaps already set in config.kdl), read live state where IPC exposes it (`outputs`, `keyboard-layouts`, `windows`, `layers`). For everything else, show "inherited from config.kdl (not managed)" and let the user opt in, which copies the value into the GUI file. A full parse-and-rewrite of `config.kdl` is only worth it with a real KDL library in an external Python tool.

**Safe apply pipeline** (in a helper script called through `Process`; see `niri-apply.sh` below):
1. Generate the candidate into `~/.config/niri/.qs-settings.kdl.new` (same filesystem, so `mv` is atomic).
2. Copy `~/.config/niri/` to a private temp dir (`$XDG_RUNTIME_DIR`), put the candidate in as `qs-settings.kdl`, and run `niri validate -c <tmp>/config.kdl`. This validates the full merged config, including relative includes. (Absolute or `~/` includes still resolve to the real files, which is fine.)
3. If validation fails, show niri's stderr in the GUI and stop. Nothing on disk changes.
4. If it passes, back up the current file to `~/.config/niri/qs-backups/qs-settings.kdl.<timestamp>` (keep 10), then `mv` the candidate into place. niri live-reloads.
5. Watch the event stream for `ConfigLoaded`. If `failed: true` (for example a version mismatch between `niri validate` and the running niri), restore the newest backup automatically and notify.
6. For risky changes (output mode, scale, position, `off`), preview first with transient IPC and ask "Keep these display settings? Reverting in 15 s", like GNOME does. Persist to KDL only on confirm.
7. Add a "Restore backup…" list and a "Disable GUI settings" button (rename the file away; the include is `optional`, so niri still loads).

**What niri can change at runtime through IPC, without touching the config:**
- **Outputs, transient**: `niri msg output <name> on|off|mode <WxH@R>|scale <s|auto>|transform <t>|position set <x> <y>|position auto|vrr on|off [--on-demand]`. These aren't saved, and they're forgotten when that output's config changes in the file. Good for live preview.
- **Actions** (everything bindable): focus and move windows, workspaces and monitors; `toggle-overview`; `power-off-monitors` / `power-on-monitors`; `switch-layout next|prev|<idx>` (keyboard layout); `spawn` / `spawn-sh`; `screenshot*`; fullscreen, floating and column-width changes on the focused window; `quit`; `load-config-file` (forces a reload); `do-screen-transition`. Run `niri msg action --help` to see the full list for the installed build.
- **Queries**: `outputs` (modes for dropdowns, VRR support, logical size for a drag-to-arrange monitor layout), `workspaces`, `windows`, `focused-window/output`, `layers`, `keyboard-layouts`, `pick-window` (great for creating a window rule: "click the window"), `pick-color`, `overview-state`, `casts`, `version`.
- **Config file only** (applied by live reload): `input` (keyboard xkb layout/options/repeat, touchpad, mouse accel, focus-follows-mouse, warp-mouse-to-focus), `layout` (gaps, struts, center-focused-column, default and preset column widths, focus-ring, border, shadow, tab indicator, background color), `cursor` (theme, size, hide-when-typing), `binds`, `window-rule`, `layer-rule`, `animations` (off, slowdown, per-animation curves), `gestures` / hot corners, `overview`, `prefer-no-csd`, `screenshot-path`, `environment`, `hotkey-overlay`, `spawn-at-startup`.
  - Note: **`spawn-at-startup` only runs when niri starts**, not on reload. The GUI should say "takes effect next login" and offer a "run now" button through `spawn`.
  - `environment {}` only affects processes spawned afterwards.

**niri pages in the GUI:**
- **Displays**: arrangement canvas from `outputs` (logical sizes), mode/scale/transform/VRR/off/focus-at-startup, per-output layout overrides. Preview via `niri msg output`, persist as `output "<make model serial>" {…}`, matching by make, model and serial so it survives connector changes.
- **Input**: xkb layouts and options (indicator from the event stream), repeat delay and rate, mouse/touchpad accel and natural scroll, focus-follows-mouse. Remember that pointer sections don't merge, so write the whole block.
- **Layout**: gaps, struts (whole block), focus-ring (on/off, width, colors), border (always `on`/`off`), shadow, center-focused-column, default column width and presets (whole block). Offer "use shell palette" to feed `Config.theme` colors into the focus-ring and border.
- **Keybinds**: a GUI-owned `binds {}` with a recorder field. Include ready-made entries for this shell: `Mod+Space { spawn "qs" "ipc" "call" "launcher" "toggle"; }`, `Mod+V … clipboard toggle`, `Mod+N … center toggle`, `Mod+Alt+L … lock lock`, `Mod+Comma … settings toggle`. Show a warning that binds in the main config placed after the include override these.
- **Window rules**: GUI-owned rules built with `pick-window` (app-id/title match → open-floating, default width, opacity, block-out-from screencast, open-on-workspace). Add a default rule for the settings window itself.
- **Animations**: global `off`/`slowdown`, per-animation presets (whole subsection).
- **Startup**: `spawn-at-startup` list (with the caveat above).
- **Advanced**: "Open config.kdl in editor", "Validate now", backups list.

---

## 6. Code skeleton

Style matches the existing code: tabs, `root`/`win` ids, flat Gruvbox, `radius: 0`, 2–3 px `Theme.red` borders, `Theme.fontFamily`.

### `Config.qml` (singleton, single source of truth)
```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every user setting lives here and in ~/.config/qs-desktop/settings.json.
// Hand edits reload live; changes from QML are written back after a short pause.
Singleton {
	id: root

	readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/qs-desktop"
	property bool ready: false

	readonly property alias theme: adapter.theme
	readonly property alias bar: adapter.bar
	readonly property alias apps: adapter.apps
	readonly property alias notifications: adapter.notifications
	readonly property alias audio: adapter.audio
	readonly property alias sysmon: adapter.sysmon
	readonly property alias lock: adapter.lock
	readonly property alias niri: adapter.niri

	function save() {
		saveLater.restart()
	}

	Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir])

	Timer {
		id: saveLater
		interval: 300
		onTriggered: file.writeAdapter()
	}

	FileView {
		id: file
		path: root.dir + "/settings.json"
		watchChanges: true
		atomicWrites: true
		printErrors: false
		onFileChanged: reload()
		onAdapterUpdated: root.save()
		onLoaded: root.ready = true
		onLoadFailed: function(error) {
			if (error === FileViewError.FileNotFound)
				writeAdapter() // seed defaults
			else
				console.warn("config load failed:", FileViewError.toString(error))
			root.ready = true
		}
		onSaveFailed: function(error) {
			console.warn("config save failed:", FileViewError.toString(error))
		}

		JsonAdapter {
			id: adapter

			property JsonObject theme: JsonObject {
				property string bg: "#282828"
				property string bgAlt: "#1d2021"
				property string bgHover: "#504945"
				property string fg: "#ebdbb2"
				property string yellow: "#fabd2f"
				property string orange: "#fe8019"
				property string red: "#fb4934"
				property string gray: "#a89984"
				property string muted: "#928374"
				property string fontFamily: "JetBrainsMono Nerd Font"
				property string monoFamily: "JetBrainsMono Nerd Font Mono"
				property string emojiFamily: "Noto Color Emoji"
				property int fontPx: 14
				property int border: 3
				property real barAlpha: 0.1
			}
			property JsonObject bar: JsonObject {
				property int height: 72
				property string clockFormat: "hh:mm"
				property string startIcon: "file:///usr/share/pixmaps/archlinux-logo.svg"
				property string startTip: "Arch Linux"
				property list<string> modules: ["overview", "audio", "network", "cpu", "memory", "weather"]
			}
			property JsonObject apps: JsonObject {
				property string terminal: "ghostty"
				property list<string> mixer: ["env", "GTK_THEME=Adwaita:dark", "pavucontrol"]
				property list<string> networkTool: ["ghostty", "--class=org.nmtui.nmtui", "-e", "nmtui"]
				property bool mullvad: true
			}
			property JsonObject notifications: JsonObject {
				property int maxPopups: 4
				property int lowMs: 5000
				property int normalMs: 10000
				property int historyCap: 300
				property int popupWidth: 440
				property bool focusSender: true
			}
			property JsonObject audio: JsonObject {
				property real maxVolume: 1.5
				property real step: 0.05
			}
			property JsonObject sysmon: JsonObject {
				property int intervalMs: 3000
				property string weatherLocation: "Tucson"
				property int weatherHours: 6
			}
			property JsonObject lock: JsonObject {
				property int blankSeconds: 900
				property bool blur: true
			}
			// Rendered into ~/.config/niri/qs-settings.kdl by NiriSettings.qml.
			property JsonObject niri: JsonObject {
				property bool managed: false
				property int gaps: 16
				property bool focusRing: true
				property int focusRingWidth: 4
				property bool border: false
				property int borderWidth: 4
				property bool usePalette: true
				property bool animationsOff: false
				property real animationSlowdown: 1.0
				property list<string> xkbLayouts: ["us"]
				property string xkbOptions: ""
				property bool focusFollowsMouse: false
				property var binds: ({
					"Mod+Space": ["qs", "ipc", "call", "launcher", "toggle"],
					"Mod+V": ["qs", "ipc", "call", "clipboard", "toggle"],
					"Mod+Comma": ["qs", "ipc", "call", "settings", "toggle"]
				})
				property list<string> startup: []
			}
		}
	}
}
```
Theme.qml then becomes, for example, `readonly property color bg: Config.theme.bg` and `readonly property string fontFamily: Config.theme.fontFamily`, keeping its existing API.

### `NiriSettings.qml` (singleton: render KDL, apply safely, watch reload)
```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
	id: root

	readonly property string niriDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/niri"
	property string lastError: ""
	property bool applying: false

	function q(value) {
		return "\"" + String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
	}

	function render() {
		const n = Config.niri
		const t = Config.theme
		const lines = ["// Generated by qs-desktop settings. Do not edit; changes are overwritten.", ""]
		lines.push("input {")
		lines.push("\tkeyboard {")
		lines.push("\t\txkb {")
		lines.push("\t\t\tlayout " + q(n.xkbLayouts.join(",")))
		if (n.xkbOptions)
			lines.push("\t\t\toptions " + q(n.xkbOptions))
		lines.push("\t\t}")
		lines.push("\t}")
		lines.push("\tfocus-follows-mouse " + (n.focusFollowsMouse ? "true" : "false"))
		lines.push("}", "")
		lines.push("layout {")
		lines.push("\tgaps " + n.gaps)
		lines.push("\tfocus-ring {")
		lines.push("\t\t" + (n.focusRing ? "on" : "off"))
		lines.push("\t\twidth " + n.focusRingWidth)
		if (n.usePalette) {
			lines.push("\t\tactive-color " + q(t.orange))
			lines.push("\t\tinactive-color " + q(t.bgHover))
		}
		lines.push("\t}")
		// Always explicit: an empty border {} does nothing in an included file.
		lines.push("\tborder {")
		lines.push("\t\t" + (n.border ? "on" : "off"))
		lines.push("\t\twidth " + n.borderWidth)
		if (n.usePalette)
			lines.push("\t\tactive-color " + q(t.red))
		lines.push("\t}")
		lines.push("}", "")
		lines.push("animations {")
		if (n.animationsOff)
			lines.push("\toff")
		lines.push("\tslowdown " + n.animationSlowdown.toFixed(2))
		lines.push("}", "")
		const keys = Object.keys(n.binds || {})
		if (keys.length) {
			lines.push("binds {")
			for (let i = 0; i < keys.length; i++)
				lines.push("\t" + keys[i] + " { spawn " + n.binds[keys[i]].map(q).join(" ") + "; }")
			lines.push("}", "")
		}
		for (let i = 0; i < n.startup.length; i++)
			lines.push("spawn-sh-at-startup " + q(n.startup[i]))
		lines.push("window-rule {", "\tmatch title=\"^qs-desktop settings$\"", "\topen-floating true", "}")
		return lines.join("\n") + "\n"
	}

	// Write the candidate next to the live file, then validate, back up, and swap.
	function apply() {
		if (applying)
			return
		applying = true
		lastError = ""
		candidate.setText(render())
	}

	FileView {
		id: candidate
		path: root.niriDir + "/.qs-settings.kdl.new"
		atomicWrites: true
		onSaved: applyProc.exec(["sh", Quickshell.shellPath("niri-apply.sh"), candidate.path])
		onSaveFailed: function(error) {
			root.applying = false
			root.lastError = "could not write candidate: " + FileViewError.toString(error)
		}
	}

	Process {
		id: applyProc
		stderr: StdioCollector {
			waitForEnd: true
			onStreamFinished: if (text.trim()) root.lastError = text.trim()
		}
		onExited: exitCode => {
			root.applying = false
			if (exitCode !== 0 && !root.lastError)
				root.lastError = "niri validate failed (" + exitCode + ")"
		}
	}

	// Niri.qml forwards {"ConfigLoaded":{"failed":bool}} from the event stream.
	Connections {
		target: Niri
		function onConfigLoaded(failed) {
			if (!failed)
				return
			Quickshell.execDetached(["sh", Quickshell.shellPath("niri-apply.sh"), "--rollback"])
			Quickshell.execDetached(["notify-send", "-u", "critical", "niri", "Config reload failed; restored the previous GUI settings."])
		}
	}
}
```

### `niri-apply.sh` (validate → backup → atomic swap; also `--rollback`)
```sh
#!/bin/sh
set -eu
dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
live="$dir/qs-settings.kdl"
bak="$dir/qs-backups"
mkdir -p "$bak"

if [ "${1:-}" = "--rollback" ]; then
	last=$(ls -1t "$bak"/qs-settings.kdl.* 2>/dev/null | head -n1 || true)
	[ -n "$last" ] && cp -f "$last" "$live.tmp" && mv -f "$live.tmp" "$live"
	exit 0
fi

cand="$1"
tmp=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/niri-validate.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
cp -a "$dir/." "$tmp/"
cp -f "$cand" "$tmp/qs-settings.kdl"
niri validate -c "$tmp/config.kdl"            # stderr goes back to the GUI

[ -f "$live" ] && cp -f "$live" "$bak/qs-settings.kdl.$(date +%Y%m%d-%H%M%S)"
ls -1t "$bak"/qs-settings.kdl.* 2>/dev/null | tail -n +11 | xargs -r rm -f --
mv -f "$cand" "$live"                          # same fs → atomic; niri live-reloads
```
(If the user runs niri with `$NIRI_CONFIG` or `-c`, point `dir` at that file's directory.)

### Event-stream handling to add to `Niri.qml` (socket, no process spawns)
```qml
	signal configLoaded(bool failed)
	property var layouts: []
	property int layoutIndex: 0
	property bool overviewOpen: false

	function onEvent(ev) {
		if (ev.WorkspacesChanged) root.workspaces = ev.WorkspacesChanged.workspaces
		else if (ev.WindowsChanged) root.windows = ev.WindowsChanged.windows
		else if (ev.WindowOpenedOrChanged) root.upsertWindow(ev.WindowOpenedOrChanged.window)
		else if (ev.WindowClosed) root.windows = root.windows.filter(w => w.id !== ev.WindowClosed.id)
		else if (ev.WindowFocusChanged) root.windows = root.windows.map(w => Object.assign({}, w, { is_focused: w.id === ev.WindowFocusChanged.id }))
		else if (ev.WorkspaceActivated) root.markActive(ev.WorkspaceActivated.id, ev.WorkspaceActivated.focused)
		else if (ev.KeyboardLayoutsChanged) { root.layouts = ev.KeyboardLayoutsChanged.keyboard_layouts.names; root.layoutIndex = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx }
		else if (ev.KeyboardLayoutSwitched) root.layoutIndex = ev.KeyboardLayoutSwitched.idx
		else if (ev.OverviewOpenedOrClosed) root.overviewOpen = ev.OverviewOpenedOrClosed.is_open
		else if (ev.ConfigLoaded) root.configLoaded(ev.ConfigLoaded.failed)
		else return // unknown variants are expected across niri versions
		root.publish()
	}

	function send(request) {
		commands.write(JSON.stringify(request) + "\n")
		commands.flush()
	}

	function focusWorkspaceId(id) {
		root.send({ Action: { FocusWorkspace: { reference: { Id: id } } } })
	}

	Socket {
		id: events
		path: Quickshell.env("NIRI_SOCKET")
		connected: true
		onConnectedChanged: {
			if (connected) {
				write("\"EventStream\"\n")
				flush()
			} else {
				reconnect.start()
			}
		}
		parser: SplitParser {
			onRead: line => {
				try {
					const msg = JSON.parse(line)
					if (!msg.Ok) // the first reply is {"Ok":"Handled"}
						root.onEvent(msg)
				} catch (e) {}
			}
		}
	}

	Socket {
		id: commands
		path: Quickshell.env("NIRI_SOCKET")
		connected: true
	}

	Timer {
		id: reconnect
		interval: 1500
		onTriggered: events.connected = true
	}
```
(`upsertWindow` and `markActive` are small array helpers. `publish()` stays as written, so Bar and Notifs keep working unchanged.)

### `SettingsWindow.qml` (FloatingWindow, one page shown) + wiring
```qml
import QtQuick
import QtQuick.Layouts
import Quickshell

FloatingWindow {
	id: win

	property string page: "appearance"

	title: "qs-desktop settings"
	implicitWidth: 820
	implicitHeight: 560
	color: Theme.bg

	RowLayout {
		anchors.fill: parent
		spacing: 0

		// Category rail, same look as the launcher's category list.
		Rectangle {
			Layout.fillHeight: true
			Layout.preferredWidth: 200
			color: Theme.bgAlt

			Column {
				anchors.fill: parent
				anchors.topMargin: 8

				Repeater {
					model: [
						{ id: "appearance", name: "Appearance", icon: "󰏘" },
						{ id: "bar", name: "Bar", icon: "󰍜" },
						{ id: "notifications", name: "Notifications", icon: "󰂚" },
						{ id: "niri", name: "niri", icon: "󰕰" }
					]

					Rectangle {
						required property var modelData
						width: parent.width
						height: 40
						color: win.page === modelData.id ? Theme.orange : (railMouse.containsMouse ? Theme.bgHover : "transparent")

						Text {
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 14
							text: modelData.icon + "  " + modelData.name
							color: win.page === modelData.id ? Theme.bg : Theme.fg
							font.family: Theme.fontFamily
							font.pixelSize: 14
						}

						MouseArea {
							id: railMouse
							anchors.fill: parent
							hoverEnabled: true
							onClicked: win.page = modelData.id
						}
					}
				}
			}
		}

		Rectangle {
			Layout.fillHeight: true
			Layout.preferredWidth: 2
			color: Theme.red
		}

		// One page shown: niri layout.
		ColumnLayout {
			visible: win.page === "niri"
			Layout.fillWidth: true
			Layout.fillHeight: true
			Layout.margins: 16
			spacing: 12

			Text {
				text: "niri layout"
				color: Theme.yellow
				font.family: Theme.fontFamily
				font.pixelSize: 18
				font.bold: true
			}

			SettingSlider {
				label: "Gaps"
				from: 0
				to: 48
				value: Config.niri.gaps
				onMoved: v => Config.niri.gaps = Math.round(v)
			}
			SettingToggle {
				label: "Focus ring"
				checked: Config.niri.focusRing
				onToggled: Config.niri.focusRing = !Config.niri.focusRing
			}
			SettingSlider {
				label: "Focus ring width"
				from: 1
				to: 12
				value: Config.niri.focusRingWidth
				onMoved: v => Config.niri.focusRingWidth = Math.round(v)
			}
			SettingToggle {
				label: "Border"
				checked: Config.niri.border
				onToggled: Config.niri.border = !Config.niri.border
			}
			SettingToggle {
				label: "Use shell palette for ring and border"
				checked: Config.niri.usePalette
				onToggled: Config.niri.usePalette = !Config.niri.usePalette
			}

			Item { Layout.fillHeight: true }

			Text {
				visible: NiriSettings.lastError !== ""
				Layout.fillWidth: true
				text: NiriSettings.lastError
				color: Theme.red
				font.family: Theme.monoFamily
				font.pixelSize: 12
				wrapMode: Text.WrapAnywhere
			}

			RowLayout {
				Layout.fillWidth: true
				Item { Layout.fillWidth: true }
				SettingButton {
					label: NiriSettings.applying ? "Validating…" : "Validate & apply"
					onTriggered: NiriSettings.apply()
				}
			}
		}
	}

	component SettingToggle: RowLayout {
		property string label: ""
		property bool checked: false
		signal toggled()
		Layout.fillWidth: true

		Text {
			text: parent.label
			color: Theme.fg
			font.family: Theme.fontFamily
			font.pixelSize: 14
		}
		Item { Layout.fillWidth: true }
		Rectangle { // same switch as the DND toggle in ControlCenter
			Layout.preferredWidth: 44
			Layout.preferredHeight: 24
			color: parent.checked ? Theme.orange : Theme.bgAlt
			border.width: 2
			border.color: Theme.red

			Rectangle {
				width: 16
				height: 16
				anchors.verticalCenter: parent.verticalCenter
				x: parent.parent.checked ? parent.width - width - 3 : 3
				color: parent.parent.checked ? Theme.bg : Theme.fg
			}
			MouseArea {
				anchors.fill: parent
				onClicked: parent.parent.toggled()
			}
		}
	}

	component SettingSlider: RowLayout {
		id: slider
		property string label: ""
		property real from: 0
		property real to: 1
		property real value: 0
		signal moved(real value)
		Layout.fillWidth: true
		spacing: 10

		Text {
			Layout.preferredWidth: 160
			text: slider.label
			color: Theme.fg
			font.family: Theme.fontFamily
			font.pixelSize: 14
		}
		Rectangle { // same bar as ControlCenter's Vol
			Layout.fillWidth: true
			implicitHeight: 12
			color: Theme.bgHover

			Rectangle {
				width: parent.width * (slider.value - slider.from) / (slider.to - slider.from)
				height: parent.height
				color: Theme.orange
			}
			MouseArea {
				anchors.fill: parent
				preventStealing: true
				function pick(x) {
					slider.moved(slider.from + Math.max(0, Math.min(1, x / width)) * (slider.to - slider.from))
				}
				onPressed: event => pick(event.x)
				onPositionChanged: event => { if (pressed) pick(event.x) }
			}
		}
		Text {
			Layout.preferredWidth: 36
			text: Math.round(slider.value)
			color: Theme.gray
			font.family: Theme.monoFamily
			font.pixelSize: 12
		}
	}

	component SettingButton: Rectangle {
		property string label: ""
		signal triggered()
		implicitWidth: buttonText.implicitWidth + 28
		implicitHeight: 38
		color: buttonMouse.containsMouse ? Theme.orange : Theme.bgAlt
		border.width: 2
		border.color: Theme.red

		Text {
			id: buttonText
			anchors.centerIn: parent
			text: parent.label
			color: buttonMouse.containsMouse ? Theme.bg : Theme.yellow
			font.family: Theme.fontFamily
			font.pixelSize: 14
		}
		MouseArea {
			id: buttonMouse
			anchors.fill: parent
			hoverEnabled: true
			onClicked: parent.triggered()
		}
	}
}
```
Wiring in `shell.qml`:
```qml
	LazyLoader {
		id: settingsLoader
		active: ShellState.settingsOpen
		SettingsWindow {
			onVisibleChanged: if (!visible) ShellState.settingsOpen = false
		}
	}

	IpcHandler {
		target: "settings"
		function toggle() {
			ShellState.settingsOpen = !ShellState.settingsOpen
			return ShellState.settingsOpen ? "open" : "closed"
		}
	}
```
(Add `property bool settingsOpen: false` to ShellState. Point the ⚙ ActionButton at ControlCenter.qml:625 to it, or keep "gear" as the quick page and add a "More settings…" button there.)

---

## 7. Suggested order of work
1. Fix bugs 1–3 and 7 (multi-monitor center and tooltip, workspace hover binding, Wi-Fi password in argv).
2. Rewrite Niri.qml on top of the socket event stream (issue 8) and expose `configLoaded`, keyboard layouts and overview state.
3. Add Config.qml and make Theme read from it. Then replace the literals (terminal, mixer, bar height, timeouts, city, volume cap).
4. SettingsWindow (Appearance, Bar, Notifications, Apps), all of it live through Config.
5. NiriSettings with `qs-settings.kdl` + `include optional=true` + the validate/backup/rollback pipeline, starting with layout and binds, then displays (with transient preview) and window rules (with `pick-window`).
6. Feature additions from §4 in P2 → P3 order. Polkit, the OSD, auto-lock and the launcher's frequency ranking give the most for the effort.

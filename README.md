# Amberol Deskband

A single music capsule for **Omarchy Quattro** and the customized **WinDoc / Omarchy Dock** host. Track and artist, previous/play/next, shuffle, repeat modes, compact seek and a popup listing the playlist saved by Amberol. Written in QML, using Quickshell services.

![Amberol Deskband running in WinDoc](preview.png)

## Compatibility

Validated on Omarchy **4.0.4**, Quickshell **0.3.1**, Qt **6.11.2**, Hyprland and Amberol **2026.1**. Horizontal bars are supported. The top bar uses a compact single line; WinDoc shows title and artist on two lines. Other Quickshell hosts need a matching host adapter; arbitrary Linux/Wayland shells are not automatically supported.

WinDoc integration requires **Deskband host API 1** from [brunoces11/windoc](https://github.com/brunoces11/windoc). The original [rosakodu/omarchy-dock](https://github.com/rosakodu/omarchy-dock) renders hosted widgets as icons and does not provide this capsule layout by itself.

Runtime requirements: Quickshell with QtQuick.Effects, MPRIS and PipeWire services, Python 3 for installation, and a running Omarchy Quattro shell. Amberol may be native or Flatpak; other MPRIS players can be used when Amberol is absent.

## Install

Clone this repository, open its directory, then run:

```bash
./install.sh --top
```

1. Check the Quickshell version and the existing Omarchy configuration.
2. Create a user plugin symlink and register the widget on the right of the top bar.
3. Verify the JSON changes and request a plugin rescan. No administrator access is used.

Use `./install.sh --windoc` for the compatible WinDoc host, or `./install.sh --both` to register both destinations. `--section left|center|right` chooses the top section. `--check` validates without changing configuration, and `--no-reload` skips contacting the running shell.

The installer preserves the existing top-bar visibility setting. It never enables a top bar the user has hidden. If the WinDoc adapter was just updated, its host code may require one `omarchy restart shell` before it is loaded; routine registration does not require a restart.

Installation refuses unmanaged path collisions and an unsupported WinDoc host. The current WinDoc host reserves one extra widget besides the two menus; remove another extra widget before installing the Deskband there. For systems managed by WinDoc, follow its adoption protocol and keep the real checkout inside WinDoc, preferably as a pinned Git submodule.

## Controls and player selection

The capsule remains present for a paused track and omits album art to give more room to the title. The artist line uses a 20% smaller font. In the WinDoc dock, a compact draggable progress bar sits below the controls; the top bar keeps its existing single-line height. The chevron opens a scrollable list from Amberol's saved playlist. The list refreshes when opened and when Amberol updates the playlist file. It shows filenames in the last saved playlist order; it cannot promise the exact upcoming order after shuffle. Track selection is unavailable with Amberol 2026.1 because it does not expose MPRIS TrackList controls or a working URI-open action. Click outside or use the close button to dismiss it. Long titles use an ellipsis; hover shows the full title with the host tooltip.

Amberol takes priority while running, including when paused. An open Amberol with no track collapses the capsule. When Amberol is absent, a controllable MPRIS player with a track is selected, preferring a playing source and using a stable name order to break ties. Disconnection collapses the widget and closes the panel; reconnection is handled reactively.

For the top bar, the JSON layout entry accepts `width` (up to 374.4 pixels) and `fallback` (boolean). A compact default is 218.4 pixels (minimum 200) and a full default is 265.2 pixels (minimum 240). The capsule uses a neutral gray background 15% brighter than its previous surface, with 3.4-pixel spacing between items. The same QML components are used by both hosts.

## Shuffle and repeat on Amberol 2026.1

Amberol already owns the in-memory queue and implements shuffle and repeat internally. Version 2026.1 exposes repeat through MPRIS, but does not connect MPRIS Shuffle to that queue. `AMBEROL_SHUFFLE_MPRIS.patch` adds that bridge while keeping Amberol's queue as the sole source of playback order.

On this Omarchy setup, `./BUILD_AMBEROL_LOCAL.sh` builds Amberol 2026.1 into `~/.local/lib/amberol-deskband`; it does not replace `/usr/bin/amberol` or require administrator access. The existing user wrapper prefers the custom binary when present and falls back to the packaged player otherwise. `./BUILD_AMBEROL_LOCAL.sh --restore-stock` switches the wrapper back to the packaged binary.

The build needs Rust/Cargo, Meson, Ninja, Blueprint Compiler, pkgconf, GTK 4, libadwaita, GStreamer development libraries, gettext and the standard GLib build tools. On Arch Linux, install the system dependencies with:

```bash
sudo pacman -S --needed rust cargo meson ninja blueprint-compiler pkgconf gtk4 libadwaita gstreamer gst-plugins-base gst-plugins-bad gettext glib2
```

Rust/Cargo can also come from rustup. The plugin itself remains MIT-licensed. `AMBEROL_SHUFFLE_MPRIS.patch` is for Amberol 2026.1 and is distributed for use under Amberol's GPL-3.0-or-later terms; the built player stays in the user's home directory and does not replace the system package.

- **Volume:** uses only Amberol's identified PipeWire playback streams. The system output volume is never changed. Other players use their MPRIS volume. If Amberol has no audio stream yet, the volume control is disabled until playback creates one.
- **Seek:** uses relative MPRIS `Seek` for Amberol, because `SetPosition` is not implemented. After switching tracks while paused, the decoder may not have a stream yet; seek becomes available after playback initializes it. Other players use absolute position.
- **Shuffle:** the custom Amberol build reads and writes MPRIS Shuffle and applies it to the existing queue. Other controllable MPRIS players use their own Shuffle property. The state is published back to the panel and Amberol's native playlist UI.
- **Repeat:** cycles through no repeat, repeat playlist and repeat current track through MPRIS LoopStatus. The button is enabled only when the selected player reports loop support.

The compact progress display updates locally every 500 ms while the capsule is visible and playback is active. The playlist uses Quickshell's file watcher instead of a polling loop. Metadata uses native service bindings. There is no continuous process polling and no promise of literally zero CPU during rendering or animations.

## Remove

```bash
./uninstall.sh
```

1. Remove only this plugin's entries from the top bar, plugin list and dock list.
2. Unlink only a plugin symlink pointing to this checkout; keep the source repository.
3. Preserve other settings, including edits made after installation, and request a rescan.

Installation and removal can be repeated. Configuration symlinks remain symlinks: writes replace their real targets atomically. The installer validates all inputs before changing them and attempts to roll back its own writes on a failure; it refuses concurrent configuration changes instead of overwriting them.

## Validation

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
/usr/lib/qt6/bin/qmltestrunner -input tests -platform offscreen
```

1. Exercise installation, removal, path conflicts, malformed JSON and preserved settings in temporary configuration trees.
2. Check player priority, paused behavior, metadata fallbacks and time formatting. The Qt executable location shown is the Arch Linux layout.

An optional end-to-end MPRIS lifecycle check is `dbus-run-session -- python3 tests/mpris_runtime.py`; it requires PyGObject and runs a synthetic player on a separate bus. It validates absence, empty metadata, playback, pause, disappearance and reconnection without closing or replacing a real user's queue.

Real Amberol checks covered play/pause, next/previous, relative seek and PipeWire volume. The original track, paused state, approximate position and volume were restored after testing. Multi-monitor and vertical layouts are not part of this release's validated scope.

## Structure and license

`BarWidget.qml` adapts the host presentation. `components/AmberolController.qml` owns reactive media state; `AmberolController.js` contains pure selection and formatting helpers. Capsule, popup, image, buttons and sliders are separate reusable QML components. `scripts/manage.py` handles reversible registration.

MIT, copyright Bruno Cesar. This is an independent MPRIS controller and is not an official Amberol extension. Amberol remains a separate GPL-licensed program. WinDoc's dock changes are maintained in its own repository and preserve the MIT license of the original Omarchy Dock by rosakodu.

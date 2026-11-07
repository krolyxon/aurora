import QtQuick
import QtQuick.Layouts

// Settings app > Shell: desktop widgets, dock, OSD, notifications.
Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 22

        Group {
            title: "desktop"
            keywords: "home screen widgets"
            Switch { label: "clock"; keywords: "desktop clock widget date"; hint: "Doto clock, date, stats and what's playing on the desktop"; checked: Settings.desktopClock; onToggled: on => Settings.desktopClock = on }
            Switch { label: "visualizer"; keywords: "cava spectrum music audio"; hint: "cava as columns of dots along the bottom while music plays"; checked: Settings.desktopViz; onToggled: on => Settings.desktopViz = on }
            Knob { label: "visualizer bars"; keywords: "cava spectrum"; from: 16; to: 128; value: Settings.vizBars; onMoved: v => Settings.vizBars = v }
        }

        Group {
            title: "dock"
            keywords: "taskbar launcher pinned apps"
            Switch { label: "dock"; keywords: "taskbar launcher"; hint: "autohides at the bottom edge"; checked: Settings.dock; onToggled: on => Settings.dock = on }
            Text {
                Layout.leftMargin: 18
                Layout.topMargin: 4
                text: "pinned apps (pin more from the dock's right-click)"
                color: Theme.fgDim
                font.family: Theme.ui
                font.pixelSize: 14
            }
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Layout.bottomMargin: 8
                spacing: 4
                Repeater {
                    model: Settings.dockPinned
                    delegate: IconBtn {
                        required property string modelData
                        implicitHeight: 26
                        icon: Theme.iClose
                        iconSize: 11
                        label: modelData
                        onClicked: Settings.togglePin(modelData)
                    }
                }
            }
        }

        Group {
            title: "on-screen display"
            keywords: "osd popup indicator"
            Knob { label: "osd timeout"; keywords: "on-screen display duration volume brightness popup"; unit: "ms"; from: 500; to: 4000; value: Settings.osdTimeout; onMoved: v => Settings.osdTimeout = Math.round(v / 100) * 100 }
        }

        Group {
            title: "network"
            Switch { label: "captive portals"; keywords: "hotel campus wifi login sign in hotspot"; hint: "open the login page in the browser when a network needs one"; checked: Settings.portalAutoOpen; onToggled: on => Settings.portalAutoOpen = on }
        }

        Group {
            title: "bar"
            Switch { label: "privacy indicators"; keywords: "microphone mic camera webcam screen sharing recording"; hint: "show in the bar when an app records the mic, uses the camera or shares the screen"; checked: Settings.privacyIndicators; onToggled: on => Settings.privacyIndicators = on }
        }

        Group {
            title: "weather"
            keywords: "forecast temperature"
            Field {
                label: "location"
                keywords: "city place weather"
                placeholder: "by IP · or a city · or lat,lon"
                value: Settings.weatherLoc
                onSubmitted: v => Settings.weatherLoc = v.trim()
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 18
                Layout.bottomMargin: 8
                text: Weather.ok ? (Weather.place !== "" ? Weather.place + ": " : "") + Math.round(Weather.now.temp) + "°, " + Weather.name(Weather.now.code)
                                   + (Weather.error !== "" ? " (" + Weather.error + ")" : "")
                      : Weather.busy ? "looking outside..." : Weather.error || "no weather yet"
                color: Weather.error !== "" ? Theme.err : Theme.fgDim
                font.family: Theme.ui
                font.pixelSize: 13
            }
        }

        Group {
            title: "notifications"
            keywords: "popups toasts alerts"
            Switch { label: "do not disturb"; keywords: "dnd silence quiet focus"; hint: "hide popups and mute the sound (critical ones still show)"; checked: Notifs.dnd; onToggled: on => Notifs.dnd = on }
            Switch { label: "sound"; keywords: "notification chime"; checked: Settings.notifSound; onToggled: on => Settings.notifSound = on }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Knob { label: "sound volume"; keywords: "notification chime loudness"; from: 0; to: 1; decimals: 2; value: Settings.notifVolume; onMoved: v => Settings.notifVolume = v }
                IconBtn { Layout.rightMargin: 14; icon: Theme.iPlay; implicitHeight: 26; onClicked: Notifs.playSound() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 18
                text: "~/.config/aurora/settings.json"
                elide: Text.ElideLeft
                color: Theme.fgDim
                font.family: Theme.ui
                font.pixelSize: 13
            }
            IconBtn { icon: Theme.iRefresh; label: "reset shell settings"; keywords: "reset defaults restore"; onClicked: Settings.reset() }
        }
        Item { Layout.preferredHeight: 12 }
    }
}

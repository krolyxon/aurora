import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

// Battery block (SysPage, settings app > Power): charge in Doto, state, a segment bar (accent when low), details.
// cards: on a card (the settings app); the panel shows it flat.
Group {
    id: root
    property bool cards: false
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat !== null && bat.isPresent
    readonly property real batPct: hasBat ? (bat.percentage > 1 ? bat.percentage / 100 : bat.percentage) : 0
    readonly property bool charging: hasBat && bat.state === UPowerDeviceState.Charging
    readonly property bool low: batPct <= Settings.batLow / 100 && !charging
    function stateLine() {
        if (!hasBat) return ""
        switch (bat.state) {
        case UPowerDeviceState.Charging:
            return "charging" + (bat.timeToFull > 0 ? " · full in " + Theme.fmtTime(bat.timeToFull) : "")
        case UPowerDeviceState.Discharging:
            return "on battery" + (bat.timeToEmpty > 0 ? " · " + Theme.fmtTime(bat.timeToEmpty) + " left" : "")
        case UPowerDeviceState.FullyCharged: return "on ac · full"
        default: return UPower.onBattery ? "on battery" : "on ac · not charging"
        }
    }
    visible: hasBat
    title: "battery"
    keywords: "charge level percentage health time left"
    flat: !cards
    spacing: cards ? 10 : 12
    gap: 12

    RowLayout {
        Layout.leftMargin: root.cards ? 18 : 6
        Layout.topMargin: root.cards ? 12 : 0
        spacing: 14
        Num {
            text: Math.round(root.batPct * 100)
            font.pixelSize: 56
        }
        ColumnLayout {
            spacing: 6
            Lb { text: "% battery"; color: Theme.fg }
            Lb { text: root.stateLine() }
        }
    }
    Seg {
        Layout.fillWidth: true
        Layout.preferredWidth: 100
        Layout.preferredHeight: 6
        Layout.leftMargin: root.cards ? 18 : 6
        Layout.rightMargin: root.cards ? 18 : 6
        n: 24
        f: root.batPct
        on: root.low ? Theme.err : Theme.fill
    }
    Lb {
        Layout.fillWidth: true
        Layout.leftMargin: root.cards ? 18 : 6
        Layout.bottomMargin: root.cards ? 12 : 0
        wrapMode: Text.Wrap
        lineHeight: 1.5
        px: 10
        text: {
            if (!root.hasBat) return ""
            var lines = []
            if (root.bat.changeRate !== undefined && Math.abs(root.bat.changeRate) > 0.05)
                lines.push("power draw " + Math.abs(root.bat.changeRate).toFixed(1) + " w")
            if (Settings.chargeMode !== "off" && Battery.supported)
                lines.push("charge limit · conservation" + (Battery.held ? ", holding" : ""))
            if (root.bat.healthSupported)
                lines.push("health " + Math.round(root.bat.healthPercentage) + "%")
            return lines.join("\n")
        }
    }
}

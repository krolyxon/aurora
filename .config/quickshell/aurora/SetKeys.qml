import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Settings app > Keybinds: read-only, searchable list parsed from ~/.config/hypr/source/keybinds.lua
// (`hyprctl binds` only shows "__lua <n>" for Lua binds). Comments above binds become the groups.
ColumnLayout {
    id: page
    spacing: 16
    readonly property string file: Quickshell.env("HOME") + "/.config/hypr/source/keybinds.lua"
    property var binds: []            // [{group, keys, action}]
    property string query: ""

    // split the argument list of a call at top-level commas (strings and nested brackets respected)
    function splitArgs(s) {
        var out = [], depth = 0, q = "", cur = ""
        for (var i = 0; i < s.length; i++) {
            var c = s[i]
            if (q !== "") {
                cur += c
                if (c === q && s[i - 1] !== "\\") q = ""
                continue
            }
            if (c === '"' || c === "'") { q = c; cur += c; continue }
            if (c === "(" || c === "{" || c === "[") depth++
            if (c === ")" || c === "}" || c === "]") depth--
            if (c === "," && depth === 0) { out.push(cur.trim()); cur = ""; continue }
            cur += c
        }
        if (cur.trim() !== "") out.push(cur.trim())
        return out
    }
    function keys(expr) {
        if (/\.\.\s*n\b/.test(expr)) return "SUPER + 1..0"            // the workspace loop
        var k = expr.replace(/mainMod/g, '"SUPER"').replace(/\.\./g, "").replace(/["']/g, "")
        return k.split("+").map(function (x) { x = x.trim(); return x.length === 1 ? x.toUpperCase() : x }).filter(function (x) { return x !== "" })
            .join(" + ").replace(/mouse:272/, "left-drag").replace(/mouse:273/, "right-drag")
            .replace(/mouse:274/, "middle-drag").replace(/mouse_down/, "scroll down").replace(/mouse_up/, "scroll up")
    }
    function action(expr, opts) {
        var d = /desc(?:ription)?\s*=\s*"([^"]*)"/.exec(opts || "")
        if (d) return d[1]
        var e = /exec_cmd\(([\s\S]*)\)\s*$/.exec(expr)
        if (e) return e[1].replace(/\\"/g, "\u0001").replace(/"/g, "").replace(/\u0001/g, '"')   // terminal .. " -e x" -> terminal -e x
            .replace(/\s*\.\.\s*/g, " ").trim()
        if (/^function/.test(expr)) return "lua function"
        return expr.replace(/^hl\.dsp\./, "").replace(/["{}]/g, "").replace(/\s*=\s*/g, "=")
            .replace(/\(\s*/g, " ").replace(/\s*\)/g, "").replace(/\s+/g, " ").trim()
    }
    function parse(t) {
        var lines = t.split("\n"), out = [], group = "", buf = "", depth = 0
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i], tr = l.trim()
            if (buf === "") {
                var cm = /^--+\s*(.*?)\s*-*$/.exec(tr)
                if (cm && cm[1] !== "" && !/^bind\s*=/.test(cm[1]) && cm[1].indexOf("http") < 0 && !/^-+$/.test(cm[1])) group = cm[1].replace(/^-+\s*/, "")
                if (tr.indexOf("hl.bind(") !== 0) continue
            }
            buf += l + "\n"
            depth += (l.match(/\(/g) || []).length - (l.match(/\)/g) || []).length
            if (depth > 0) continue
            var inner = buf.slice(buf.indexOf("hl.bind(") + 8, buf.lastIndexOf(")"))
            var a = splitArgs(inner)
            if (a.length >= 2) out.push({ group: group, keys: keys(a[0]), action: action(a[1], a[2]) })
            buf = ""
            depth = 0
        }
        binds = out
    }

    readonly property var shown: {
        var q = query.toLowerCase(), out = [], last = null
        for (var i = 0; i < binds.length; i++) {
            var b = binds[i]
            if (q !== "" && (b.keys + " " + b.action + " " + b.group).toLowerCase().indexOf(q) < 0) continue
            if (b.group !== last) { out.push({ header: b.group }); last = b.group }   // group header row
            out.push(b)
        }
        return out
    }

    FileView {
        path: page.file
        watchChanges: true
        onFileChanged: reload()
        onLoaded: page.parse(text())
    }

    Field {
        id: search
        label: Theme.iSearch + "  filter"
        placeholder: "key, command or group"
        value: page.query                 // the settings search sets it
        onEdited: v => page.query = v
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 0
        model: page.shown
        boundsBehavior: Flickable.StopAtBounds
        // a group header, or a bind on its group's card: s1 rows whose outer corners round where the group starts / ends
        delegate: Item {
            id: d
            required property var modelData
            required property int index
            readonly property bool isHeader: modelData.header !== undefined
            readonly property bool first: index === 0 || page.shown[index - 1].header !== undefined
            readonly property bool last: index === page.shown.length - 1 || page.shown[index + 1].header !== undefined
            width: ListView.view.width
            height: isHeader ? (index === 0 ? 0 : 22) + 30 : 44 + (first ? 8 : 0) + (last ? 8 : 0)
            SectionLabel {
                visible: d.isHeader
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                text: d.isHeader ? d.modelData.header : ""
            }
            Rectangle {
                visible: !d.isHeader
                anchors.fill: parent
                color: Theme.s1
                topLeftRadius: d.first ? 36 : 0
                topRightRadius: d.first ? 36 : 0
                bottomLeftRadius: d.last ? 36 : 0
                bottomRightRadius: d.last ? 36 : 0
                RowLayout {
                    x: 26
                    y: (d.first ? 8 : 0) + (44 - height) / 2
                    width: parent.width - 52
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 240
                        implicitHeight: 30
                        radius: 15
                        color: Theme.s2
                        Lb {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            text: d.modelData.keys || ""
                            color: Theme.fill
                            elide: Text.ElideRight
                            px: 10
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: d.modelData.action || ""
                        color: Theme.fg
                        elide: Text.ElideRight
                        font.family: Theme.ui
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
    Text {
        Layout.leftMargin: 18
        text: page.binds.length + " binds  ·  " + page.file.replace(Quickshell.env("HOME"), "~")
        color: Theme.fgDim
        font.family: Theme.ui
        font.pixelSize: 13
    }
}

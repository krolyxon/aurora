import QtQuick
import QtQuick.Layouts

// A settings group: the caps title, then its rows on a rounded s1 card (Android / Nothing OS settings).
// flat = the title and rows without the card (pages shared with the control panel, which already is a card).
// SetIndex reads a literal `title:` (+ `keywords:`) as the group, like a SectionLabel's `text:`.
ColumnLayout {
    id: g
    property string title: ""
    property string keywords: ""    // synonyms for the settings search (SetIndex reads them from the source)
    property string count: ""
    property bool flat: false
    property alias gap: body.spacing
    default property alias rows: body.data

    readonly property int pad: flat ? 0 : 8

    Layout.fillWidth: true
    Layout.fillHeight: false        // a layout's default is true; a page sets it for a list that scrolls inside
    spacing: flat ? 4 : 10

    SectionLabel {
        visible: g.title !== ""
        Layout.leftMargin: g.flat ? 0 : 14
        text: g.title
        count: g.count
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: g.Layout.fillHeight     // only when the group itself fills (a list that scrolls inside)
        implicitHeight: body.implicitHeight + 2 * g.pad
        radius: 28 + g.pad
        color: g.flat ? "transparent" : Theme.s1
        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: g.pad
            spacing: 4
        }
    }
}

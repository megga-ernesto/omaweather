import QtQuick
import QtQuick.Layouts
import qs.Commons as C
import qs.Ui as Ui

Ui.BorderSurface {
    id: group
    required property string title
    default property alias controls: fields.data
    Layout.fillWidth: true
    readonly property int inset: C.Style.spacing.xxl
    implicitHeight: fields.implicitHeight + 2 * inset
    radius: C.Style.cornerRadius
    color: Qt.alpha(C.Color.popups.text, 0.055)
    borderSpec: C.Border.flat(Qt.alpha(C.Color.popups.text, 0.15), 1)

    property Item contents: ColumnLayout {
        id: fields
        parent: group
        anchors.fill: parent
        anchors.margins: group.inset
        spacing: C.Style.spacing.rowGap
        Text {
            Layout.fillWidth: true
            text: group.title
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: C.Color.popups.text
            font.family: C.Style.font.family
            font.pixelSize: C.Style.font.body
            font.bold: true
        }
    }
}

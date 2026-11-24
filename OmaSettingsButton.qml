import QtQuick
import qs.Ui as Ui
import qs.Commons as C

Ui.Button {
    property bool closing: false
    required property var catalog
    iconText: closing ? "×" : ""
    tooltipText: catalog.t(closing ? "oma.closeSettings" : "oma.settings")
    foreground: C.Color.popups.text
    focusable: true
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText
    Accessible.onPressAction: clicked()
}

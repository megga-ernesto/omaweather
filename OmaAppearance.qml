import QtQuick
import QtQuick.Layouts
import qs.Ui as Ui
import qs.Commons as C

ColumnLayout {
    id: appearance
    required property OmaPanelFrame frame
    required property var catalog
    spacing: C.Style.spacing.labelGap
    readonly property var modes: ["base", "glass", "blur"]
    function focusSelected() { choices.itemAt(Math.max(0, modes.indexOf(frame.finish)))?.forceActiveFocus() }

    Flow {
        Layout.fillWidth: true
        spacing: C.Style.spacing.md
        Repeater {
            id: choices
            model: appearance.modes
            Ui.Button {
                required property string modelData
                required property int index
                text: appearance.catalog.t("oma." + modelData)
                selected: modelData === appearance.frame.finish
                bordered: true
                focusable: true
                foreground: C.Color.popups.text
                Accessible.role: Accessible.RadioButton
                Accessible.name: text
                Accessible.checkable: true
                Accessible.checked: selected
                Accessible.onPressAction: clicked()
                onClicked: appearance.frame.setFinish(modelData)
                Keys.onPressed: event => {
                    const key = C.Util.readingKey(event, true)
                    if (key !== Qt.Key_Left && key !== Qt.Key_Right) return
                    const count = appearance.modes.length
                    appearance.frame.setFinish(appearance.modes[(index + (key === Qt.Key_Right ? 1 : count - 1)) % count])
                    appearance.focusSelected()
                    event.accepted = true
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: text.length > 0
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: appearance.frame.saveFailed ? appearance.catalog.t("oma.saveFailed")
            : appearance.frame.glass && !appearance.frame.materialApplied ? appearance.catalog.t("oma.materialFailed")
            : appearance.frame.finish === "blur" && appearance.frame.blurFailed ? appearance.catalog.t("oma.blurFailed") : ""
        font.family: C.Style.font.family
        font.pixelSize: C.Style.font.body
        color: C.Color.popups.text
    }
}

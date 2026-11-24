import QtQuick
import QtQuick.Layouts
import qs.Commons as C

// For panels whose main and settings pages own their scrolling and headers.
FocusScope {
    id: workspace
    required property OmaPanelFrame frame
    required property Item mainFocus
    required property Item settingsFocus
    property alias mainPane: mainSlot.data
    property alias settingsPane: settingsSlot.data
    signal settingsRequested(bool opened)
    implicitHeight: columns.implicitHeight

    function showSettings(opened) {
        settingsRequested(opened)
        Qt.callLater(() => {
            if (frame.open) (frame.configuring ? settingsFocus : mainFocus).forceActiveFocus()
        })
    }
    Keys.onEscapePressed: {
        if (frame.configuring) showSettings(false)
        else frame.close()
    }

    RowLayout {
        id: columns
        anchors.fill: parent
        spacing: C.Style.spacing.panelGap
        Item {
            id: mainSlot
            visible: !workspace.frame.configuring || workspace.frame.wide
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            implicitHeight: children[0]?.implicitHeight ?? 0
        }
        Rectangle {
            visible: workspace.frame.wide
            Layout.fillHeight: true
            implicitWidth: 1
            color: Qt.alpha(C.Color.popups.text, 0.12)
        }
        Item {
            id: settingsSlot
            visible: workspace.frame.configuring
            Layout.fillWidth: !workspace.frame.wide
            Layout.preferredWidth: workspace.frame.wide ? workspace.frame.settingsWidth : -1
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            implicitHeight: children[0]?.implicitHeight ?? 0
        }
    }
}

import QtQuick
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons as C
import qs.Ui as Ui

Ui.KeyboardPanel {
    id: panel
    required property string layerName
    property string legacyGlassKey: ""
    property string legacyBlurKey: ""
    property bool configuring: false
    property int preferredWidth: C.Style.space(442)
    readonly property int settingsWidth: C.Style.space(318)
    readonly property bool wide: configuring && availableCardWidth >= C.Style.space(760) + C.Style.spacing.panelGap

    property string finish: {
        const saved = owner?.setting("appearanceMode", "")
        if (["base", "glass", "blur"].includes(saved)) return saved
        if (!legacyGlassKey || owner?.setting(legacyGlassKey, false) !== true) return "base"
        return owner.setting(legacyBlurKey, false) === true ? "blur" : "glass"
    }
    readonly property bool glass: finish === "glass" || finish === "blur"
    readonly property bool materialApplied: material.applied
    readonly property string requestedLayerName: finish === "base" ? "omarchy-keyboard-panel" : layerName
    property string mappedLayerName: "omarchy-keyboard-panel"
    property bool remappingLayer: false
    readonly property bool needsBlur: open && finish === "blur" && materialApplied
        && !remappingLayer && mappedLayerName === layerName
    property bool saveFailed: false
    property bool blurFailed: false

    WlrLayershell.namespace: mappedLayerName
    onRequestedLayerNameChanged: syncLayer()
    Component.onCompleted: syncLayer()
    contentWidth: fittedContentWidth(preferredWidth + (wide ? settingsWidth + C.Style.spacing.panelGap : 0))
    contentHeight: fittedContentHeight(loadedContentHeight)
    focusTarget: loadedContent
    borderSpec: materialApplied ? C.Border.flat(Qt.alpha(C.Color.popups.text, 0.24), 1)
        : C.Border.surfaceSpec("popups", "border", C.Color.popups.border, Math.max(1, C.Style.space(2)))

    function setFinish(mode) {
        const entry = Object.assign({}, owner.settings, {id: owner.moduleName, appearanceMode: mode})
        saveFailed = !bar?.shell?.updateEntryInline(owner.moduleName, entry)
        if (!saveFailed) owner.settings = entry
    }

    function syncLayer() {
        if (remappingLayer || !requestedLayerName || mappedLayerName === requestedLayerName) return
        if (!visible) {
            mappedLayerName = requestedLayerName
            return
        }

        // Wayland sets the namespace when the surface is created. Keep the
        // panel open logically so Omarchy retains its content and ownership.
        const focusedItem = loadedContent?.Window.window?.activeFocusItem
        remappingLayer = true
        Qt.callLater(() => {
            mappedLayerName = requestedLayerName
            if (panel.open) panel.focusPrimed = false
            remappingLayer = false
            if (open && focusedItem) focusedItem.forceActiveFocus()
        })
    }

    property Binding remapVisibility: Binding {
        target: panel
        property: "visible"
        when: panel.remappingLayer
        value: false
    }

    OmaMaterial { id: material; glass: panel.glass }

    property Process backdrop: Process {
        running: panel.needsBlur
        command: ["python3", "-B", decodeURIComponent(Qt.resolvedUrl("backdrop.py").toString().slice(7)), panel.layerName]
        onStarted: panel.blurFailed = false
        onExited: code => panel.blurFailed = panel.needsBlur && code !== 0
    }
}

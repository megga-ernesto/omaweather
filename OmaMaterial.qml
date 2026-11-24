import QtQuick
import "OmaColors.js" as Palette
import qs.Commons as C
import qs.Ui as Ui

// Adaptador para la tarjeta que KeyboardPanel dibuja alrededor del contenido.
// Solo el acabado especial depende de la estructura interna del shell.
Item {
    id: material
    property bool glass: false
    readonly property var frame: {
        let item = parent
        while (item && !(item instanceof Ui.BorderSurface))
            item = item.parent
        return item
    }
    readonly property bool applied: glass && !!frame

    readonly property real inkLuminance: Palette.luminance(C.Color.popups.text)

    function readable(color, alpha) {
        const layer = Qt.alpha(color, alpha)
        const darkest = Palette.luminance(Qt.tint("black", layer))
        const lightest = Palette.luminance(Qt.tint("white", layer))
        return (darkest + 0.05) / (inkLuminance + 0.05) >= 4.5
            || (inkLuminance + 0.05) / (lightest + 0.05) >= 4.5
    }

    function tone(tint, alpha) {
        const base = Qt.alpha(C.Color.popups.background, 1)
        let color = Qt.tint(base, Qt.alpha(C.Color.accent, tint))
        if (!readable(color, 1)) color = base
        while (alpha < 1 && !readable(color, alpha))
            alpha = Math.min(1, alpha + 0.02)
        return Qt.alpha(color, alpha)
    }

    property Gradient glassGradient: Gradient {
        GradientStop { position: 0; color: material.tone(0.06, 0.77) }
        GradientStop { position: 0.54; color: material.tone(0.03, 0.72) }
        GradientStop { position: 1; color: material.tone(0.00, 0.88) }
    }

    Binding {
        when: material.applied
        target: material.frame
        property: "color"
        value: "transparent"
    }
    Binding {
        when: material.applied
        target: material.frame
        property: "radius"
        value: C.Style.space(20)
    }

    Rectangle {
        parent: material.frame || material
        anchors.fill: parent
        visible: material.applied
        z: -1
        radius: material.frame?.radius ?? 0
        gradient: material.glassGradient
    }

    Rectangle {
        parent: material.frame || material
        visible: material.applied
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: C.Style.space(24)
        anchors.rightMargin: C.Style.space(24)
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(C.Color.popups.text, 0.22) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}

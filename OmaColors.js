.pragma library

function linear(channel) {
    return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
}

function luminance(color) {
    return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
}

function inkOn(fill, text, background) {
    const level = luminance(fill)
    function contrast(ink) {
        const value = luminance(ink)
        return (Math.max(level, value) + 0.05) / (Math.min(level, value) + 0.05)
    }
    if (contrast(text) >= 4.5) return text
    if (contrast(background) >= 4.5) return Qt.alpha(background, 1)
    return level > 0.179 ? "black" : "white"
}

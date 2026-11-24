function condition(code, night) {
    if (code === 0) return night ? ["clear", "󰖔"] : ["clear", "󰖙"]
    if (code === 1 || code === 2) return night ? ["partly", "󰼱"] : ["partly", "󰖕"]
    if (code === 3) return ["cloudy", "󰖐"]
    if (code === 45 || code === 48) return ["fog", "󰖑"]
    if (code >= 95 && code <= 99) return ["storm", "󰖓"]
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return ["snow", "󰖘"]
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return ["rain", "󰖗"]
    return ["unknown", "󰖕"]
}

function validPlace(place) {
    return place && typeof place.name === "string" && place.name.length > 0
        && place.name.length <= 80 && Number.isFinite(place.lat) && Math.abs(place.lat) <= 90
        && Number.isFinite(place.lon) && Math.abs(place.lon) <= 180
}

function forecastNotices(report) {
    if (!report || !Array.isArray(report.hours)) return []
    const notices = []
    for (const sample of [report, ...report.hours.slice(0, 24)]) {
        if (typeof sample?.time !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(sample.time))
            continue
        const kind = sample.code === 96 || sample.code === 99 ? "forecastHail"
            : sample.code === 95 || sample.code === 97 ? "forecastStorm"
            : sample.code === 65 || sample.code === 82 ? "forecastHeavyRain" : ""
        if (kind && !notices.some(notice => notice.kind === kind))
            notices.push({ kind, time: sample.time })
    }
    return notices
}

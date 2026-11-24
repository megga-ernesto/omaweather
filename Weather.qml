import QtQuick
import "OmaColors.js" as Palette
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui as Ui
import "Conditions.js" as Weather

Ui.BarWidget {
  id: root
  moduleName: "elmegga.omaweather"

  readonly property var defaultPlace: ({name: "Ciudad Juárez", lat: 31.6904, lon: -106.4245})
  readonly property var place: Weather.validPlace(setting("place", null)) ? setting("place", null) : defaultPlace
  readonly property string placeKey: place.lat + "," + place.lon
  readonly property var intervals: [5, 15, 30, 60]
  readonly property int minutes: intervals.includes(setting("minutes", 15)) ? setting("minutes", 15) : 15
  readonly property bool automatic: setting("automatic", true) === true
  readonly property bool forecastAlerts: setting("forecastAlerts", false) === true

  readonly property color ink: Commons.Color.popups.text
  readonly property color background: Commons.Color.popups.background
  readonly property color accent: Commons.Color.accent
  readonly property color accentInk: Palette.inkOn(accent, ink, Commons.Color.background)
  readonly property color softInk: Qt.tint(ink, Qt.alpha(background, 0.32))
  readonly property color surface: Qt.alpha(ink, 0.055)
  readonly property string scriptFolder: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
  property var report: null
  property var results: []
  property string requestedPlace: ""
  property string searchStatus: ""
  property bool requested: false
  property bool opened: false
  property bool configuring: false
  property bool failed: false
  property bool saveFailed: false
  property var announcedKinds: []
  readonly property var forecastNotices: forecastAlerts && !failed ? Weather.forecastNotices(report) : []

  property string forecastView: "hourly"
  property int hourPage: 0
  readonly property int hoursPerPage: 6
  readonly property var hours: report?.hours ?? []
  readonly property int lastHourPage: Math.max(0, Math.ceil(hours.length / hoursPerPage) - 1)

  implicitWidth: vertical ? barSize : s(85)
  implicitHeight: vertical ? s(33) : barSize

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function s(value) { return Commons.Style.space(value) }
  function decimal(value) { return value === null ? "—" : Commons.I18n.formatNumber(value, 0) }
  function temp(value) { return value === null ? "—" : decimal(value) + "°" }
  function unit(value, suffix, precision = 0) {
    return value == null ? "—" : Commons.I18n.formatNumber(value, precision) + suffix
  }
  function weekday(value) {
    const parts = value.split("-").map(Number)
    return Qt.locale(Commons.I18n.formatLocale).dayName(
      new Date(parts[0], parts[1] - 1, parts[2]).getDay(), Locale.ShortFormat)
  }
  function save(key, value) {
    const entry = Object.assign({}, settings, {id: moduleName})
    entry[key] = value
    saveFailed = !bar || !bar.shell || !bar.shell.updateEntryInline(moduleName, entry)
    if (!saveFailed) settings = entry
    return !saveFailed
  }
  function refresh() {
    if (fetch.running) return
    requested = true
    requestedPlace = placeKey
    fetch.command = ["python3", "-B", decodeURIComponent(scriptFolder) + "weather.py",
      "forecast", String(place.lat), String(place.lon)]
    fetch.running = true
    if (automatic) ticker.restart()
  }
  function noticeText(notice) {
    return strings.t(notice.kind).arg(notice.time.replace("T", " "))
  }
  function notifyForecast() {
    if (!forecastAlerts || failed || !report || !bar) return
    const widgets = typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : []
    if (widgets.length && widgets[0] !== root) return
    const pending = forecastNotices.filter(notice => !announcedKinds.includes(notice.kind))
    announcedKinds = forecastNotices.map(notice => notice.kind)
    if (!pending.length) return
    const body = [place.name, ...pending.map(noticeText), strings.t("forecastNoticeNote")].join("\n")
    const escaped = body.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    Quickshell.execDetached(["notify-send", "--app-name=ElMeGGa OmaWeather", "--icon=weather-storm", "--",
      strings.t("forecastNoticeTitle"), escaped])
  }
  function search(query) {
    if (lookup.running || query.trim().length < 2) return
    results = []
    searchStatus = ""
    const language = Commons.I18n.formatLocale.split(/[-_]/)[0]
    lookup.command = ["python3", "-B", decodeURIComponent(scriptFolder) + "weather.py",
      "search", query, language]
    lookup.running = true
  }
  function open() {
    if (!opened) {
      configuring = false
      opened = true
      if (!requested) refresh()
    }
  }
  function close() { opened = false }
  function closeForPopoutSwitch() { close() }

  onPlaceKeyChanged: {
    announcedKinds = []
    report = null
    hourPage = 0
    requested = false
    if ((opened || automatic) && bar) refresh()
  }
  onForecastNoticesChanged: Qt.callLater(notifyForecast)
  onForecastAlertsChanged: if (!forecastAlerts) announcedKinds = []
  onLastHourPageChanged: hourPage = Math.min(hourPage, lastHourPage)
  onAutomaticChanged: {
    if (automatic && bar) refresh()
  }
  Timer {
    id: ticker
    interval: root.minutes * 60000
    running: root.automatic && !!root.bar
    repeat: true
    onTriggered: root.refresh()
  }
  onBarChanged: {
    if (bar && automatic) Qt.callLater(refresh)
  }

  Process {
    id: fetch
    stdout: StdioCollector { id: readings }
    onExited: function(code) {
      if (root.requestedPlace !== root.placeKey) {
        Qt.callLater(root.refresh)
        return
      }
      if (code === 0) {
        try {
          root.report = JSON.parse(readings.text)
          root.failed = false
          return
        } catch (error) {}
      }
      root.failed = true
    }
  }
  Process {
    id: lookup
    stdout: StdioCollector { id: cities }
    onExited: function(code) {
      if (code === 0) {
        try {
          root.results = JSON.parse(cities.text).filter(Weather.validPlace)
          root.searchStatus = root.results.length ? "" : "noCities"
          return
        } catch (error) {}
      }
      root.searchStatus = "searchFailed"
    }
  }

  component Label: Text {
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.ink
    font.family: Commons.Style.font.family
    font.pixelSize: Commons.Style.font.body
  }
  component Action: Ui.Button {
    focusable: true
    bordered: true
    foreground: root.ink
    Accessible.role: Accessible.Button
    Accessible.name: text || tooltipText
    Accessible.onPressAction: clicked()
  }
  component Toggle: Controls.Switch {
    id: control
    implicitHeight: root.s(34)
    padding: 0
    indicator: Rectangle {
      x: control.mirrored ? 0 : control.width - width
      y: (control.height - height) / 2
      width: root.s(34)
      height: root.s(19)
      radius: height / 2
      color: control.checked ? root.accent : root.surface
      border.width: 1
      border.color: control.visualFocus ? root.accent : Qt.alpha(root.ink, 0.15)
      Rectangle {
        x: control.checked !== control.mirrored ? parent.width - width - root.s(3) : root.s(3)
        anchors.verticalCenter: parent.verticalCenter
        width: root.s(13)
        height: width
        radius: width / 2
        color: control.checked ? root.accentInk : root.ink
        Behavior on x { NumberAnimation { duration: Commons.Style.duration(150); easing.type: Easing.OutCubic } }
      }
    }
    contentItem: Label {
      text: control.text
      wrapMode: Text.WordWrap
      elide: Text.ElideNone
      verticalAlignment: Text.AlignVCenter
      leftPadding: control.mirrored ? root.s(42) : 0
      rightPadding: control.mirrored ? 0 : root.s(42)
    }
  }
  component ForecastRow: RowLayout {
    property string period: ""
    property var code
    property bool night: false
    property var chance
    property var minimum: null
    property var temperature
    property bool showRange: false
    Layout.fillWidth: true
    spacing: root.s(8)
    Label { Layout.fillWidth: true; text: period }
    Label {
      text: Weather.condition(code, night)[1]
      Accessible.name: strings.t(Weather.condition(code, night)[0])
      color: root.accent
      font.pixelSize: root.s(19)
    }
    Label {
      Layout.preferredWidth: root.s(65)
      horizontalAlignment: Text.AlignRight
      text: chance == null ? "—" : "󰖌 " + root.unit(chance, "%")
      Accessible.name: strings.t("rainChance") + " " + root.unit(chance, "%")
      color: root.softInk
      font.pixelSize: Commons.Style.font.bodySmall
    }
    Label {
      visible: showRange
      Layout.preferredWidth: root.s(40)
      horizontalAlignment: Text.AlignRight
      text: root.temp(minimum)
      color: root.softInk
    }
    Label {
      Layout.preferredWidth: root.s(34)
      horizontalAlignment: Text.AlignRight
      text: root.temp(temperature)
      font.bold: true
    }
  }

  Ui.WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.forecastNotices.length ? strings.t("forecastNoticeTitle") : strings.t("title")
    hasVisualContent: true
    labelVisible: false
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.opened ? root.close() : root.open()
    }
    Row {
      anchors.centerIn: parent
      spacing: root.s(7)
      Label {
        width: root.s(17)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
        text: Weather.condition(root.report?.code, root.report?.night)[1]
        color: root.forecastNotices.length ? Commons.Color.urgent : button.foreground
        font.family: button.fontFamily
        font.pixelSize: Math.min(root.s(14), root.barSize - root.s(6))
      }
      Label {
        visible: !root.vertical
        text: root.report ? root.temp(root.report.temperature) : "—"
        font.family: button.fontFamily
        font.pixelSize: Math.min(root.s(14), root.barSize - root.s(6))
        color: button.foreground
      }
    }
  }

  OmaPanelFrame {
    id: popup
    layerName: "omarchy-omaweather"
    owner: root
    bar: root.bar
    anchorItem: button
    open: root.opened
    configuring: root.configuring
    legacyGlassKey: "glass"
    legacyBlurKey: "blur"

    content: OmaWorkspace {
      id: page
      frame: popup
      mainFocus: settingsButton
      settingsFocus: closeSettingsButton
      onSettingsRequested: value => root.configuring = value

      mainPane: ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        spacing: Commons.Style.spacing.panelGap
        RowLayout {
          Layout.fillWidth: true
          Label {
            text: strings.t("title")
            Layout.fillWidth: true
            font.bold: true
            font.pixelSize: Commons.Style.font.title
          }
          Action {
            tooltipText: strings.t("refresh")
            iconText: "󰑐"
            enabled: !fetch.running
            onClicked: root.refresh()
          }
          OmaSettingsButton {
            id: settingsButton
            catalog: strings
            selected: popup.configuring
            onClicked: page.showSettings(!popup.configuring)
          }
        }
        Controls.ScrollView {
          id: weatherScroll
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredHeight: weatherBody.implicitHeight
          contentWidth: availableWidth
          clip: true
          ColumnLayout {
            id: weatherBody
            width: weatherScroll.availableWidth
            spacing: root.s(8)
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: hero.implicitHeight + root.s(28)
              radius: root.s(14)
              color: root.surface
              RowLayout {
                id: hero
                anchors { fill: parent; margins: root.s(14) }
                spacing: root.s(14)
                Label {
                  text: Weather.condition(root.report?.code, root.report?.night)[1]
                  color: root.accent
                  font.pixelSize: root.s(51)
                }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: root.s(3)
                  Label { Layout.fillWidth: true; text: root.place.name; color: root.softInk }
                  Label {
                    Layout.fillWidth: true
                    font.bold: true
                    font.pixelSize: root.s(21)
                    text: root.report ? root.temp(root.report.temperature) + "C" : "—"
                  }
                  Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    text: fetch.running && !root.report ? strings.t("loading")
                      : strings.t(Weather.condition(root.report?.code, root.report?.night)[0])
                  }
                }
              }
            }
            OmaGroup {
              Layout.fillWidth: true
              visible: root.forecastNotices.length > 0
              title: strings.t("forecastNoticeTitle")
              Repeater {
                model: root.forecastNotices
                delegate: Label {
                  required property var modelData
                  Layout.fillWidth: true
                  wrapMode: Text.WordWrap
                  elide: Text.ElideNone
                  text: root.noticeText(modelData)
                }
              }
              Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                color: root.softInk
                text: strings.t("forecastNoticeNote")
              }
            }
            RowLayout {
              visible: !!root.report
              Layout.fillWidth: true
              spacing: root.s(6)
              Repeater {
                model: [
                  { key: "feels", value: root.report ? root.temp(root.report.feels) : "—" },
                  { key: "humidity", value: root.report?.humidity != null ? root.decimal(root.report.humidity) + "%" : "—" },
                  { key: "wind", value: root.report?.wind != null ? root.decimal(root.report.wind) + " km/h" : "—" }
                ]
                delegate: Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  Layout.preferredWidth: 1
                  implicitHeight: metric.implicitHeight + root.s(16)
                  radius: root.s(14)
                  color: root.surface
                  ColumnLayout {
                    id: metric
                    anchors { fill: parent; margins: root.s(8) }
                    spacing: root.s(4)
                    Label { Layout.fillWidth: true; text: strings.t(modelData.key); color: root.softInk; font.pixelSize: Commons.Style.font.caption }
                    Label { Layout.fillWidth: true; text: modelData.value; font.bold: true }
                  }
                }
              }
            }
            RowLayout {
              visible: !!root.report
              Layout.fillWidth: true
              spacing: root.s(4)
              Repeater {
                model: ["hourly", "daily", "details"]
                delegate: Action {
                  required property string modelData
                  text: strings.t(modelData)
                  selected: root.forecastView === modelData
                  Layout.fillWidth: true
                  Layout.preferredWidth: 1
                  onClicked: root.forecastView = modelData
                }
              }
            }
            OmaGroup {
              visible: !!root.report && root.forecastView === "hourly"
              Layout.fillWidth: true
              title: strings.t("nextHours")
              Repeater {
                model: root.hours.slice(root.hourPage * root.hoursPerPage, (root.hourPage + 1) * root.hoursPerPage)
                delegate: ForecastRow {
                  required property var modelData
                  period: modelData.time.slice(0, 10) === root.report?.time.slice(0, 10)
                    ? modelData.time.slice(11)
                    : strings.t("weekdayTime").arg(root.weekday(modelData.time.slice(0, 10))).arg(modelData.time.slice(11))
                  code: modelData.code
                  night: modelData.night
                  chance: modelData.rain
                  temperature: modelData.temperature
                }
              }
              RowLayout {
                visible: root.lastHourPage > 0
                Layout.fillWidth: true
                Action {
                  tooltipText: strings.t("previousHours")
                  iconText: Commons.I18n.rightToLeft ? "󰅂" : "󰅁"
                  enabled: root.hourPage > 0
                  onClicked: root.hourPage--
                }
                Label {
                  Layout.fillWidth: true
                  horizontalAlignment: Text.AlignHCenter
                  text: strings.t("hourPage").arg(root.decimal(root.hourPage + 1)).arg(root.decimal(root.lastHourPage + 1))
                  color: root.softInk
                  font.pixelSize: Commons.Style.font.caption
                }
                Action {
                  tooltipText: strings.t("followingHours")
                  iconText: Commons.I18n.rightToLeft ? "󰅁" : "󰅂"
                  enabled: root.hourPage < root.lastHourPage
                  onClicked: root.hourPage++
                }
              }
              Label {
                visible: !root.hours.length
                Layout.fillWidth: true
                text: strings.t("unknown")
                color: root.softInk
              }
            }
            OmaGroup {
              title: strings.t("outlook")
              visible: !!root.report && root.forecastView === "daily"
              Layout.fillWidth: true
              Repeater {
                model: root.report?.days ?? []
                delegate: ForecastRow {
                  required property var modelData
                  required property int index
                  period: index === 0 ? strings.t("today") : root.weekday(modelData.date)
                  code: modelData.code
                  chance: modelData.rain
                  minimum: modelData.low
                  temperature: modelData.high
                  showRange: true
                }
              }
            }
            OmaGroup {
              title: strings.t("localConditions")
              visible: !!root.report && root.forecastView === "details"
              Layout.fillWidth: true
              Repeater {
                model: root.report ? [
                  { key: "gusts", value: root.unit(root.report.gusts, " km/h") },
                  { key: "pressure", value: root.unit(root.report.pressure, " hPa") },
                  { key: "clouds", value: root.unit(root.report.clouds, "%") },
                  { key: "visibility", value: root.unit(root.report.visibility == null ? null : root.report.visibility / 1000, " km", 1) },
                  { key: "uv", value: root.unit(root.report.uv, "", 1) },
                  { key: "rainTotal", value: root.unit(root.report.rainTotal, " mm", 1) },
                  { key: "sunrise", value: root.report.sunrise ?? "—" },
                  { key: "sunset", value: root.report.sunset ?? "—" }
                ] : []
                delegate: RowLayout {
                  required property var modelData
                  Layout.fillWidth: true
                  Label { Layout.fillWidth: true; text: strings.t(modelData.key); color: root.softInk }
                  Label { text: modelData.value; font.bold: true }
                }
              }
            }
            Label {
              Layout.fillWidth: true
              visible: root.failed || !!root.report
              text: root.report ? strings.t(root.failed ? "stale" : "updated").arg(root.report.time.replace("T", " "))
                                : strings.t("failed")
              color: root.failed ? Commons.Color.urgent : root.softInk
              wrapMode: Text.WordWrap
              font.pixelSize: Commons.Style.font.caption
            }
            Label {
              Layout.fillWidth: true
              text: strings.t("source")
              color: root.softInk
              font.pixelSize: Commons.Style.font.caption
              Accessible.role: Accessible.Link
              Accessible.onPressAction: Qt.openUrlExternally("https://open-meteo.com/")
              TapHandler { onTapped: Qt.openUrlExternally("https://open-meteo.com/") }
            }
          }
        }
      }

      settingsPane: ColumnLayout {
        id: settingsColumn
        anchors.fill: parent
        spacing: Commons.Style.spacing.panelGap
        RowLayout {
          Layout.fillWidth: true
          Label {
            Layout.fillWidth: true
            text: strings.t("oma.settings")
            font.bold: true
            font.pixelSize: Commons.Style.font.title
          }
          OmaSettingsButton {
            id: closeSettingsButton
            catalog: strings
            closing: true
            onClicked: page.showSettings(false)
          }
        }
        Controls.ScrollView {
          id: settingsScroll
          Layout.fillHeight: true
          Layout.fillWidth: true
          Layout.preferredHeight: settingsBody.implicitHeight
          contentWidth: availableWidth
          clip: true
          ColumnLayout {
            id: settingsBody
            width: settingsScroll.availableWidth
            spacing: root.s(8)
            OmaGroup {
              Layout.fillWidth: true
              title: strings.t("oma.appearance")
              OmaAppearance {
                Layout.fillWidth: true
                frame: popup
                catalog: strings
              }
            }
            OmaGroup {
              Layout.fillWidth: true
              title: strings.t("location")
              RowLayout {
                Layout.fillWidth: true
                Controls.TextField {
                  id: city
                  Layout.fillWidth: true
                  Layout.preferredHeight: root.s(34)
                  placeholderText: strings.t("city")
                  Accessible.name: strings.t("city")
                  placeholderTextColor: root.softInk
                  color: root.ink
                  selectionColor: root.accent
                  selectedTextColor: root.accentInk
                  font.family: Commons.Style.font.family
                  font.pixelSize: Commons.Style.font.body
                  enabled: !lookup.running
                  maximumLength: 80
                  leftPadding: root.s(10)
                  background: Rectangle {
                    radius: height / 2
                    color: root.surface
                    border.width: 1
                    border.color: city.activeFocus ? root.accent : Qt.alpha(root.ink, 0.15)
                  }
                  onAccepted: root.search(text)
                }
                Action {
                  tooltipText: strings.t("search")
                  iconText: "󰍉"
                  enabled: !lookup.running && city.text.trim().length >= 2
                  onClicked: root.search(city.text)
                }
              }
              Label {
                Layout.fillWidth: true
                visible: lookup.running || !!root.searchStatus
                text: lookup.running ? strings.t("loading") : root.searchStatus ? strings.t(root.searchStatus) : ""
                wrapMode: Text.WordWrap
                color: root.softInk
              }
              Repeater {
                model: root.results
                delegate: Action {
                  required property var modelData
                  Layout.fillWidth: true
                  Layout.preferredWidth: 1
                  text: modelData.name + (modelData.region ? " · " + modelData.region : "")
                  onClicked: {
                    if (root.save("place", modelData)) {
                      root.results = []
                      city.clear()
                    }
                  }
                }
              }
            }
            OmaGroup {
              Layout.fillWidth: true
              title: strings.t("updates")
              Toggle {
                Layout.fillWidth: true
                text: strings.t("automatic")
                checked: root.automatic
                onClicked: if (!root.save("automatic", checked)) checked = Qt.binding(() => root.automatic)
              }
              Toggle {
                Layout.fillWidth: true
                text: strings.t("enableForecastNotices")
                checked: root.forecastAlerts
                onClicked: if (!root.save("forecastAlerts", checked)) checked = Qt.binding(() => root.forecastAlerts)
              }
              Label {
                visible: root.forecastAlerts
                Layout.fillWidth: true
                text: strings.t("forecastNoticeNote")
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                color: root.softInk
              }
              Label { Layout.fillWidth: true; text: strings.t(root.automatic ? "interval" : "manual"); color: root.softInk }
              RowLayout {
                visible: root.automatic
                Layout.fillWidth: true
                spacing: root.s(4)
                Repeater {
                  model: root.intervals
                  delegate: Action {
                    required property int modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    selected: root.minutes === modelData
                    text: strings.t("minutes").arg(root.decimal(modelData))
                    onClicked: root.save("minutes", modelData)
                  }
                }
              }
            }
            Label {
              visible: root.saveFailed
              Layout.fillWidth: true
              text: strings.t("saveFailed")
              wrapMode: Text.WordWrap
              color: Commons.Color.urgent
            }
          }
        }
      }
    }
  }
}

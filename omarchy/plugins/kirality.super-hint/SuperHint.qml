import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property var categories: []
  property var heldMods: []
  property var lastAction: null

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md

  // Columns get a fixed, generous width instead of an even division of a
  // fixed card width -- dividing evenly crushed labels unreadable (e.g.
  // "Theme menu" -> "Th…") whenever a row's own modifier-key prefix (like
  // SHIFT + CTRL +) ate most of a narrow column's space. The card's size is
  // derived from however many columns/rows are actually needed instead.
  property int columnWidth: Style.space(230)
  property int columnCount: Math.max(1, root.categories.length)
  property int maxRows: {
    var m = 1
    for (var i = 0; i < root.categories.length; i++) {
      var items = (root.categories[i] && root.categories[i].items) || []
      m = Math.max(m, items.length)
    }
    return m
  }
  property int cardWidth: Math.min(
    contentMargin * 2 + columnCount * columnWidth + contentSpacing * 2 * Math.max(0, columnCount - 1),
    panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(
    contentMargin * 2 + Style.space(96) + maxRows * Style.space(30) + Style.space(56)
      + (root.lastAction ? Style.space(root.lastAction.detail ? 52 : 34) : 0),
    panel.height - Style.gapsOut * 2)

  function open(payloadJson) {
    root.opened = true
    root.categories = root.parsePayload(payloadJson)
    try {
      var data = JSON.parse(payloadJson || "{}")
      root.heldMods = data.heldMods || []
      root.lastAction = data.lastAction || null
      if (root.lastAction) {
        var tokens = []
        var mods = root.lastAction.mods || []
        for (var m = 0; m < mods.length; m++) { tokens.push(mods[m]); tokens.push("+") }
        tokens.push(root.lastAction.key)
        root.lastAction.tokens = tokens
      }
    } catch (e) {
      root.heldMods = []
      root.lastAction = null
    }
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "kirality.super-hint")
  }

  // Flattens each row's {mods, key} into a display token list, e.g.
  // ["SHIFT", "+", "B"], so the delegate tree never branches on shape.
  function parsePayload(payloadJson) {
    try {
      var data = JSON.parse(payloadJson || "{}")
      var cats = data.categories || []
      for (var i = 0; i < cats.length; i++) {
        var items = cats[i].items || []
        for (var j = 0; j < items.length; j++) {
          var it = items[j]
          var tokens = []
          var mods = it.mods || []
          for (var m = 0; m < mods.length; m++) { tokens.push(mods[m]); tokens.push("+") }
          tokens.push(it.key)
          it.tokens = tokens
        }
      }
      return cats
    } catch (e) {
      return []
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-super-hint"
    WlrLayershell.layer: WlrLayer.Overlay
    // Purely informational HUD: it must never grab keyboard input, or the
    // first key of any Super+key chord gets swallowed by this surface
    // before Hyprland's own bind dispatch sees it (confirmed live: with
    // Exclusive focus, Super+arrow needed pressing twice to register).
    // Escape-to-dismiss is handled by the Lua-side show/hide logic instead
    // (any non-Super key while Super is held hides this overlay).
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Visual-only surface, same as Osd.qml: keep the layer-shell input
    // region empty so it never affects focus/input routing for whatever is
    // beneath it (confirmed live: without this, Super+arrow moved Hyprland's
    // active-window indicator but real keyboard focus did not follow).
    mask: Region {}

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        // Held-key indicator: live readout of Super plus whatever other
        // modifiers are currently also held (see heldMods), updated on
        // every re-summon as modifier state changes.
        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(6)

            Repeater {
              model: ["SUPER"].concat(root.heldMods)

              delegate: Row {
                id: heldRoot
                required property string modelData
                required property int index
                spacing: Style.space(6)

                Text {
                  visible: heldRoot.index > 0
                  anchors.verticalCenter: parent.verticalCenter
                  text: "+"
                  color: Color.accent
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Rectangle {
                  width: Math.max(Style.space(64), heldText.implicitWidth + Style.space(24))
                  height: Style.space(34)
                  radius: Style.space(9)
                  color: Util.alpha(Color.accent, 0.18)
                  border.color: Color.accent
                  border.width: 1

                  Text {
                    id: heldText
                    anchors.centerIn: parent
                    text: heldRoot.modelData
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "held down"
            color: root.foreground
            opacity: 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // Category grid
        Row {
          id: categoriesRow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: root.contentSpacing * 2

          Repeater {
            model: root.categories

            delegate: Column {
              id: catCol
              required property var modelData
              width: root.columnWidth
              spacing: Style.space(10)

              Text {
                text: catCol.modelData.name.toUpperCase()
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }

              Repeater {
                model: catCol.modelData.items

                delegate: Row {
                  id: rowRoot
                  required property var modelData
                  width: catCol.width
                  spacing: Style.space(6)

                  Row {
                    id: tokensRow
                    spacing: Style.space(6)

                  Repeater {
                    model: rowRoot.modelData.tokens

                    delegate: Item {
                      id: tokenRoot
                      required property string modelData
                      readonly property bool isPlus: tokenRoot.modelData === "+"
                      width: isPlus ? Style.space(10) : keycapText.implicitWidth + Style.space(14)
                      height: Style.space(20)

                      Rectangle {
                        anchors.fill: parent
                        visible: !tokenRoot.isPlus
                        radius: Style.space(5)
                        color: Util.alpha(root.foreground, 0.06)
                        border.width: 1
                        border.color: rowRoot.modelData.highlight ? Color.accent : root.border
                      }

                      Text {
                        id: keycapText
                        anchors.centerIn: parent
                        text: tokenRoot.modelData
                        color: rowRoot.modelData.highlight ? Color.accent : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: !tokenRoot.isPlus
                        opacity: tokenRoot.isPlus ? 0.45 : 1
                      }
                    }
                  }
                  }

                  Text {
                    width: Math.max(0, rowRoot.width - tokensRow.width - rowRoot.spacing)
                    elide: Text.ElideRight
                    text: rowRoot.modelData.label
                    color: rowRoot.modelData.highlight ? Color.accent : root.foreground
                    opacity: rowRoot.modelData.highlight ? 1 : 0.85
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }
              }
            }
          }
        }

        // Last action: what you last actually ran, shown the NEXT time the
        // hint reopens (this is an observed keycode resolved back to a
        // live description, not something we intercepted or re-executed).
        // Curated commands carry a hand-written one-line detail; anything
        // else falls back to just the system's own bind description with
        // no second line.
        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(4)
          visible: root.lastAction !== null

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "last:"
              color: root.foreground
              opacity: 0.45
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              id: lastActionTokens
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              Repeater {
                model: root.lastAction ? root.lastAction.tokens : []

                delegate: Item {
                  id: lastTokenRoot
                  required property string modelData
                  readonly property bool isPlus: lastTokenRoot.modelData === "+"
                  width: isPlus ? Style.space(8) : lastTokenText.implicitWidth + Style.space(10)
                  height: Style.space(18)

                  Rectangle {
                    anchors.fill: parent
                    visible: !lastTokenRoot.isPlus
                    radius: Style.space(4)
                    color: Util.alpha(root.foreground, 0.06)
                    border.width: 1
                    border.color: root.border
                  }

                  Text {
                    id: lastTokenText
                    anchors.centerIn: parent
                    text: lastTokenRoot.modelData
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: !lastTokenRoot.isPlus
                    opacity: lastTokenRoot.isPlus ? 0.45 : 0.85
                  }
                }
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.lastAction ? root.lastAction.label : ""
              color: root.foreground
              opacity: 0.85
              font.bold: true
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !!(root.lastAction && root.lastAction.detail)
            text: root.lastAction ? root.lastAction.detail : ""
            color: root.foreground
            opacity: 0.55
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // Footer hint
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "release SUPER to dismiss"
          color: root.foreground
          opacity: 0.45
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}

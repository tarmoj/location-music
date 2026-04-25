import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import QtWebSockets

ApplicationWindow {
   id: app
   width: 800
   height: 600
   visible: true
   property string version: "0.3.0"
   title: qsTr("Meeblue Server " + version)
   Settings {
      id: settings
      property string oscHost: "127.0.0.1"
      property int oscPort: 8000
   }

   header: ToolBar {
      id: toolBar
      width: parent.width
      // height: titleLabel.height + 20

      implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding

      background: Rectangle {color: "transparent" }

      topPadding: parent.SafeArea ? parent.SafeArea.margins.top : 10
      bottomPadding: 10

      contentItem:  Item {
         //anchors.fill: parent
         anchors.topMargin: 10
         implicitHeight: titleLabel.implicitHeight + 10


         Label {
            id: titleLabel
            anchors.centerIn: parent
            //anchors.verticalCenter: parent.verticalCenter
            text: app.title
            font.pointSize: 16
            font.bold: true
            horizontalAlignment: Qt.AlignHCenter

         }

         ToolButton {
            id: menuButton

            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            icon.source: "qrc:/images/menu.svg"
            onClicked: drawer.opened ? drawer.close() : drawer.open()
         }
      }
   }


   Drawer {
      id: drawer
      //width is automatic
      height: app.height - toolBar.height
      y: toolBar.height
      property int marginLeft: 20

      background: Rectangle {anchors.fill:parent; color: Material.backgroundColor.lighter()}


      ColumnLayout {
         anchors.fill: parent
         spacing: 5
         visible: true


         MenuItem {
            text: qsTr("Info")
            icon.source: "qrc:/images/info.svg"
            onTriggered: {
               drawer.close()
               helpDialog.open()
            }
         }


         Item {Layout.fillHeight: true}

      }

   }

   MessageDialog {
      id: helpDialog
      buttons: MessageDialog.Ok

      text: qsTr(`
                 MeeBlue Server

                 More info comes here.
                 Built using Qt framework.

                 (c) Tarmo Johannes trmjhnns@gmail.com`)

      onButtonClicked: function (button, role) { // does not close on Android otherwise
         switch (button) {
         case MessageDialog.Ok:
            helpDialog.close()
         }
      }
   }

   readonly property real minRssi: -80
   readonly property real maxRssi: -40

   // Keyed as previousMeans[stationId] = normalised 0..1 value
   property var previousMeans: ({})

   // Plain JS map for programmatic access: usersData[userId] = stations array
   property var usersData: ({})

   property bool manualMode: false

   // One entry per userId: {userId, userName, strongestStation, stations: [...]}
   ListModel {
      id: usersModel
   }

   // One entry per station for meter display: {stationId: string, value: real 0..1}
   ListModel {
      id: stationMetersModel
   }

   function processMessage(message) {
      var data
      try {
         data = JSON.parse(message)
      } catch (e) {
         console.warn("Failed to parse message:", e)
         return
      }

      var userId = data.userId
      var userName = data.userName
      var strongestStation = data.strongestStation
      var stations = data.stations  // JS array from JSON

      // Find existing entry for this userId
      var existingIndex = -1
      for (var i = 0; i < usersModel.count; i++) {
         if (usersModel.get(i).userId === userId) {
            existingIndex = i
            break
         }
      }

      var entry = {
         userId: userId,
         userName: userName,
         strongestStation: strongestStation,
         stations: stations
      }

      if (existingIndex === -1) {
         usersModel.append(entry)
      } else {
         // remove + insert at same index: forces Repeater to recreate with fresh var role data
         usersModel.remove(existingIndex)
         usersModel.insert(existingIndex, entry)
      }

      usersData[userId] = stations
   }

   function stationMeterIndex(stationId) {
      for (var i = 0; i < stationMetersModel.count; i++) {
         if (stationMetersModel.get(i).stationId === stationId) return i
      }
      return -1
   }

   function sendStationMeans() {
      if (!manualMode) {
         var stationSums = {}
         var stationCounts = {}

         for (var userId in usersData) {
            var stns = usersData[userId]
            for (var j = 0; j < stns.length; j++) {
               var s = stns[j]
               if (stationSums[s.stationId] === undefined) {
                  stationSums[s.stationId] = 0
                  stationCounts[s.stationId] = 0
               }
               stationSums[s.stationId] += s.rssi
               stationCounts[s.stationId]++
            }
         }

         for (var stationId in stationSums) {
            var meanRssi = stationSums[stationId] / stationCounts[stationId]
            var normalised = Math.max(0.0, Math.min(1.0, (meanRssi - minRssi) / (maxRssi - minRssi)))
            normalised = Math.round(normalised * 1000) / 1000
            var idx = stationMeterIndex(stationId)
            if (idx === -1)
               stationMetersModel.append({stationId: stationId, value: normalised})
            else
               stationMetersModel.setProperty(idx, "value", normalised)
            if (previousMeans[stationId] !== normalised) {
               console.log("Station", stationId, "mean RSSI:", meanRssi.toFixed(1), "normalised:", normalised)
               oscClient.sendMessage("/vcs/station" + stationId, [normalised])
               previousMeans[stationId] = normalised
            }
         }
      } else {
         // manual mode: send directly from meter values
         for (var m = 0; m < stationMetersModel.count; m++) {
            var entry = stationMetersModel.get(m)
            var val = Math.round(entry.value * 1000) / 1000
            if (previousMeans[entry.stationId] !== val) {
               oscClient.sendMessage("/vcs/station" + entry.stationId, [val])
               previousMeans[entry.stationId] = val
            }
         }
      }
   }

   readonly property var defaultStationIds: ["1", "2", "3"]

   function ensureDefaultMeters() {
      for (var k = 0; k < defaultStationIds.length; k++) {
         if (stationMeterIndex(defaultStationIds[k]) === -1)
            stationMetersModel.append({stationId: defaultStationIds[k], value: 0.0})
      }
   }

   onManualModeChanged: {
      if (manualMode) ensureDefaultMeters()
   }

   Component.onCompleted: {
      console.log("Server started and listening")
      if (manualMode) ensureDefaultMeters()
   }

   Timer {
      interval: 500
      repeat: true
      running: true // ;usersModel.count > 0
      onTriggered: sendStationMeans()
   }

   OscClient {
      id: oscClient
      host: settings.oscHost
      port: settings.oscPort
   }

   WebSocketServer {
      id: server
      listen: true
      port: 6789
      host: "0.0.0.0"

      onClientConnected: function(webSocket) {
         console.log("Client connected:", webSocket)
         webSocket.onTextMessageReceived.connect(function(message) {
            processMessage(message)
         })
      }
      onErrorStringChanged: function(errorString) {
         console.log(qsTr("Server error: %1").arg(errorString));
      }
   }



   SwipeView {
      id: swipeView
      anchors.fill: parent

      Page {
         padding: 8

         background: Rectangle {
            gradient: Gradient {
               GradientStop { position: 0.0; color: Material.backgroundColor }
               GradientStop { position: 0.6; color: Material.backgroundColor }
               GradientStop { position: 0.8; color: "#1a4d1a" }
               GradientStop { position: 1.0; color: "#0a2e0a" }
            }
         }

         ColumnLayout {
            anchors.fill: parent
            spacing: 10

            RowLayout {
               spacing: 10
               Label { text: qsTr("Station info")}
               ToolButton { text:qsTr("Clear"); onClicked: usersModel.clear()   }
            }

            ListView {
               Layout.fillWidth: true
               Layout.fillHeight: true
               model: usersModel
               spacing: 4
               clip: true

               delegate: Rectangle {
                  width: ListView.view.width
                  height: rowFlow.implicitHeight + 8
                  color: index % 2 === 0 ? Material.background : Qt.rgba(
                                              Material.foreground.r,
                                              Material.foreground.g,
                                              Material.foreground.b, 0.05)
                  radius: 4

                  Flow {
                     id: rowFlow
                     anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 8
                        rightMargin: 8
                     }
                     spacing: 10

                     Label {
                        text: model.userId
                        font.bold: true
                        font.pointSize: 11
                     }

                     Label {
                        text: model.userName
                        font.pointSize: 11
                        color: Material.accent
                     }

                     Repeater {
                        model: stations   // JS array from ListModel var role

                        Label {
                           required property var modelData
                           text: modelData.stationId + ": " + modelData.rssi
                           font.pointSize: 11
                           font.bold: modelData.stationId === strongestStation
                           color: modelData.stationId === strongestStation
                                  ? Material.accent : Material.foreground
                        }
                     }
                  }
               }
            }

            Flow {
               Layout.fillWidth: true
               spacing: 12

               Repeater {
                  model: stationMetersModel

                  delegate: Column {
                     spacing: 4

                     Rectangle {
                        id: meterBar
                        width: 44
                        height: 160
                        color: Qt.rgba(1, 1, 1, 0.08)
                        radius: 4
                        clip: true

                        Rectangle {
                           width: parent.width
                           height: model.value * parent.height
                           anchors.bottom: parent.bottom
                           radius: 4
                           color: model.value > 0.66 ? "#44cc44"
                                : model.value > 0.33 ? "#ccaa00" : "#cc4444"
                        }

                        Repeater {
                           model: [0.25, 0.5, 0.75]
                           Rectangle {
                              required property var modelData
                              x: 0; width: parent.width
                              y: (1.0 - modelData) * meterBar.height - 1
                              height: 1
                              color: Qt.rgba(1, 1, 1, 0.25)
                           }
                        }

                        MouseArea {
                           anchors.fill: parent
                           enabled: manualMode
                           cursorShape: manualMode ? Qt.SizeVerCursor : Qt.ArrowCursor
                           onPressed:         setVal(mouseY)
                           onPositionChanged: if (pressed) setVal(mouseY)
                           function setVal(y) {
                              var v = 1.0 - y / meterBar.height
                              stationMetersModel.setProperty(
                                 index, "value", Math.max(0.0, Math.min(1.0, v)))
                           }
                        }
                     }

                     Label {
                        text: model.stationId
                        width: 44
                        horizontalAlignment: Text.AlignHCenter
                        font.pointSize: 9
                     }

                     Label {
                        text: model.value.toFixed(2)
                        width: 44
                        horizontalAlignment: Text.AlignHCenter
                        font.pointSize: 9
                        color: Material.accent
                     }
                  }
               }
            }
            CheckBox {
               text: qsTr("Manual")
               checked: manualMode
               onCheckedChanged: manualMode = checked
            }

            Item {Layout.fillHeight: true}

         }
      }

      Page {

         padding: 8

         background: Rectangle {
            gradient: Gradient {
               GradientStop { position: 0.0; color: Material.backgroundColor }
               GradientStop { position: 0.6; color: Material.backgroundColor }
               GradientStop { position: 0.8; color: "#1a4d1a" }
               GradientStop { position: 1.0; color: "#0a2e0a" }
            }
         }

         ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Label {
               text: qsTr("Settings")
               font.pointSize: 18
               font.bold: true
            }


            Flow {
                id: serverRow
                Layout.fillWidth: true
                spacing: 5

                Label {
                    height: serverIPTextField.height
                    text: qsTr("OSC server IP:")
                    verticalAlignment: Text.AlignVCenter
                }
                TextField {
                    id: serverIPTextField
                    width: 165
                    text: settings.oscHost
                }

                Label {
                    height: serverPortSpinBox.height
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("Port:")
                }
                SpinBox {
                    id: serverPortSpinBox
                    width: 80
                    up.indicator:   Item { width: 0 }
                    down.indicator: Item { width: 0 }
                    from: 1024
                    to: 65535
                    editable: true
                    value: settings.oscPort
                }

                Button {
                    id: updateButton
                    text: qsTr("Update")
                    onClicked: {
                        settings.oscHost = serverIPTextField.text
                        settings.oscPort = serverPortSpinBox.value
                    }
                }
            }


            Item {Layout.fillHeight: true }
         }


      }
   }
}

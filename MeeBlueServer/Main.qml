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
   property string version: "0.2.1"
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

   // One entry per userId: {userId, userName, strongestStation, stations: [...]}
   ListModel {
      id: usersModel
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

   function proximityWeight(proximity) {
      switch (proximity) {
         case "immediate": return 4
         case "near":      return 3
         case "far":       return 2
         default:          return 1
      }
   }

   function sendStationMeans() {
      var stationSums = {}
      var stationWeights = {}

      for (var userId in usersData) {
         var stns = usersData[userId]
         for (var j = 0; j < stns.length; j++) {
            var s = stns[j]
            var w = proximityWeight(s.proximity)
            if (stationSums[s.stationId] === undefined) {
               stationSums[s.stationId] = 0
               stationWeights[s.stationId] = 0
            }
            stationSums[s.stationId] += s.rssi * w
            stationWeights[s.stationId] += w
         }
      }

      for (var stationId in stationSums) {
         var meanRssi = stationSums[stationId] / stationWeights[stationId]
         var normalised = Math.max(0.0, Math.min(1.0, (meanRssi - minRssi) / (maxRssi - minRssi)))
         normalised = Math.round(normalised * 1000) / 1000  // 3 decimal places
         if (previousMeans[stationId] !== normalised) {
            console.log("Station", stationId, "mean RSSI:", meanRssi.toFixed(1), "normalised:", normalised) 
            oscClient.sendMessage("/vcs/station" + stationId, [normalised])
            previousMeans[stationId] = normalised
         }
      }
   }

   Component.onCompleted: {
      console.log("Server started and listening")
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
                           text: modelData.stationId + ": " + modelData.rssi + " " + modelData.proximity
                           font.pointSize: 11
                           font.bold: modelData.stationId === strongestStation
                           color: modelData.stationId === strongestStation
                                  ? Material.accent : Material.foreground
                        }
                     }
                  }
               }
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

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
   title: qsTr("Meeblue Server")
   color: Material.background

   Settings {

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

   // Per-user data: keyed as previousStations[userId][stationId] = {rssi, proximity}
   property var previousStations: ({})

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

      if (existingIndex === -1) {
         usersModel.append({
            userId: userId,
            userName: userName,
            strongestStation: strongestStation,
            stations: stations
         })
      } else {
         usersModel.set(existingIndex, {
            userId: userId,
            userName: userName,
            strongestStation: strongestStation,
            stations: stations
         })
         // Workaround: explicitly reassign var role to trigger delegate refresh
         usersModel.setProperty(existingIndex, "stations", stations)
      }

      // Change detection — OSC hook-in point
      var prevUser = previousStations[userId] || {}
      for (var j = 0; j < stations.length; j++) {
         var s = stations[j]
         var prev = prevUser[s.stationId] || {}
         if (prev.rssi !== undefined && prev.rssi !== s.rssi) {
            console.log("CHANGED rssi user", userId, "station", s.stationId,
                        prev.rssi, "->", s.rssi)
            // TODO: send OSC message here (userId, stationId, "rssi", s.rssi)
         }
         if (prev.proximity !== undefined && prev.proximity !== s.proximity) {
            console.log("CHANGED proximity user", userId, "station", s.stationId,
                        prev.proximity, "->", s.proximity)
            // TODO: send OSC message here (userId, stationId, "proximity", s.proximity)
         }
         prevUser[s.stationId] = {rssi: s.rssi, proximity: s.proximity}
      }
      previousStations[userId] = prevUser
   }

   Component.onCompleted: {
      console.log("Server started and listening")
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
      onErrorStringChanged: {
         console.log(qsTr("Server error: %1").arg(errorString));
      }
   }



   SwipeView {
      id: swipeView
      anchors.fill: parent

      Page {
         padding: 8

         ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Label { text: qsTr("Station info")}

            ListView {
               Layout.fillWidth: true
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
         Label {
            anchors.centerIn: parent
            text: qsTr("Secondary View")
            font.pointSize: 18
            font.bold: true
         }
      }
   }
}

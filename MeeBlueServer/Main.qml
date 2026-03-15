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

   WebSocketServer {
      id: server
      listen: true
      port: 6789
      host: "0.0.0.0"

      onClientConnected: function(webSocket) {
         webSocket.onTextMessageReceived.connect(function(message) {
            console.log(qsTr("Server received message: %1").arg(message));
            webSocket.sendTextMessage(qsTr("Hello Client!"));
         });
      }
      onErrorStringChanged: {
         console.log(qsTr("Server error: %1").arg(errorString));
      }
   }



   SwipeView {
      id: swipeView
      anchors.fill: parent

      Page {

         Label {
            anchors.centerIn: parent
            text: qsTr("Main View")
            font.pointSize: 18
            font.bold: true
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

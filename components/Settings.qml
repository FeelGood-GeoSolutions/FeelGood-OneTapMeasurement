import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: settingsDialog
    property var settings: null
    property var mainWindow: null

    visible: false
    modal: true
    width: 400
    //height: 300
    title: qsTr("Feelgood OneTap Settings")
    standardButtons: Dialog.Ok | Dialog.Cancel

    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) / 2

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        Text {
            text: qsTr("Configure your Feelgood OneTap settings here.")
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Switch {
            id: autoImageSwitch
            text: qsTr("Automatically capture image")
            checked: settingsDialog.settings.autoImage
            onCheckedChanged: settingsDialog.settings.autoImage = checked
            Layout.fillWidth: true
        }

        Switch {
            id: imuConfirmationSwitch
            text: qsTr("Require IMU confirmation")
            checked: settingsDialog.settings.requireConfirmationOnImuMissing
            onCheckedChanged: settingsDialog.settings.requireConfirmationOnImuMissing = checked
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: qsTr("Picture field name:")
                Layout.alignment: Qt.AlignVCenter
            }

            TextField {
                id: pictureFieldInput
                text: settingsDialog.settings.pictureFieldName
                onTextChanged: settingsDialog.settings.pictureFieldName = text
                Layout.fillWidth: true
                placeholderText: qsTr("Enter field name")
            }
        }

        Switch {
            id: audioFeedbackSwitch
            text: qsTr("Enable audio feedback")
            checked: settingsDialog.settings.enableAudioFeedback
            onCheckedChanged: settingsDialog.settings.enableAudioFeedback = checked
            Layout.fillWidth: true
        }

        Item {
            Layout.fillHeight: true
        }
    }
}

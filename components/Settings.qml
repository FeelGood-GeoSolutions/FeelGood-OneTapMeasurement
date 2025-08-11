import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: settingsDialog
    property var settings: null
    property var mainWindow: null

    visible: false
    modal: true
    // Constrain size to fit smaller screens
    width: Math.min(400, mainWindow ? (mainWindow.width - 20) : 400)
    height: Math.min(implicitHeight, mainWindow ? (mainWindow.height - 20) : implicitHeight)
    title: qsTr("FeelGood OneTapMeasurement Plugin Settings")
    standardButtons: Dialog.Ok | Dialog.Cancel

    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) / 2

    // Make content scrollable so it never exceeds the screen height
    ScrollView {
        id: scroller
        anchors.fill: parent
        padding: 10
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: scroller.availableWidth
            spacing: 15

            Switch {
                id: autoImageSwitch
                text: qsTr("Automatically capture image")
                checked: settingsDialog.settings.autoImage
                onCheckedChanged: settingsDialog.settings.autoImage = checked
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: settingsDialog.settings.autoImage

                Label {
                    text: qsTr("Picture field name")
                    Layout.alignment: Qt.AlignVCenter
                }

                TextField {
                    id: pictureFieldInput
                    text: settingsDialog.settings.pictureFieldName
                    onTextChanged: settingsDialog.settings.pictureFieldName = text
                    Layout.fillWidth: true
                    Layout.maximumWidth: 270
                    // Avoid slight overflow under vertical scrollbar
                    Layout.rightMargin: 6
                    placeholderText: qsTr("Enter field name...")
                }
            }

            Switch {
                id: imuConfirmationSwitch
                text: qsTr("Require confirmation if IMU is not active")
                checked: settingsDialog.settings.requireConfirmationOnImuMissing
                onCheckedChanged: settingsDialog.settings.requireConfirmationOnImuMissing = checked
                Layout.fillWidth: true
            }

            Switch {
                id: audioFeedbackSwitch
                text: qsTr("Enable audio feedback")
                checked: settingsDialog.settings.enableAudioFeedback
                onCheckedChanged: settingsDialog.settings.enableAudioFeedback = checked
                Layout.fillWidth: true
            }
        }
    }
}

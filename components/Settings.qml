import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: settingsDialog
    
    property var settings: null
    property var parentWindow: null
    
    signal settingsAccepted()
    
    visible: false
    modal: true
    width: 450
    height: 400
    title: qsTr("Feelgood OneTap Settings")
    standardButtons: Dialog.Ok | Dialog.Cancel
    
    x: parentWindow ? (parentWindow.width - width) / 2 : 0
    y: parentWindow ? (parentWindow.height - height) / 2 : 0

    ScrollView {
        anchors.fill: parent
        
        Column {
            width: parent.width
            spacing: 20
            padding: 20

            Text {
                text: qsTr("Configure your Feelgood OneTap settings")
                font.pointSize: 14
                font.bold: true
                wrapMode: Text.Wrap
                width: parent.width
            }

            GroupBox {
                title: qsTr("Camera Settings")
                width: parent.width - 40
                
                Column {
                    width: parent.width
                    spacing: 15

                    CheckBox {
                        id: autoImageCheckbox
                        text: qsTr("Auto-capture image")
                        checked: settings ? settings.autoImage : false
                        
                        onCheckedChanged: {
                            if (settings) {
                                settings.autoImage = checked;
                            }
                        }
                    }

                    Text {
                        text: qsTr("When enabled, the camera will automatically capture a photo when creating a point.")
                        font.pointSize: 10
                        color: "#666"
                        wrapMode: Text.Wrap
                        width: parent.width
                    }

                    RowLayout {
                        width: parent.width
                        enabled: autoImageCheckbox.checked

                        Text {
                            text: qsTr("Picture field name:")
                            Layout.preferredWidth: 120
                        }

                        TextField {
                            id: pictureFieldTextField
                            text: settings ? settings.pictureFieldName : ""
                            placeholderText: qsTr("picture")
                            Layout.fillWidth: true
                            
                            onTextChanged: {
                                if (settings) {
                                    settings.pictureFieldName = text;
                                }
                            }
                        }
                    }

                    Text {
                        text: qsTr("The name of the field where the image path will be stored.")
                        font.pointSize: 10
                        color: "#666"
                        wrapMode: Text.Wrap
                        width: parent.width
                    }
                }
            }

            GroupBox {
                title: qsTr("Audio Settings")
                width: parent.width - 40
                
                Column {
                    width: parent.width
                    spacing: 15

                    CheckBox {
                        id: audioFeedbackCheckbox
                        text: qsTr("Enable audio feedback")
                        checked: settings ? settings.enableAudioFeedback : false
                        
                        onCheckedChanged: {
                            if (settings) {
                                settings.enableAudioFeedback = checked;
                            }
                        }
                    }

                    Text {
                        text: qsTr("Play a sound when a point is successfully created.")
                        font.pointSize: 10
                        color: "#666"
                        wrapMode: Text.Wrap
                        width: parent.width
                    }
                }
            }

            GroupBox {
                title: qsTr("Advanced Settings")
                width: parent.width - 40
                
                Column {
                    width: parent.width
                    spacing: 15

                    CheckBox {
                        id: confirmationCheckbox
                        text: qsTr("Require confirmation on IMU missing")
                        checked: settings ? settings.requireConfirmationOnImuMissing : false
                        
                        onCheckedChanged: {
                            if (settings) {
                                settings.requireConfirmationOnImuMissing = checked;
                            }
                        }
                    }

                    Text {
                        text: qsTr("Show confirmation dialog when IMU data is not available.")
                        font.pointSize: 10
                        color: "#666"
                        wrapMode: Text.Wrap
                        width: parent.width
                    }
                }
            }
        }
    }

    onAccepted: {
        settingsAccepted();
    }
    
    onRejected: {
        // Reload settings from stored values if user cancels
        loadSettingsFromStorage();
    }
    
    function loadSettingsFromStorage() {
        if (settings) {
            autoImageCheckbox.checked = settings.autoImage;
            pictureFieldTextField.text = settings.pictureFieldName;
            audioFeedbackCheckbox.checked = settings.enableAudioFeedback;
            confirmationCheckbox.checked = settings.requireConfirmationOnImuMissing;
        }
    }
    
    Component.onCompleted: {
        loadSettingsFromStorage();
    }
}
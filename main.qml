import QtQuick
import QtCore
import QtQuick.Controls
import QtQuick.Layouts

import QtMultimedia
import QtCore

import org.qfield
import org.qgis
import Theme

import "qrc:/qml" as QFieldItems

Item {
    id: plugin

    property var mainWindow: iface.mainWindow()
    property var positionSource: iface.findItemByObjectName('positionSource')
    property var dashBoard: iface.findItemByObjectName('dashBoard')
    property var overlayFeatureFormDrawer: iface.findItemByObjectName('overlayFeatureFormDrawer')
    property var projectInfo: iface.findItemByObjectName('projectInfo')

    property string mainIconSource: "icons/camera_icon.svg"
    property string pendingIconSource: "icons/pending_icon.svg"
    
    property var pendingFeatureData: null

    Settings {
        id: feelgoodOnetapSettings

        property bool autoImage: false
        property bool requireConfirmationOnImuMissing: true
        property string pictureFieldName: "picture"
        property bool enableAudioFeedback: true
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(oneTapButton);
        settingsDialog.parent = mainWindow.contentItem;
        loadSettings();
        return;
    }

    function configure() {
        settingsDialog.open();
    }

    Item {
        id: cameraItem

        property alias photoPath: imageCapture.lastSavedPath

        Camera {
            id: camera
            active: false

            onActiveChanged: {
                if (active) {
                    plugin.oneTap();
                } else {
                    oneTapButton.enable();
                }
            }
        }

        CaptureSession {
            id: captureSession
            camera: camera
            imageCapture: imageCapture
        }

        ImageCapture {
            id: imageCapture
            property string lastSavedPath: ""

            onImageSaved: (requestId, filePath) => {
                lastSavedPath = filePath;
                cameraItem.photoCaptured(filePath);
            }

            onErrorOccurred: (requestId, error, errorString) => {}

            onReadyForCaptureChanged: ready => {}
        }

        signal photoCaptured(string filePath)

        Component.onCompleted: {
            photoCaptured.connect(plugin.createFromPendingFeatureData);
        }

        function attemptCapture(path) {
            try {
                if (imageCapture.readyForCapture) {
                    imageCapture.captureToFile(path);
                } else {
                    Qt.callLater(function () {
                        if (imageCapture.readyForCapture) {
                            imageCapture.captureToFile(path);
                            return;
                        } else {
                            plugin.log("ImageCapture not ready, please try again.");
                        }
                    });
                }
            } catch (error) {
                plugin.log("Error capturing photo:" + error);
                oneTapButton.enable();
            }
            oneTapButton.enable();
            camera.active = false;
        }
    }

    SoundEffect {
        id: successSound
        source: "sounds/success.wav"

        function playSuccess() {
            play();
        }
    }

    QfToolButton {
        id: oneTapButton
        iconSource: plugin.mainIconSource
        iconColor: Theme.white
        bgcolor: Theme.darkGray
        round: true
        enabled: true

        onClicked: {
            if (!oneTapButton.enabled) {
                return;
            }
            disable();

            if (feelgoodOnetapSettings.autoImage) {
                camera.active = true;
                return;
            }
            plugin.oneTap();
            return;
        }

        onPressAndHold: {
            if (oneTapButton.enabled) {
                settingsDialog.open();
            }
            return;
        }

        function enable() {
            oneTapButton.iconSource = plugin.mainIconSource;
            oneTapButton.enabled = true;
        }

        function disable() {
            oneTapButton.iconSource = plugin.pendingIconSource;
            oneTapButton.enabled = false;
        }
    }

    Dialog {
        id: settingsDialog
        visible: false
        modal: true
        width: 400
        height: 300
        title: qsTr("Feelgood OneTap Settings")
        standardButtons: Dialog.Ok | Dialog.Cancel

        x: (plugin.mainWindow.width - width) / 2
        y: (plugin.mainWindow.height - height) / 2

        Column {
            anchors.fill: parent
            spacing: 10

            Text {
                text: qsTr("Configure your Feelgood OneTap settings here.")
                wrapMode: Text.Wrap
            }
        }

        onAccepted: {
            plugin.saveSettings();
            return;
        }
    }

    function oneTap() {
        dashBoard.ensureEditableLayerSelected();
        let layer = dashBoard.activeLayer;
        if (!positionSource.active || !positionSource.positionInformation.latitudeValid || !positionSource.positionInformation.longitudeValid) {
            mainWindow.displayToast(qsTr('Cannot generate point. Positioning is not active or does not return a valid position.'));
            oneTapButton.enable();
            return;
        }

        if (layer.geometryType() != Qgis.GeometryType.Point) {
            mainWindow.displayToast(qsTr('Cannot generate point. Active vector layer is not a point geometry.'));
            oneTapButton.enable();
            return;
        }
        let fieldNames = layer.fields.names;

        if (fieldNames.indexOf(feelgoodOnetapSettings.pictureFieldName) == -1 && feelgoodOnetapSettings.autoImage) {
            mainWindow.displayToast(qsTr('Cannot generate point. Active vector layer is missing a field named ${feelgoodOnetapSettings.pictureFieldName}. Please create it in the layer settings or adjust your plugin settings.'));
            return;
        }

        let pos = positionSource.sourcePosition;
        if (!pos || typeof pos.x !== "number" || typeof pos.y !== "number") {
            mainWindow.displayToast(qsTr('No valid GPS position data available.'));
            oneTapButton.enable();
            return;
        }
        let longitude = pos.x;
        let latitude = pos.y;

        let wgs84Crs = CoordinateReferenceSystemUtils.wgs84Crs();
        let layerCrs = layer.crs;
        if (!layerCrs || !layerCrs.authid) {
            mainWindow.displayToast(qsTr('Active layer CRS could not be determined.'));
            oneTapButton.enable();
            return;
        }

        let point = GeometryUtils.point(longitude, latitude);

        // Reproject to layer CRS if needed
        let transformedPoint = point;
        if (layerCrs.authid !== "EPSG:4326") {
            transformedPoint = GeometryUtils.reprojectPoint(point, wgs84Crs, layerCrs);
            if (!transformedPoint || typeof transformedPoint.x !== "number" || typeof transformedPoint.y !== "number") {
                mainWindow.displayToast(qsTr('Failed to reproject point. CRS transformation error.'));
                oneTapButton.enable();
                return;
            }
        }

        let geometry = GeometryUtils.createGeometryFromWkt('POINT(' + transformedPoint.x + ' ' + transformedPoint.y + ')');
        if (!geometry) {
            mainWindow.displayToast(qsTr('Failed to create geometry.'));
            oneTapButton.enable();
            return;
        }

        let relativePath = "DCIM/onetap_" + Date.now() + ".jpg";
        let fullPath = qgisProject.homePath + "/" + relativePath;

        plugin.pendingFeatureData = {
            layer: layer,
            geometry: geometry,
            relativePath: relativePath
        };
        plugin.log(feelgoodOnetapSettings.autoImage);
        if (feelgoodOnetapSettings.autoImage) {
            cameraItem.attemptCapture(fullPath);
            return;
        }
        plugin.createFromPendingFeatureData();
        return;
    }

    function saveSettings() {
        return;
    }

    function loadSettings() {
        return;
    }

    function log(obj) {
        iface.logMessage(obj);
        return;
    }

    function createFromPendingFeatureData() {
        if (plugin.pendingFeatureData) {
            let feature = FeatureUtils.createBlankFeature(plugin.pendingFeatureData.layer.fields, plugin.pendingFeatureData.geometry);

            let fieldNames = feature.fields.names;
            if (fieldNames.indexOf(feelgoodOnetapSettings.pictureFieldName) > -1 && feelgoodOnetapSettings.autoImage) {
                let fieldIndex = fieldNames.indexOf(feelgoodOnetapSettings.pictureFieldName);
                feature.setAttribute(fieldIndex, plugin.pendingFeatureData.relativePath);
            } else if (feelgoodOnetapSettings.autoImage) {
                plugin.log("Picture field not found in feature fields");
            }

            overlayFeatureFormDrawer.featureModel.feature = feature;
            overlayFeatureFormDrawer.featureModel.resetAttributes(true);
            overlayFeatureFormDrawer.state = 'Add';
            overlayFeatureFormDrawer.open();
            overlayFeatureFormDrawer.close();

            plugin.pendingFeatureData = null;

            if (camera.active) {
                camera.active = false;
            } else {
                oneTapButton.enable();
            }

            if (feelgoodOnetapSettings.enableAudioFeedback) {
                successSound.playSuccess();
            }
        }
    }
}

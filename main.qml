import QtQuick
import QtCore
import QtQuick.Controls
import QtQuick.Layouts

import QtMultimedia

import org.qfield
import org.qgis
import Theme

import "qrc:/qml" as QFieldItems
import "components" as Components

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
    property bool isCapturing: false

    Settings {
        id: feelgoodOnetapSettings

        property bool autoImage: false
        property bool requireConfirmationOnImuMissing: true
        property string pictureFieldName: "picture"
        property bool enableAudioFeedback: true
    }

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(oneTapButton);
    }

    Component.onDestruction: {
        if (cameraComponent.active) {
            cameraComponent.active = false;
        }
    }

    function configure() {
        settingsDialog.open();
    }

    Components.Logger {
        id: logger
    }

    QfCameraPermission {
        id: cameraPermission

        onStatusChanged: {
            oneTapButton.start();
        }
    }

    Components.Camera {
        id: cameraComponent

        onPhotoCaptured: filePath => {
            plugin.createFromPendingFeatureData();
        }

        onCameraError: errorMessage => {
            logger.log("Camera error: " + errorMessage);
            oneTapButton.enable();
            plugin.isCapturing = false;
        }
    }

    SoundEffect {
        id: successSound
        source: "sounds/success.wav"

        function playSuccess() {
            if (feelgoodOnetapSettings.enableAudioFeedback) {
                play();
            }
        }
    }

    SoundEffect {
        id: attentionSound
        source: "sounds/attention.wav"

        function playAttention() {
            if (feelgoodOnetapSettings.enableAudioFeedback) {
                play();
            }
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
            start();
        }

        onPressAndHold: {
            settingsDialog.open();
        }

        function enable() {
            oneTapButton.iconSource = plugin.mainIconSource;
            oneTapButton.enabled = true;
        }

        function disable() {
            oneTapButton.iconSource = plugin.pendingIconSource;
            oneTapButton.enabled = false;
        }

        function start() {
            if (!oneTapButton.enabled || plugin.isCapturing) {
                return;
            }

            if (feelgoodOnetapSettings.autoImage && cameraPermission.status === Qt.PermissionStatus.Undetermined) {
                cameraPermission.request();
                return;
            }

            if (feelgoodOnetapSettings.requireConfirmationOnImuMissing && !plugin.positionSource.positionInformation.imuCorrection) {
                attentionSound.playAttention();
                imuMissingConfirmationDialog.open();
            } else {
                plugin.oneTap();
            }
        }
    }

    Components.Settings {
        id: settingsDialog

        settings: feelgoodOnetapSettings
        mainWindow: plugin.mainWindow
        parent: plugin.mainWindow.contentItem
    }

    Dialog {
        id: imuMissingConfirmationDialog
        parent: plugin.mainWindow.contentItem

        visible: false
        modal: true
        width: 400
        title: qsTr("IMU not active!")
        standardButtons: Dialog.Ok | Dialog.Cancel

        x: (plugin.mainWindow.width - width) / 2
        y: (plugin.mainWindow.height - height) / 2

        ColumnLayout {
            width: parent.width
            spacing: 10

            Label {
                text: qsTr("IMU is not active. Do you want to continue?\n\nHint: You can disable this confirmation in the plugin settings.")
                Layout.fillWidth: true
                Layout.preferredWidth: imuMissingConfirmationDialog.width - 40
                wrapMode: Text.Wrap
            }
        }

        onAccepted: {
            plugin.oneTap();
        }

        onRejected: {}
    }

    function startCameraCapture() {
        if (cameraPermission.status !== Qt.PermissionStatus.Granted) {
            let txt = "Camera permission not granted. Please disable automatic capture or adjust your app permissions!";
            logger.log(txt);
            mainWindow.displayToast(txt);
            oneTapButton.enable();
            return;
        }

        if (plugin.isCapturing) {
            logger.log("Camera capture already in progress. Please wait until the current capture is finished.");
            oneTapButton.enable();
            return;
        }

        if (!plugin.pendingFeatureData) {
            logger.log("Failed to create feature data. Please try again.");
            oneTapButton.enable();
            return;
        }

        let fullPath = qgisProject.homePath + "/" + plugin.pendingFeatureData.relativePath;
        cameraComponent.startCapture(fullPath);
        plugin.isCapturing = true;
    }

    function oneTap() {
        oneTapButton.disable();
        plugin.createPendingFeatureData();

        if (!plugin.pendingFeatureData) {
            logger.log("Failed to create pending feature data");
            oneTapButton.enable();
            return;
        }

        if (feelgoodOnetapSettings.autoImage) {
            platformUtilities.createDir(qgisProject.homePath, 'DCIM');
            plugin.startCameraCapture();
        } else {
            plugin.createFromPendingFeatureData();
        }
    }

    function createPendingFeatureData() {
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
            mainWindow.displayToast(qsTr('Cannot generate point. Active vector layer is missing a field named "%1". Please create it in the layer settings or adjust your plugin settings.').arg(feelgoodOnetapSettings.pictureFieldName));
            oneTapButton.enable();
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

        plugin.pendingFeatureData = {
            layer: layer,
            geometry: geometry,
            relativePath: relativePath
        };
    }

    function createFromPendingFeatureData() {
        if (plugin.pendingFeatureData) {
            let feature = FeatureUtils.createBlankFeature(plugin.pendingFeatureData.layer.fields, plugin.pendingFeatureData.geometry);

            overlayFeatureFormDrawer.featureModel.currentLayer = plugin.pendingFeatureData.layer;
            overlayFeatureFormDrawer.featureModel.feature = feature;
            overlayFeatureFormDrawer.featureModel.resetAttributes(true);
            overlayFeatureFormDrawer.state = 'Add';

            if (feelgoodOnetapSettings.autoImage) {
                let fieldNames = feature.fields.names;
                let fieldIndex = fieldNames.indexOf(feelgoodOnetapSettings.pictureFieldName);

                if (fieldIndex > -1) {
                    let success = overlayFeatureFormDrawer.featureModel.setData(overlayFeatureFormDrawer.featureModel.index(fieldIndex, 0), plugin.pendingFeatureData.relativePath, FeatureModel.AttributeValue);
                    if (!success) {
                        logger.log("Failed to set picture field");
                    }
                } else {
                    logger.log("Picture field not found in feature fields");
                }
            }

            let success = overlayFeatureFormDrawer.featureModel.create();

            if (success) {
                mainWindow.displayToast(qsTr('Feature created'));
            } else {
                logger.log("Failed to create feature");
                mainWindow.displayToast(qsTr('Failed to create feature'));
            }

            plugin.pendingFeatureData = null;
            cameraComponent.cleanup();
            plugin.isCapturing = false;
            oneTapButton.enable();

            successSound.playSuccess();
        }
    }
}

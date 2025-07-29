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
        settingsDialog.parent = mainWindow.contentItem;
        return;
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

    Components.Camera {
        id: cameraComponent
        
        onPhotoCaptured: (filePath) => {
            plugin.createFromPendingFeatureData();
        }
        
        onCameraError: (errorMessage) => {
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

    QfToolButton {
        id: oneTapButton
        iconSource: plugin.mainIconSource
        iconColor: Theme.white
        bgcolor: Theme.darkGray
        round: true
        enabled: true

        onClicked: {
            if (!oneTapButton.enabled || plugin.isCapturing) {
                return;
            }
            disable();

            if (feelgoodOnetapSettings.autoImage) {
                plugin.startCameraCapture();
                return;
            }
            plugin.oneTap();
            return;
        }

        onPressAndHold: {
            if (oneTapButton.enabled && !plugin.isCapturing) {
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

    Components.Settings {
        id: settingsDialog
        
        settings: feelgoodOnetapSettings
        parentWindow: plugin.mainWindow
    }

    function startCameraCapture() {
        if (plugin.isCapturing) {
            logger.log("Camera capture already in progress");
            return;
        }

        // First call oneTap to set up the pending feature data
        plugin.oneTap();
        
        if (!plugin.pendingFeatureData) {
            logger.log("Failed to create pending feature data");
            oneTapButton.enable();
            return;
        }

        let fullPath = qgisProject.homePath + "/" + plugin.pendingFeatureData.relativePath;
        cameraComponent.startCapture(fullPath);
        plugin.isCapturing = true;
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

        if (!feelgoodOnetapSettings.autoImage) {
            plugin.createFromPendingFeatureData();
            return;
        }

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
                logger.log("Picture field not found in feature fields");
            }

            overlayFeatureFormDrawer.featureModel.feature = feature;
            overlayFeatureFormDrawer.featureModel.resetAttributes(true);
            overlayFeatureFormDrawer.state = 'Add';
            overlayFeatureFormDrawer.open();
            overlayFeatureFormDrawer.close();

            plugin.pendingFeatureData = null;

            // Clean up camera after successful capture
            cameraComponent.cleanup();
            plugin.isCapturing = false;
            oneTapButton.enable();

            successSound.playSuccess();
        }
    }
}
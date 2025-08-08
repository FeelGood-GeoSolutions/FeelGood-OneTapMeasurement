import QtQuick
import QtCore
import QtMultimedia

import "."

Item {
    id: root

    Logger {
        id: logger
    }
    
    property alias active: cameraLoader.active
    
    signal photoCaptured(string filePath)
    signal cameraError(string errorMessage)
    
    function startCapture(filePath) {
        logger.log("11")
        if (cameraLoader.item) {
            logger.log("12")
            cameraLoader.item.startCapture(filePath);
        } else {
            logger.log("12b")
            cameraLoader.active = true;
            Qt.callLater(() => {
                if (cameraLoader.item) {
                    cameraLoader.item.startCapture(filePath);
                } else {
                    root.cameraError("Failed to load camera component");
                }
            });
        }
    }
    
    function cleanup() {
        if (cameraLoader.active) {
            Qt.callLater(() => {
                cameraLoader.active = false;
            });
        }
    }

    Loader {
        id: cameraLoader
        active: false
        
        sourceComponent: Component {
            Item {
                id: cameraComponent
                
                property alias photoPath: imageCapture.lastSavedPath
                property string pendingCapturePath: ""
                
                MediaDevices {
                    id: mediaDevices
                }

                Camera {
                    id: camera
                    active: false
                    cameraDevice: mediaDevices.defaultVideoInput

                    onActiveChanged: {
                        if (active && cameraComponent.pendingCapturePath) {
                            Qt.callLater(() => {
                                cameraComponent.attemptCapture(cameraComponent.pendingCapturePath);
                            });
                        }
                    }

                    onErrorOccurred: (error, errorString) => {
                        cameraComponent.handleCameraError("Camera error: " + errorString);
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
                        cameraComponent.photoCaptured(filePath);
                    }

                    onErrorOccurred: (requestId, error, errorString) => {
                        cameraComponent.handleCameraError("ImageCapture error: " + errorString);
                    }

                    onReadyForCaptureChanged: ready => {
                    }
                }

                signal photoCaptured(string filePath)

                Component.onCompleted: {
                    photoCaptured.connect(root.photoCaptured);
                }

                Component.onDestruction: {
                    if (camera.active) {
                        camera.active = false;
                    }
                }

                function handleCameraError(errorMessage) {
                    logger.log("Handling camera error - cleaning up: " + errorMessage);
                    root.cameraError(errorMessage);
                    Qt.callLater(() => {
                        cameraLoader.active = false;
                    });
                }

                function attemptCapture(path) {
                    let maxRetries = 5;
                    let retryCount = 0;
                    let retryDelay = 200; // ms
                    logger.log("13")
                    function tryCapture() {
                        if (retryCount >= maxRetries) {
                            handleCameraError("Failed to capture after " + maxRetries + " attempts");
                            return;
                        }

                        try {
                            if (!camera.active) {
                                handleCameraError("Camera not active during capture attempt");
                                return;
                            }

                            if (imageCapture.readyForCapture) {
                                imageCapture.captureToFile(path);
                            } else {
                                retryCount++;
                                logger.log("Attempt " + retryCount + ": Camera not ready, retrying in " + retryDelay + "ms");
                                delayTimer.callback = tryCapture;
                                delayTimer.interval = retryDelay;
                                delayTimer.start();
                            }
                        } catch (error) {
                            handleCameraError("Error capturing photo: " + error);
                        }
                    }
                    logger.log("14")
                    tryCapture();
                }

                function startCapture(path) {
                    pendingCapturePath = path;
                    
                    if (!camera.active) {
                        camera.active = true;
                    } else {
                        attemptCapture(path);
                    }
                }

                // Timer for delayed operations
                Timer {
                    id: delayTimer
                    interval: 100
                    repeat: false
                    property var callback: null
                    
                    onTriggered: {
                        if (callback) {
                            callback();
                            callback = null;
                        }
                    }
                }
            }
        }
    }
}
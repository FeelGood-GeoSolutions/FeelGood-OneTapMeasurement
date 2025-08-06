import QtQuick

QtObject {
    id: logger

    function log(msg) {
        if (iface && iface.logMessage) {
            iface.logMessage("[Feelgood OneTapMeasurement] " + msg);
        }
    }
}
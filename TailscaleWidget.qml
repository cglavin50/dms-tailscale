import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import Quickshell.Io

PluginComponent {
    id: root

    property bool isConnected: false
    property int refreshInterval: pluginData.refreshInterval || 5

    Timer {
        interval: root.refreshInterval * 1000
        running: true
        repeat: true
        onTriggered: statusCheck.running = true
    }

    Process {
        id: statusCheck
        command: ["tailscale", "status", "--json"]
        running: true

        property string caller: ""

        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.isConnected = data.BackendState === "Running";
                } catch (e) {
                    root.isConnected = false;
                    ToastService.showError("Error reading tailscale output");
                }

                statusCheck.running = false;
            }
        }

        onExited: {
            if (caller == "toggle") {
                const output = root.isConnected ? "Tailscale Connected" : "Tailscale Disconnected";
                ToastService.showInfo(output);
            }
            caller = "";
        }
    }

    Process {
        id: toggleProcess

        onExited: (code, status) => {
            statusCheck.caller = "toggle";
            statusCheck.running = true;
        }
    }

    function toggleTailscale() {
        if (root.isConnected) {
            toggleProcess.command = ["tailscale", "down"];
        } else {
            toggleProcess.command = ["tailscale", "up"];
        }
        toggleProcess.running = true;
    }

    horizontalBarPill: Component {
        MouseArea {
            implicitWidth: contentRow.implicitWidth
            implicitHeight: contentRow.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleTailscale()

            Row {
                id: contentRow
                spacing: Theme.spacingS

                DankIcon {
                    name: root.isConnected ? "vpn_key" : "vpn_key_off"
                    size: Theme.iconSize - 6
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showIcon
                }
            }
        }
    }

    verticalBarPill: Component {
        MouseArea {
            implicitWidth: contentRow.implicitWidth
            implicitHeight: contentRow.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleTailscale()

            Column {
                id: contentColumn
                spacing: Theme.spacingS

                DankIcon {
                    name: root.isConnected ? "vpn_key" : "vpn_key_off"
                    size: Theme.iconSize - 6
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showIcon
                }
            }
        }
    }
}

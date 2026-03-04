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
    property var exitNodes: []
    property string currentExitNode: ""
    property bool isBusy: false

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

                    const peers = data.Peer || {};
                    const nodes = [];
                    let activeExitNode = "";

                    for (const key in peers) {
                        const peer = peers[key];
                        if (peer.ExitNode) {
                            activeExitNode = peer.HostName || "";
                        }
                        if (peer.ExitNodeOption) {
                            nodes.push({
                                "hostName": peer.HostName || "",
                                "dnsName": (peer.DNSName || "").replace(/\.$/, ""),
                                "ip": (peer.TailscaleIPs && peer.TailscaleIPs[0]) || "",
                                "online": peer.Online || false,
                                "isActive": peer.ExitNode || false,
                                "os": peer.OS || ""
                            });
                        }
                    }

                    nodes.sort((a, b) => {
                        if (a.isActive !== b.isActive) return a.isActive ? -1 : 1;
                        if (a.online !== b.online) return a.online ? -1 : 1;
                        return a.hostName.localeCompare(b.hostName);
                    });

                    root.exitNodes = nodes;
                    root.currentExitNode = activeExitNode;
                } catch (e) {
                    root.isConnected = false;
                    root.exitNodes = [];
                    root.currentExitNode = "";
                    ToastService.showError("Error reading tailscale output");
                }

                statusCheck.running = false;
            }
        }

        onExited: {
            if (caller === "toggle") {
                const output = root.isConnected ? "Tailscale Connected" : "Tailscale Disconnected";
                ToastService.showInfo(output);
            } else if (caller === "exitnode") {
                if (root.currentExitNode) {
                    ToastService.showInfo("Exit node: " + root.currentExitNode);
                } else {
                    ToastService.showInfo("Exit node disconnected");
                }
                root.isBusy = false;
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

    Process {
        id: exitNodeProcess

        stdout: StdioCollector {
            id: exitNodeOut
        }

        stderr: StdioCollector {
            id: exitNodeErr
            onStreamFinished: {
                if (exitNodeErr.text) {
                    ToastService.showError("Exit node error: " + exitNodeErr.text.trim());
                }
            }
        }

        onExited: (code, status) => {
            if (code !== 0) {
                root.isBusy = false;
                return;
            }
            statusCheck.caller = "exitnode";
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

    function connectExitNode(ip) {
        if (root.isBusy) return;
        root.isBusy = true;
        exitNodeProcess.command = ["tailscale", "set", "--exit-node=" + ip];
        exitNodeProcess.running = true;
    }

    function disconnectExitNode() {
        if (root.isBusy) return;
        root.isBusy = true;
        exitNodeProcess.command = ["tailscale", "set", "--exit-node="];
        exitNodeProcess.running = true;
    }

    horizontalBarPill: Component {
        Row {
            id: contentRow
            spacing: Theme.spacingS

            DankIcon {
                name: root.isConnected ? "vpn_key" : "vpn_key_off"
                size: Theme.iconSize - 6
                color: root.isConnected ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            id: contentColumn
            spacing: Theme.spacingS

            DankIcon {
                name: root.isConnected ? "vpn_key" : "vpn_key_off"
                size: Theme.iconSize - 6
                color: root.isConnected ? Theme.primary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: 340
    popoutHeight: 400

    popoutContent: Component {
        PopoutComponent {
            id: popoutRoot

            headerText: "Tailscale"
            showCloseButton: true

            headerActions: Component {
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: refreshBtn.containsMouse ? Theme.surfacePressed : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "refresh"
                        size: 18
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: refreshBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: statusCheck.running = true
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: root.isConnected ? Theme.primaryPressed : Theme.surfaceLight
                    border.width: root.isConnected ? 2 : 1
                    border.color: root.isConnected ? Theme.primary : Theme.outlineLight

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingS

                        DankIcon {
                            name: root.isConnected ? "vpn_key" : "vpn_key_off"
                            size: 20
                            color: root.isConnected ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            spacing: 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 20 - tsToggle.width - Theme.spacingS * 3

                            StyledText {
                                text: root.isConnected ? "Connected" : "Disconnected"
                                font.pixelSize: Theme.fontSizeMedium
                                color: root.isConnected ? Theme.primary : Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: root.currentExitNode ? "Exit node: " + root.currentExitNode : "No exit node"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                visible: root.isConnected
                            }
                        }

                        DankToggle {
                            id: tsToggle
                            checked: root.isConnected
                            anchors.verticalCenter: parent.verticalCenter
                            hideText: true
                            onToggled: (value) => {
                                root.toggleTailscale();
                            }
                        }
                    }
                }

                Rectangle {
                    height: 1
                    width: parent.width
                    color: Theme.outlineLight
                    visible: root.isConnected
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: root.isConnected

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Exit Nodes"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: parent.width - exitNodesLabel.implicitWidth - disconnectBtn.width - Theme.spacingS * 2
                            height: 1
                        }

                        StyledText {
                            id: exitNodesLabel
                            text: ""
                            visible: false
                        }

                        Rectangle {
                            id: disconnectBtn
                            height: 26
                            width: disconnectRow.width + Theme.spacingM * 2
                            radius: 13
                            color: disconnectArea.containsMouse ? Theme.errorHover : Theme.surfaceLight
                            visible: root.currentExitNode !== ""
                            opacity: root.isBusy ? 0.5 : 1.0

                            Row {
                                id: disconnectRow
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "link_off"
                                    size: Theme.fontSizeSmall
                                    color: disconnectArea.containsMouse ? Theme.error : Theme.surfaceText
                                }

                                StyledText {
                                    text: "Disconnect"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: disconnectArea.containsMouse ? Theme.error : Theme.surfaceText
                                    font.weight: Font.Medium
                                }
                            }

                            MouseArea {
                                id: disconnectArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
                                enabled: !root.isBusy
                                onClicked: root.disconnectExitNode()
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: Math.min(root.exitNodes.length * 50, 240)

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS
                            visible: root.exitNodes.length === 0

                            DankIcon {
                                name: "vpn_key_off"
                                size: 32
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: "No exit nodes available"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        DankListView {
                            id: exitNodeList
                            anchors.fill: parent
                            visible: root.exitNodes.length > 0
                            spacing: 4
                            clip: true

                            model: root.exitNodes

                            delegate: Rectangle {
                                id: nodeDelegate

                                required property var modelData
                                required property int index

                                width: exitNodeList.width
                                height: 44
                                radius: Theme.cornerRadius
                                color: nodeArea.containsMouse ? Theme.primaryHoverLight : (modelData.isActive ? Theme.primaryPressed : Theme.surfaceLight)
                                border.width: modelData.isActive ? 2 : 1
                                border.color: modelData.isActive ? Theme.primary : Theme.outlineLight
                                opacity: root.isBusy ? 0.5 : (modelData.online ? 1.0 : 0.4)

                                MouseArea {
                                    id: nodeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: {
                                        if (root.isBusy) return Qt.BusyCursor;
                                        if (!modelData.online) return Qt.ForbiddenCursor;
                                        return Qt.PointingHandCursor;
                                    }
                                    enabled: !root.isBusy && modelData.online
                                    onClicked: {
                                        if (modelData.isActive) {
                                            root.disconnectExitNode();
                                        } else {
                                            root.connectExitNode(modelData.ip);
                                        }
                                    }
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: modelData.isActive ? "vpn_lock" : "public"
                                        size: 20
                                        color: modelData.isActive ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        spacing: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 20 - onlineIndicator.width - Theme.spacingS * 3

                                        StyledText {
                                            text: modelData.hostName
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: modelData.isActive ? Theme.primary : Theme.surfaceText
                                            font.weight: modelData.isActive ? Font.Medium : Font.Normal
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        StyledText {
                                            text: modelData.online ? modelData.ip : "Offline"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }

                                    Rectangle {
                                        id: onlineIndicator
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: modelData.online ? Theme.success : Theme.error
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: !root.isConnected

                    StyledText {
                        width: parent.width
                        text: "Connect Tailscale to view exit nodes"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}

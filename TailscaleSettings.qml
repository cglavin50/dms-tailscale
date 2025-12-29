import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "tailscale"

    StyledText {
        width: parent.width
        text: "Tailscale config"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Click the widget in your bar to toggle Tailscale connection"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        text: "Note: You may need to configure passwordless sudo for 'tailscale' commands, or ensure your user is in the correct group."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.warningText
        wrapMode: Text.WordWrap
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: "Refresh Interval"
        description: "Context refresh interval (in seconds)."
        defaultValue: 5
        minimum: 1
        maximum: 600
        unit: "sec"
        leftIcon: "schedule"
    }
}

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property int batteryPercent: -1
    property string modelName: "Darmoshark Mouse"
    property string detailsText: ""

    readonly property string readCmd: "sh -c 'found=0; for d in /sys/class/power_supply/darmoshark_battery_*; do [ -f \"$d/capacity\" ] || continue; cap=$(cat \"$d/capacity\" 2>/dev/null); model=$(cat \"$d/model_name\" 2>/dev/null); present=$(cat \"$d/present\" 2>/dev/null); if [ \"$present\" = \"1\" ] && [ -n \"$cap\" ]; then echo \"${cap}|${model:-Darmoshark}\"; found=1; fi; done; if [ \"$found\" = \"0\" ]; then echo \"-1|Darmoshark Mouse\"; fi'"

    preferredRepresentation: fullRepresentation

    toolTipMainText: root.modelName
    toolTipSubText: root.batteryPercent >= 0
        ? (root.detailsText.length > 0 ? root.detailsText : ("Bateria: " + root.batteryPercent + "%"))
        : "Sem leitura (mouse desconectado, dormindo ou módulo darmoshark_battery não carregado)"

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            var out = (data["stdout"] || "").trim();
            if (out.length > 0) {
                var lines = out.split("\n");
                var firstParts = lines[0].split("|");
                var val = parseInt((firstParts[0] || "").trim(), 10);
                var name = (firstParts[1] || "Darmoshark Mouse").trim();
                if (!isNaN(val) && val >= 0 && val <= 100) {
                    root.batteryPercent = val;
                    root.modelName = name;
                    if (lines.length > 1) {
                        var summary = [];
                        for (var i = 0; i < lines.length; i++) {
                            var p = lines[i].split("|");
                            if (p.length >= 2) {
                                summary.push(p[1].trim() + ": " + p[0].trim() + "%");
                            }
                        }
                        root.detailsText = summary.join("\n");
                    } else {
                        root.detailsText = "Bateria: " + val + "%";
                    }
                } else {
                    root.batteryPercent = -1;
                    root.detailsText = "";
                }
            }
            disconnectSource(sourceName);
        }
    }

    function pollBattery() {
        executable.connectSource(root.readCmd);
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pollBattery()
    }

    fullRepresentation: Item {
        id: panelItem
        implicitWidth: badgeRow.implicitWidth + 10
        implicitHeight: Kirigami.Units.iconSizes.medium
        Layout.fillWidth: false
        Layout.fillHeight: true
        Layout.minimumWidth: badgeRow.implicitWidth + 10
        Layout.preferredWidth: badgeRow.implicitWidth + 10
        Layout.maximumWidth: badgeRow.implicitWidth + 10

        RowLayout {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 4

            Kirigami.Icon {
                source: "input-mouse"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                color: root.batteryPercent < 0
                    ? "#7f8c8d"
                    : (root.batteryPercent <= 15 ? "#da4453" : (root.batteryPercent <= 25 ? "#f39c12" : Kirigami.Theme.textColor))
            }

            PC3.Label {
                text: root.batteryPercent >= 0 ? (root.batteryPercent + "%") : "--%"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: root.batteryPercent < 0
                    ? "#7f8c8d"
                    : (root.batteryPercent <= 15 ? "#da4453" : (root.batteryPercent <= 25 ? "#f39c12" : Kirigami.Theme.textColor))
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pollBattery()
        }
    }
}

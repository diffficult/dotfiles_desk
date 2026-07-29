import QtQuick
import Quickshell.Io

Item {
    id: controller

    required property var host

    property string powerProfile: ""
    property var powerProfiles: []
    readonly property var actions: [
        { glyph: "󰌾", label: "LOCK",      cmd: "hyprlock" },
        { glyph: "󰤄", label: "SUSPEND",   cmd: "systemctl suspend" },
        { glyph: "󰋊", label: "HIBERNATE", cmd: "systemctl hibernate" },
        { glyph: "󰗽", label: "LOGOUT",    cmd: "hyprctl dispatch exit" },
        { glyph: "󰜉", label: "REBOOT",    cmd: "systemctl reboot" },
        { glyph: "󰐥", label: "SHUTDOWN",  cmd: "systemctl poweroff" }
    ]

    function setPowerProfile(name) {
        if (!name) return;
        controller.powerProfile = name;
        controller.host.run("powerprofilesctl set " + name);
        powerProfileRefreshTimer.restart();
    }

    function refreshPowerProfile() {
        powerProfileProbe.running = false;
        powerProfileProbe.running = true;
    }

    function fireAction(action) {
        if (!action || !action.cmd) return;
        controller.host.run(action.cmd);
    }

    Timer {
        id: powerProfileRefreshTimer
        interval: 400
        repeat: false
        onTriggered: controller.refreshPowerProfile()
    }

    Process {
        id: powerProfileProbe
        running: false
        command: ["bash", "-lc",
            "cur=$(powerprofilesctl get 2>/dev/null); "
            + "if [ -z \"$cur\" ]; then echo '|'; exit 0; fi; "
            + "list=$(powerprofilesctl list 2>/dev/null | awk -F: '/^[ *]+[a-z-]+:/{gsub(/^[ *]+|:$/,\"\",$1); print $1}' | paste -sd,); "
            + "printf '%s|%s' \"$cur\" \"$list\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split("|");
                if (p.length !== 2) return;
                const cur = p[0] || "";
                const list = p[1] ? p[1].split(",").filter(Boolean) : [];
                if (controller.powerProfile !== cur) controller.powerProfile = cur;
                if (JSON.stringify(controller.powerProfiles) !== JSON.stringify(list))
                    controller.powerProfiles = list;
            }
        }
    }

    Component.onCompleted: refreshPowerProfile()
}

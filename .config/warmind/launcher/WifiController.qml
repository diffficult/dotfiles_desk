import QtQuick
import Quickshell.Io

Item {
    id: controller

    property bool supported: false
    property var networks: []
    property bool radioOn: true
    property bool scanning: false
    property string networksSerialised: ""
    property bool active: false

    function open() {
        controller.active = true;
        controller.refresh();
    }

    function close() {
        controller.active = false;
    }

    function toggle() {
        if (controller.active) controller.close();
        else controller.open();
    }

    function refresh() {
        if (scanProbe.running) return;
        scanning = true;
        scanProbe.running = false;
        scanProbe.running = true;
    }

    function connect(ssid) {
        if (!ssid) return;
        runCommand("DEV=$(iwctl --dont-ask device list 2>/dev/null"
                 + " | sed 's/\\x1b\\[[0-9;]*m//g'"
                 + " | awk '/station/{print $1; exit}');"
                 + " [ -n \"$DEV\" ] && iwctl --dont-ask station \"$DEV\" connect "
                 + JSON.stringify(ssid));
        postActionTimer.restart();
    }

    function disconnect() {
        runCommand("DEV=$(iwctl --dont-ask device list 2>/dev/null"
                 + " | sed 's/\\x1b\\[[0-9;]*m//g'"
                 + " | awk '/station/{print $1; exit}');"
                 + " [ -n \"$DEV\" ] && iwctl --dont-ask station \"$DEV\" disconnect");
        postActionTimer.restart();
    }

    function toggleRadio() {
        const target = radioOn ? "off" : "on";
        radioOn = !radioOn;
        runCommand("DEV=$(iwctl --dont-ask device list 2>/dev/null"
                 + " | sed 's/\\x1b\\[[0-9;]*m//g'"
                 + " | awk '/^[[:space:]]+[a-z][a-z0-9]+/{print $1; exit}');"
                 + " [ -n \"$DEV\" ] && iwctl --dont-ask device \"$DEV\" set-property Powered " + target);
        postActionTimer.restart();
    }

    function runCommand(cmd) {
        runner.command = ["bash", "-lc", cmd];
        runner.running = false;
        runner.running = true;
    }

    Process {
        id: runner
        running: false
    }

    Timer {
        id: postActionTimer
        interval: 800
        repeat: false
        onTriggered: controller.refresh()
    }

    Process {
        id: scanProbe
        running: false
        command: ["bash", "-lc",
            "DEV=$(iwctl --dont-ask device list 2>/dev/null"
            + "   | sed 's/\\x1b\\[[0-9;]*m//g'"
            + "   | awk '/station/{print $1; exit}');"
            + " if [ -z \"$DEV\" ]; then echo 'SUPPORT|off'; echo 'RADIO|off'; exit 0; fi;"
            + " echo 'SUPPORT|on';"
            + " powered=$(iwctl --dont-ask device \"$DEV\" show 2>/dev/null"
            + "   | sed 's/\\x1b\\[[0-9;]*m//g'"
            + "   | awk '/Powered/{print $NF; exit}');"
            + " if [ \"$powered\" != on ]; then echo 'RADIO|off'; exit 0; fi;"
            + " echo 'RADIO|on';"
            + " iwctl --dont-ask station \"$DEV\" scan >/dev/null 2>&1;"
            + " iwctl --dont-ask station \"$DEV\" get-networks rssi-dbms 2>/dev/null"
            + "   | sed 's/\\x1b\\[[0-9;]*m//g'"
            + "   | awk '"
            + "       /^-+$/ { sep++; next }"
            + "       sep < 2 || $0 ~ /^[[:space:]]*$/ { next }"
            + "       {"
            + "         line=$0;"
            + "         conn=(index(substr(line,1,4),\">\")>0)?1:0;"
            + "         sub(/^[ >]+/, \"\", line);"
            + "         sub(/[ ]+$/, \"\", line);"
            + "         if (match(line, /^(.*[^ ])  +([^ ]+)  +(-?[0-9]+)$/, m))"
            + "           printf \"%d\\t%s\\t%s\\t%s\\n\", conn, m[1], m[2], m[3];"
            + "       }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(s => s.length > 0);
                let nextSupported = false;
                let nextRadioOn = false;
                const nextNetworks = [];
                for (const line of lines) {
                    if (line.startsWith("SUPPORT|")) {
                        nextSupported = line.slice(8) === "on";
                        continue;
                    }
                    if (line.startsWith("RADIO|")) {
                        nextRadioOn = line.slice(6) === "on";
                        continue;
                    }
                    const fields = line.split("\t");
                    if (fields.length < 4) continue;
                    const dbm = parseInt(fields[3]) / 100;
                    const pct = Math.max(0, Math.min(100, Math.round(2 * (dbm + 100))));
                    nextNetworks.push({
                        inUse: fields[0] === "1",
                        ssid: fields[1],
                        signal: pct,
                        security: fields[2]
                    });
                }
                nextNetworks.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal));
                controller.supported = nextSupported;
                controller.radioOn = nextRadioOn;
                const ser = JSON.stringify(nextNetworks);
                if (ser !== controller.networksSerialised) {
                    controller.networksSerialised = ser;
                    controller.networks = nextNetworks;
                }
                controller.scanning = false;
            }
        }
    }
}

import QtQuick

CardWindow {
    id: networkPopup
    required property var root
    required property var controller

    theme: root
    revealed: controller.active
    cardWidth: 520
    layerNamespace: "warmind-network"
    title: "NETWORK"
    subtitle: controller.supported
        ? controller.radioOn ? controller.networks.length + " NETWORKS" : "WI-FI RADIO OFF"
        : root.netKind === "eth" ? "ETHERNET" : "NO WI-FI ADAPTER"
    footer: "↑↓ ROW · ENTER ACTIVATE · R REFRESH · ESC CLOSE"

    anchorEdge: networkPopup.root.barEdge
    anchorBarX: networkPopup.root.popupAnchorX > 0
        ? networkPopup.root.popupAnchorX : networkPopup.width / 2
    anchorBarY: networkPopup.root.popupAnchorY

    headerRight: CalendarChevron {
        root: networkPopup.root
        text: networkPopup.root.icoRefresh
        restColor: networkPopup.root.inkDeep
        font.pixelSize: 22
        onTriggered: networkPopup.controller.refresh()
    }

    onDismiss: networkPopup.controller.close()
    onKeyPressed: function(event) {
        if (event.key === Qt.Key_R) {
            networkPopup.controller.refresh();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Q) {
            networkPopup.controller.close();
            event.accepted = true;
            return;
        }
        if (popupBody.kbdHandle(event)) event.accepted = true;
    }

    Flickable {
        id: networkScroller
        width: parent.width
        height: Math.min(500, Math.max(140, popupBody.implicitHeight))
        contentWidth: width
        contentHeight: popupBody.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        QuickWifiBody {
            id: popupBody
            width: networkScroller.width
            root: networkPopup.root
            nav: networkPopup.root
            controller: networkPopup.controller
            onClose: networkPopup.controller.close()
        }
    }
}

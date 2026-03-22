import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Slide {
        Image {
            id: slide1
            source: "welcome.png"
            width: parent.width
            height: parent.height
            fillMode: Image.PreserveAspectFit
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 40
            text: "Welcome to WrathOS — Forging ahead reliably, Gaming at the edge."
            color: "#DDDDDD"
            font.pixelSize: 18
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: "Powered by the CachyOS kernel\nBORE scheduler · ThinLTO · FUTEX2\nFor maximum gaming performance."
            color: "#DDDDDD"
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: "Lean by default.\nChoose your gaming bundles after install\nwith the WrathOS configurator."
            color: "#DDDDDD"
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Timer {
        interval: 5000
        running: presentation.exposed
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }
}

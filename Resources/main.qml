import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    width: 600
    height: 400
    visible: true
    title: "Relic"

    globalDrawer: Kirigami.GlobalDrawer {
        title: "Navigation"
        titleIcon: "view-list-icons"
        
        actions: [
            Kirigami.Action {
                text: "Home"
                icon.name: "go-home"
                onTriggered: pageStack.replace(homePage)
            },
            Kirigami.Action {
                text: "About"
                icon.name: "help-about"
                onTriggered: pageStack.replace(aboutPage)
            }
        ]
    }

    Component {
        id: homePage
        Kirigami.Page {
            title: "Home"
            
            Controls.Label {
                anchors.centerIn: parent
                text: "Welcome to the Home Page"
                font.pointSize: 20
            }
        }
    }

    Component {
        id: aboutPage
        Kirigami.Page {
            title: "About"
            
            Controls.Label {
                anchors.centerIn: parent
                text: "This is Relic."
            }
        }
    }

    // Default startup page
    pageStack.initialPage: homePage
}
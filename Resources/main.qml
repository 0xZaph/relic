import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    width: 420
    height: 560
    visible: true
    title: "Relic"

    required property var viewModel

    globalDrawer: Kirigami.GlobalDrawer {
        title: "Relic"
        titleIcon: "relic-icon"
        
        actions: [
            Kirigami.Action {
                text: "Logout"
                icon.name: "system-log-out"
                visible: viewModel.isLoggedIn
                onTriggered: viewModel.logout()
            },
            Kirigami.Action {
                text: "About"
                icon.name: "help-about"
                onTriggered: pageStack.push(aboutPage)
            }
        ]
    }

    Component {
        id: homePage
        Kirigami.Page {
            title: "Profile"
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Kirigami.Units.gridUnit
                width: parent.width - Kirigami.Units.gridUnit * 2

                Rectangle {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 6
                    Layout.alignment: Qt.AlignHCenter
                    radius: width / 2
                    color: Kirigami.Theme.highlightColor
                    
                    Kirigami.Icon {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        source: "user"
                        color: "white"
                    }
                }

                Kirigami.Heading {
                    text: viewModel.username
                    type: Kirigami.Heading.Type.Primary
                    Layout.alignment: Qt.AlignHCenter
                }

                Controls.Label {
                    text: "Logged in via Epic Games"
                    opacity: 0.7
                    Layout.alignment: Qt.AlignHCenter
                }

                Item { Layout.preferredHeight: Kirigami.Units.gridUnit }

                Controls.Button {
                    text: "Refresh Library"
                    icon.name: "view-refresh"
                    Layout.fillWidth: true
                    onClicked: {
                        // Future library refresh logic
                    }
                }

                Controls.Button {
                    text: "Logout"
                    icon.name: "system-log-out"
                    Layout.fillWidth: true
                    palette.buttonText: Kirigami.Theme.negativeTextColor
                    onClicked: viewModel.logout()
                }
            }
        }
    }

    Component {
        id: loginPage
        Kirigami.Page {
            title: "Welcome"
            
            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 20)
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Heading {
                    text: "Relic"
                    font.pointSize: 32
                    Layout.alignment: Qt.AlignHCenter
                }

                Controls.Label {
                    text: "Enter your Epic Games authorization code to continue."
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Controls.TextField {
                    id: codeInput
                    placeholderText: "Authorization Code"
                    Layout.fillWidth: true
                    echoMode: TextInput.Normal
                    onAccepted: viewModel.login(text)
                }

                Controls.Button {
                    text: "Login"
                    highlighted: true
                    Layout.fillWidth: true
                    enabled: codeInput.text.length > 0
                    onClicked: viewModel.login(codeInput.text)
                }

                Controls.Label {
                    text: viewModel.errorMessage
                    color: Kirigami.Theme.negativeTextColor
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    visible: text.length > 0
                }
            }
        }
    }

    Component {
        id: aboutPage
        Kirigami.Page {
            title: "About"
            Controls.Label {
                anchors.centerIn: parent
                text: "Relic - A Native Epic Games Client"
            }
        }
    }

    pageStack.initialPage: viewModel.isLoggedIn ? homePage : loginPage

    Connections {
        target: viewModel
        function onIsLoggedInChanged() {
            if (viewModel.isLoggedIn) {
                pageStack.replace(homePage)
            } else {
                pageStack.replace(loginPage)
            }
        }
    }
}
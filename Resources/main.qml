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
                visible: viewModel.userViewModel.isLoggedIn
                onTriggered: viewModel.userViewModel.logout()
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
                anchors.fill: parent
                anchors.margins: Kirigami.Units.gridUnit
                spacing: Kirigami.Units.gridUnit

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
                    text: viewModel.userViewModel.username
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
                    enabled: !viewModel.libraryViewModel.isRefreshing
                    onClicked: viewModel.libraryViewModel.refreshLibrary()
                }

                Controls.Label {
                    text: viewModel.libraryViewModel.statusMessage
                    opacity: 0.7
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8

                    model: viewModel.libraryViewModel.games

                    delegate: Rectangle {
                        required property var modelData

                        radius: 10
                        color: Kirigami.Theme.alternateBackgroundColor
                        implicitHeight: 64
                        width: ListView.view.width

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 2

                            Controls.Label {
                                text: modelData.title
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Controls.Label {
                                text: modelData.developer.length > 0 ? modelData.developer : modelData.appName
                                opacity: 0.7
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                Controls.Button {
                    text: "Logout"
                    icon.name: "system-log-out"
                    Layout.fillWidth: true
                    palette.buttonText: Kirigami.Theme.negativeTextColor
                    onClicked: viewModel.userViewModel.logout()
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
                    onAccepted: viewModel.userViewModel.login(text)
                }

                Controls.Button {
                    text: "Login"
                    highlighted: true
                    Layout.fillWidth: true
                    enabled: codeInput.text.length > 0
                    onClicked: viewModel.userViewModel.login(codeInput.text)
                }

                Controls.Label {
                    text: viewModel.userViewModel.errorMessage
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

    pageStack.initialPage: viewModel.userViewModel.isLoggedIn ? homePage : loginPage

    Connections {
        target: viewModel.userViewModel
        function onIsLoggedInChanged() {
            if (viewModel.userViewModel.isLoggedIn) {
                pageStack.replace(homePage)
            } else {
                pageStack.replace(loginPage)
            }
        }
    }
}
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

    Kirigami.Page {
        id: profilePage
        property var viewModel
        title: "Profile"
        Loader {
            anchors.fill: parent
            sourceComponent: viewModel.userViewModel.isLoggedIn ? profileInfo : loginForm
        }

        Component {
            id: loginForm
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40 
                spacing: Kirigami.Units.largeSpacing

                Image {
                    source: "epic_games_logo.svg"
                    sourceSize.width: Kirigami.Units.iconSizes.huge
                    sourceSize.height: Kirigami.Units.iconSizes.huge
                    Layout.alignment: Qt.AlignHCenter
                    opacity: 0.8
                }

                Kirigami.Heading {
                    text: "Welcome!"
                    level: 1
                    Layout.fillWidth: true
                }

                Controls.Label {
                    text: "In order for you to be able to log in and install your games, we first need you to follow the steps below:"
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }
                
                Kirigami.Card {
                    Layout.fillWidth: true
                    
                    contentItem: ColumnLayout {
                        Layout.margins: Kirigami.Units.largeSpacing * 1.5
                        spacing: Kirigami.Units.largeSpacing

                        Controls.Label {
                            text: "1.  Open the Epic Games login page:"
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        
                        Kirigami.Separator {
                            Layout.fillWidth: true
                            opacity: 0.5
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Controls.TextField {
                                id: urlField
                                text: "https://legendary.gl/epiclogin"
                                readOnly: true
                                Layout.fillWidth: true
                            }

                            Controls.Button {
                                text: "Copy"
                                icon.name: "edit-copy"
                                flat: true
                                onClicked: {
                                    urlField.selectAll()
                                    urlField.copy()
                                    urlField.deselect()
                                }
                            }

                            Controls.Button {
                                text: "Open"
                                icon.name: "internet-web-browser"
                                flat: true
                                onClicked: Qt.openUrlExternally(urlField.text)
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Kirigami.Units.smallSpacing }

                Kirigami.Card {
                    Layout.fillWidth: true
                    
                    contentItem: ColumnLayout {
                        Layout.margins: Kirigami.Units.largeSpacing * 1.5
                        spacing: Kirigami.Units.largeSpacing

                        Controls.Label {
                            text: "2.  Copy the authorization code from the browser and paste it below:"
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        Kirigami.Separator {
                            Layout.fillWidth: true
                            opacity: 0.5
                        }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.largeSpacing

                                Controls.Label {
                                    text: "Auth Code"
                                }
                        
                                Controls.TextField {
                                    id: codeInput
                                    Layout.fillWidth: true
                                    echoMode: TextInput.Normal
                                    onAccepted: viewModel.userViewModel.login(text)
                                }
                            }
                    }
                }

                Item { Layout.fillHeight: true }

                Controls.Label {
                    text: viewModel.userViewModel.errorMessage
                    color: Kirigami.Theme.negativeTextColor
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    visible: text.length > 0
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight

                    Item { Layout.fillWidth: true }

                    Controls.Button {
                        text: "Connect Account"
                        highlighted: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                        enabled: codeInput.text.length > 0
                        onClicked: viewModel.userViewModel.login(codeInput.text)
                    }
                }
            }
        }

                Component {
            id: profileInfo
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing * 2
                spacing: Kirigami.Units.largeSpacing * 2

                Kirigami.Card {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.largeSpacing
                        Layout.margins: Kirigami.Units.largeSpacing

                        Rectangle {
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 96
                            Layout.alignment: Qt.AlignHCenter
                            radius: width / 2
                            color: "transparent"
                            border.color: Kirigami.Theme.highlightColor
                            border.width: 3

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 6
                                radius: width / 2
                                color: Kirigami.Theme.highlightColor
                                
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 48
                                    height: 48
                                    source: "user"
                                    color: Kirigami.Theme.highlightedTextColor
                                }
                            }
                        }

                        Kirigami.Heading {
                            text: viewModel.userViewModel.username
                            level: 2
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Controls.Label {
                            text: "✓ Epic Games Account Connected"
                            color: Kirigami.Theme.positiveTextColor
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Controls.Button {
                    text: "Sign Out"
                    icon.name: "system-log-out"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
                    palette.button: Kirigami.Theme.negativeBackgroundColor
                    palette.buttonText: Kirigami.Theme.negativeTextColor
                    onClicked: viewModel.userViewModel.logout()
                }
            }
        }
    }

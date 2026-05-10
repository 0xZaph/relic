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
                anchors.margins: Kirigami.Units.gridUnit
                spacing: Kirigami.Units.gridUnit
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

        Component {
            id: profileInfo
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

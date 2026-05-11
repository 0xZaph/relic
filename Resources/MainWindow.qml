import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    width: 720
    height: 640
    minimumWidth: 720
    minimumHeight: 640
    visible: true
    title: "Relic"

    required property var viewModel

    property int currentPage: 0 // 0: Library, 1: Profile, 2: Store


    globalDrawer: Kirigami.GlobalDrawer {
        id: drawer
        title: "Relic"
        titleIcon: "relic-icon"
        actions: [
            Kirigami.Action {
                text: "Library"
                icon.name: "view-list-details"
                onTriggered: root.currentPage = 0
            },
            Kirigami.Action {
                text: "Profile"
                icon.name: "user"
                onTriggered: root.currentPage = 1
            },
            Kirigami.Action {
                text: "Store"
                icon.name: "system-software-install"
                onTriggered: root.currentPage = 2
            },
            Kirigami.Action {
                text: "Logout"
                icon.name: "system-log-out"
                enabled: viewModel.userViewModel.isLoggedIn
                onTriggered: viewModel.userViewModel.logout()
            }
        ]
    }

    Loader {
        id: pageLoader
        anchors.fill: parent
        sourceComponent: !viewModel.userViewModel.isLoggedIn ? profilePage : (root.currentPage === 0 ? libraryPage : (root.currentPage === 2 ? storePage : profilePage))
    }

    Component { id: libraryPage; LibraryPage { viewModel: root.viewModel } }
    Component { id: profilePage; ProfilePage { viewModel: root.viewModel } }
    Component { id: storePage; StorePage { viewModel: root.viewModel } }

    Connections {
        target: viewModel.userViewModel
        function onIsLoggedInChanged() {
            if (viewModel.userViewModel.isLoggedIn) {
                root.currentPage = 0;
            } else {
                root.currentPage = 0;
            }
        }
    }
}

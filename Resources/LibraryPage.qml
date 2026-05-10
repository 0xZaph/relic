import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: libraryPage
    property var viewModel
    title: qsTr("Library")

    readonly property var lvm: viewModel.libraryViewModel

    actions: [
        Kirigami.Action {
            icon.name: "view-refresh"
            text: qsTr("Refresh Library")
            enabled: !lvm.isRefreshing
            onTriggered: lvm.refreshLibrary()
        }
    ]

    // Busy indicator in the page header area while refreshing
    Controls.BusyIndicator {
        anchors.centerIn: parent
        running: lvm.isRefreshing
        visible: lvm.isRefreshing
        z: 10
    }

    // Error banner
    Kirigami.InlineMessage {
        id: errorBanner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.smallSpacing
        visible: lvm.errorMessage !== ""
        type: Kirigami.MessageType.Error
        text: lvm.errorMessage
        z: 9
    }

    // Empty state
    ColumnLayout {
        anchors.centerIn: parent
        visible: !lvm.isRefreshing && gamesGrid.count === 0
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            source: "folder-games-symbolic"
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.iconSizes.huge
            implicitHeight: Kirigami.Units.iconSizes.huge
            opacity: 0.5
        }
        Kirigami.Heading {
            text: qsTr("No Games Found")
            level: 2
            Layout.alignment: Qt.AlignHCenter
        }
        Controls.Label {
            text: qsTr("Try refreshing your library.")
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.7
        }
    }

    // Game grid — GridView directly fills the page, no ScrollView wrapper
    GridView {
        id: gamesGrid
        anchors.fill: parent
        anchors.topMargin: lvm.errorMessage !== "" ? errorBanner.height + Kirigami.Units.smallSpacing * 2 : 0

        readonly property int cardWidth: 160
        readonly property int cardHeight: 213
        readonly property int cardSpacing: Kirigami.Units.largeSpacing

        cellWidth: cardWidth + cardSpacing
        cellHeight: cardHeight + cardSpacing + 28  // 28px for title below card
        cacheBuffer: height

        model: lvm.games
        visible: !lvm.isRefreshing

        delegate: Item {
            required property string title
            required property bool isInstalled
            required property string artSquare
            required property string artCover

            readonly property string imageUrl: artSquare !== "" ? artSquare
                                             : artCover  !== "" ? artCover
                                             : ""

            width: gamesGrid.cellWidth
            height: gamesGrid.cellHeight

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: gamesGrid.cardSpacing / 2
                width: gamesGrid.cardWidth
                height: gamesGrid.cellHeight - gamesGrid.cardSpacing / 2

                Rectangle {
                    id: gameCard
                    width: gamesGrid.cardWidth
                    height: gamesGrid.cardHeight
                    radius: 12
                    color: "#1e1e1e"
                    clip: true

                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    // Cover image — hidden, used as MultiEffect source
                    Image {
                        id: coverImage
                        anchors.fill: parent
                        source: imageUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        sourceSize.width: gamesGrid.cardWidth * 2
                        sourceSize.height: gamesGrid.cardHeight * 2
                        visible: false
                    }

                    // Rounded mask for MultiEffect
                    Item {
                        id: roundedMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: "black"
                        }
                    }

                    // Rendered image with desaturation for uninstalled games
                    MultiEffect {
                        anchors.fill: parent
                        source: coverImage
                        visible: coverImage.status === Image.Ready
                        colorization: (isInstalled || cardHover.containsMouse) ? 0.0 : 0.85
                        colorizationColor: "#808080"
                        maskEnabled: true
                        maskSource: roundedMask
                    }

                    // Placeholder while loading or no URL
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: "#2a2a2a"
                        visible: coverImage.status !== Image.Ready

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            source: "games-config-tiles"
                            implicitWidth: Kirigami.Units.iconSizes.large
                            implicitHeight: Kirigami.Units.iconSizes.large
                            opacity: 0.3
                        }
                    }

                    // Hover gradient + title overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        opacity: cardHover.containsMouse ? 1.0 : 0.0
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5;  color: "#50000000" }
                            GradientStop { position: 1.0;  color: "#CC000000" }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }

                        Controls.Label {
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                margins: Kirigami.Units.largeSpacing
                            }
                            text: title
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.pointSize: 10
                            font.weight: Font.Bold
                            color: "white"
                        }
                    }

                    // Installed dot badge
                    Rectangle {
                        visible: isInstalled
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 8
                        height: 8
                        radius: 4
                        color: "#4caf50"
                    }

                    MouseArea {
                        id: cardHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: gameCard.scale = 1.05
                        onExited:  gameCard.scale = 1.0
                        onClicked: console.log("Clicked:", title)
                    }
                }

                // Title below card
                Controls.Label {
                    anchors.top: gameCard.bottom
                    anchors.topMargin: 4
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: title
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.pointSize: 9
                    opacity: 0.85
                }
            }
        }
    }
}

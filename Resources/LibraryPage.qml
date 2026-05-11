import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Dialogs
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

    // Game detail / import sheet
    Kirigami.OverlaySheet {
        id: gameSheet
        width: Math.min(libraryPage.width * 0.9, 500)

        onVisibleChanged: {
            if (!visible) lvm.clearSelectedGame()
        }

        // Open whenever a game is selected
        Connections {
            target: lvm
            function onHasSelectedGameChanged() {
                if (lvm.hasSelectedGame) {
                    importPathField.text = ""
                    gameSheet.open()
                } else {
                    gameSheet.close()
                }
            }
        }

        header: RowLayout {
            spacing: Kirigami.Units.largeSpacing
            // Fixed height header so the image can't blow up the sheet
            height: 100

            Rectangle {
                width: 75
                height: 100
                radius: 6
                color: Kirigami.Theme.alternateBackgroundColor
                clip: true
                Layout.alignment: Qt.AlignVCenter

                Image {
                    anchors.fill: parent
                    source: lvm.selectedArtSquare !== "" ? lvm.selectedArtSquare
                          : lvm.selectedArtCover  !== "" ? lvm.selectedArtCover : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: source !== ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Kirigami.Heading {
                    text: lvm.selectedTitle
                    level: 2
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Controls.Label {
                    text: lvm.selectedDeveloper
                    opacity: 0.7
                }
                // Platform chips
                RowLayout {
                    spacing: 4
                    visible: lvm.selectedPlatforms !== ""
                    Repeater {
                        model: lvm.selectedPlatforms.split(",").map(s => s.trim())
                        delegate: Rectangle {
                            required property string modelData
                            radius: 4
                            color: Kirigami.Theme.highlightColor
                            implicitWidth: platformLabel.implicitWidth + 10
                            implicitHeight: platformLabel.implicitHeight + 4
                            Controls.Label {
                                id: platformLabel
                                anchors.centerIn: parent
                                text: modelData
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                color: Kirigami.Theme.highlightedTextColor
                            }
                        }
                    }
                }
                Controls.Label {
                    visible: lvm.selectedIsInstalled
                    text: qsTr("Installed") + (lvm.selectedInstallPath !== ""
                          ? " · " + lvm.selectedInstallPath : "")
                    color: Kirigami.Theme.positiveTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        ColumnLayout {
            width: parent.width
            spacing: Kirigami.Units.largeSpacing

            // Size info row (shown while loading or when data is available)
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                visible: !lvm.selectedIsInstalled && (lvm.detailsLoading || lvm.detailsDownloadSize !== "" || lvm.detailsDiskSize !== "")

                Controls.BusyIndicator {
                    visible: lvm.detailsLoading
                    running: lvm.detailsLoading
                    implicitWidth: 24
                    implicitHeight: 24
                }

                // Download size
                RowLayout {
                    visible: lvm.detailsDownloadSize !== ""
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: "download"
                        implicitWidth: 20
                        implicitHeight: 20
                    }
                    ColumnLayout {
                        spacing: 0
                        Controls.Label {
                            text: qsTr("Download Size")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.7
                        }
                        Controls.Label {
                            text: lvm.detailsDownloadSize
                            font.bold: true
                        }
                    }
                }

                // Install size
                RowLayout {
                    visible: lvm.detailsDiskSize !== ""
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: "drive-harddisk"
                        implicitWidth: 20
                        implicitHeight: 20
                    }
                    ColumnLayout {
                        spacing: 0
                        Controls.Label {
                            text: qsTr("Install Size")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.7
                        }
                        Controls.Label {
                            text: lvm.detailsDiskSize
                            font.bold: true
                        }
                    }
                }
            }

            // Wine picker (macOS only, for Windows games)
            ColumnLayout {
                visible: lvm.wineInstallationNames !== "" && lvm.selectedPlatforms.indexOf("Windows") !== -1
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    text: qsTr("Wine / Compatibility Layer")
                    level: 4
                }

                Controls.ComboBox {
                    id: winePicker
                    Layout.fillWidth: true
                    model: lvm.wineInstallationNames !== ""
                           ? lvm.wineInstallationNames.split("|||")
                           : []
                    currentIndex: lvm.selectedWineIndex
                    onActivated: lvm.selectWine(currentIndex)
                }
            }

            // Busy indicator while detecting wine
            RowLayout {
                visible: lvm.wineDetecting && lvm.selectedPlatforms.indexOf("Windows") !== -1
                spacing: Kirigami.Units.smallSpacing
                Controls.BusyIndicator {
                    running: lvm.wineDetecting
                    implicitWidth: 20
                    implicitHeight: 20
                }
                Controls.Label {
                    text: qsTr("Detecting Wine installations…")
                    opacity: 0.7
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }

            // Import section — only for uninstalled games
            ColumnLayout {
                visible: !lvm.selectedIsInstalled
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    text: qsTr("Import Existing Installation")
                    level: 4
                }

                Controls.Label {
                    text: qsTr("If you already have this game installed via the Epic Games Launcher, "
                               + "point Relic at the install folder to register it without re-downloading.")
                    wrapMode: Text.Wrap
                    opacity: 0.8
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Controls.TextField {
                        id: importPathField
                        placeholderText: qsTr("Path to install folder…")
                        Layout.fillWidth: true
                    }

                    Controls.Button {
                        text: qsTr("Browse…")
                        icon.name: "document-open-folder"
                        onClicked: folderDialog.open()
                    }
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: lvm.importError !== ""
                    type: Kirigami.MessageType.Error
                    text: lvm.importError
                }

                Controls.Button {
                    text: lvm.isImporting ? qsTr("Importing…") : qsTr("Import Game")
                    icon.name: "document-import"
                    enabled: importPathField.text.trim() !== "" && !lvm.isImporting
                    Layout.alignment: Qt.AlignRight
                    onClicked: lvm.importGame(lvm.selectedAppName, importPathField.text.trim())
                }
            }

            // Launch section — only for installed games
            ColumnLayout {
                visible: lvm.selectedIsInstalled
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing


                // Launch error message
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: lvm.launchError !== ""
                    type: Kirigami.MessageType.Error
                    text: lvm.launchError
                }

                // Launch button row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing

                    Controls.Button {
                        text: lvm.isLaunching ? qsTr("Launching…") : qsTr("Launch")
                        icon.name: "media-playback-start"
                        enabled: !lvm.isLaunching
                        onClicked: lvm.launchGame(lvm.selectedAppName)
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    // Folder picker for import path
    FolderDialog {
        id: folderDialog
        onAccepted: importPathField.text = selectedFolder.toString().replace("file://", "")
    }

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
            required property string appName
            required property bool isInstalled
            required property string artSquare
            required property string artCover
            required property string platforms

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
                        onClicked: lvm.selectGame(appName)
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

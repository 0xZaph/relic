import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: aboutPage
    title: "About"

    property var viewModel

    Controls.Label {
        anchors.centerIn: parent
        text: "Relic - A Native Epic Games Client"
    }
}

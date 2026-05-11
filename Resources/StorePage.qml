import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtWebView
import org.kde.kirigami as Kirigami

Kirigami.Page {
    id: storePage
    title: "Store"
    padding: 0
    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0
    property var viewModel

    WebView {
        anchors.fill: parent
        url: "https://store.epicgames.com/"
    }
}

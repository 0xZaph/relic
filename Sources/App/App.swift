import Foundation
import KirigamiSupport
import QtBridge

@main
struct relic: QApp {
    var requiresQtWidgets: Bool { true }

    let qmlFileName: String = "main"
    var initialProperties: [String : QtBridge.QObjectBuildable] = {
        ["viewModel": AppViewModel()]
    }()

    func preApplicationCreate() {
        QMLApp.setOrganizationName("Zaph")
        QMLApp.setOrganizationDomain("xyz.zaph.relic")
        QMLApp.setApplicationName("Relic")
        QMLApp.setDesktopFileName("xyz.zaph.relic")

        setupKirigamiPreApp()
    }

    func postApplicationCreate() {
        QMLApp.setStyle("breeze")
        setupKirigamiPostApp()
    }

    func engineDidCreate(enginePointer: UnsafeMutableRawPointer) {
        setupKirigamiEngine(enginePointer)
    }
}

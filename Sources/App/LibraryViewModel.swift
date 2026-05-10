import Foundation
import QtBridge
import LegendaryKit
import EpicKit

@MainActor
@QtBridgeable
public final class LibraryGame {
    public var appName: String
    public var title: String
    public var developer: String
    public var artCover: String
    public var artSquare: String
    public var artLogo: String
    public var gameDescription: String
    public var isInstalled: Bool
    public var installPath: String

    public init(
        appName: String,
        title: String,
        developer: String,
        artCover: String,
        artSquare: String,
        artLogo: String,
        gameDescription: String,
        isInstalled: Bool,
        installPath: String
    ) {
        self.appName = appName
        self.title = title
        self.developer = developer
        self.artCover = artCover
        self.artSquare = artSquare
        self.artLogo = artLogo
        self.gameDescription = gameDescription
        self.isInstalled = isInstalled
        self.installPath = installPath
    }

    public convenience init(from info: GameInfo) {
        self.init(
            appName: info.appName,
            title: info.title,
            developer: info.developer ?? "",
            artCover: info.artCover ?? "",
            artSquare: info.artSquare ?? "",
            artLogo: info.artLogo ?? "",
            gameDescription: info.description ?? "",
            isInstalled: info.isInstalled,
            installPath: info.installPath ?? ""
        )
    }
}

@MainActor
@QtBridgeable
public final class LibraryViewModel {
    private let library: Library

    @QtTracked public var games: QListModel<LibraryGame> = []
    public var statusMessage: String = ""
    public var errorMessage: String = ""
    public var isRefreshing: Bool = false

    public init() {
        self.library = Library(autoRefresh: false)
        print("[LibraryViewModel] init")
        reloadFromCache()
    }

    public func reloadFromCache() {
        print("[LibraryViewModel] reloadFromCache")
        let loadedGames = library.getListOfGames()
            .map { LibraryGame(from: $0) }

        games = QListModel(loadedGames)
        statusMessage = loadedGames.isEmpty
            ? "No cached games found"
            : "Loaded \(loadedGames.count) game\(loadedGames.count == 1 ? "" : "s")"
        print("[LibraryViewModel] loaded \(loadedGames.count) games")
    }

    public func refreshLibrary() {
        print("[LibraryViewModel] refreshLibrary requested")
        Task {
            isRefreshing = true
            statusMessage = "Refreshing library..."

            do {
                try await library.refreshLegendary()
                reloadFromCache()
                errorMessage = ""
                print("[LibraryViewModel] refreshLibrary success")
            } catch {
                errorMessage = "Library refresh failed: \(error.localizedDescription)"
                statusMessage = "Refresh failed"
                if let apiError = error as? EPCAPIError {
                    print("[LibraryViewModel] refreshLibrary failed with EPCAPIError: \(apiError)")
                }
                print("[LibraryViewModel] refreshLibrary failed: \(error.localizedDescription)")
            }

            isRefreshing = false
        }
    }
}

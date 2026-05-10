import EpicKit
import Foundation
import LegendaryKit
import QtBridge

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
    public var platforms: String

    public init(
        appName: String,
        title: String,
        developer: String,
        artCover: String,
        artSquare: String,
        artLogo: String,
        gameDescription: String,
        isInstalled: Bool,
        installPath: String,
        platforms: String
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
        self.platforms = platforms
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
            installPath: info.installPath ?? "",
            platforms: info.platformVersions.keys.sorted().joined(separator: ", ")
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

    // Selected game state — flat scalars because QtBridge can't register optional @QtBridgeable as a property
    public var hasSelectedGame: Bool = false
    public var selectedAppName: String = ""
    public var selectedTitle: String = ""
    public var selectedDeveloper: String = ""
    public var selectedArtSquare: String = ""
    public var selectedArtCover: String = ""
    public var selectedIsInstalled: Bool = false
    public var selectedInstallPath: String = ""
    public var selectedPlatforms: String = ""

    // Manifest-derived details (loaded on demand)
    public var detailsLoading: Bool = false
    public var detailsDiskSize: String = ""  // formatted e.g. "4.25 GiB"
    public var detailsDownloadSize: String = ""  // formatted e.g. "2.5 GiB"
    public var detailsBuildVersion: String = ""
    public var detailsNumFiles: Int = 0
    public var detailsNumChunks: Int = 0

    public var importError: String = ""
    public var isImporting: Bool = false

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
        statusMessage =
            loadedGames.isEmpty
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

    // Called from QML with the appName string from the delegate
    public func selectGame(appName: String) {
        guard let game = games.asArray.first(where: { $0.appName == appName }) else { return }
        selectedAppName = game.appName
        selectedTitle = game.title
        selectedDeveloper = game.developer
        selectedArtSquare = game.artSquare
        selectedArtCover = game.artCover
        selectedIsInstalled = game.isInstalled
        selectedInstallPath = game.installPath
        selectedPlatforms = game.platforms
        importError = ""
        // Clear stale details
        detailsDiskSize = ""
        detailsDownloadSize = ""
        detailsBuildVersion = ""
        detailsNumFiles = 0
        detailsNumChunks = 0
        hasSelectedGame = true  // set last — QML watches this to open the sheet
        // Kick off details fetch
        loadGameDetails(appName: appName)
    }

    public func loadGameDetails(appName: String) {
        Task {
            detailsLoading = true
            do {
                let details = try await library.getGameDetails(appName: appName)
                detailsDiskSize = details.diskSize > 0 ? formatBytes(details.diskSize) : ""
                detailsDownloadSize =
                    details.downloadSize > 0 ? formatBytes(details.downloadSize) : ""
                detailsBuildVersion = details.buildVersion
                detailsNumFiles = details.numFiles
                detailsNumChunks = details.numChunks
            } catch {
                print("[LibraryViewModel] loadGameDetails failed for \(appName): \(error)")
            }
            detailsLoading = false
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gib = Double(bytes) / (1024 * 1024 * 1024)
        if gib >= 1 { return String(format: "%.2f GiB", gib) }
        let mib = Double(bytes) / (1024 * 1024)
        return String(format: "%.1f MiB", mib)
    }

    public func clearSelectedGame() {
        hasSelectedGame = false
        selectedAppName = ""
        selectedTitle = ""
        selectedDeveloper = ""
        selectedArtSquare = ""
        selectedArtCover = ""
        selectedIsInstalled = false
        selectedInstallPath = ""
        selectedPlatforms = ""
        detailsDiskSize = ""
        detailsDownloadSize = ""
        detailsBuildVersion = ""
        detailsNumFiles = 0
        detailsNumChunks = 0
        importError = ""
    }

    public func importGame(appName: String, installPath: String) {
        Task {
            isImporting = true
            importError = ""
            do {
                try await library.importGame(appName: appName, installPath: installPath)
                reloadFromCache()
                clearSelectedGame()
                print("[LibraryViewModel] importGame success: \(appName)")
            } catch {
                importError = error.localizedDescription
                print("[LibraryViewModel] importGame failed: \(error.localizedDescription)")
            }
            isImporting = false
        }
    }
}

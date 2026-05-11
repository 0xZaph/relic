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

    // Launch / dry-run state
    public var isLaunching: Bool = false
    public var launchError: String = ""
    public var launchOutput: String = ""   // dry-run result shown in UI

    // Wine detection
    public var wineDetecting: Bool = false
    /// Comma-separated list of detected wine installation names (for QML display).
    public var wineInstallationNames: String = ""
    /// Comma-separated list of detected wine binary paths (parallel to names).
    public var wineInstallationBins: String = ""
    /// Index into the detected wine list that is currently selected.
    public var selectedWineIndex: Int = 0

    // Backing store — not exposed to QML directly
    private var detectedWineInstallations: [WineInstallation] = []

    public init() {
        self.library = Library(autoRefresh: false)
        print("[LibraryViewModel] init")
        Task {
            await self.library.initializeCache(autoRefresh: false)
            self.reloadFromCache()
        }
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
        launchError = ""
        launchOutput = ""
        // Clear stale details
        detailsDiskSize = ""
        detailsDownloadSize = ""
        detailsBuildVersion = ""
        detailsNumFiles = 0
        detailsNumChunks = 0
        hasSelectedGame = true  // set last — QML watches this to open the sheet
        // Kick off details fetch
        loadGameDetails(appName: appName)
        // Detect wine installations for all games (macOS only)
        detectWineInstallations()
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
        launchError = ""
        launchOutput = ""
        wineInstallationNames = ""
        wineInstallationBins = ""
        selectedWineIndex = 0
        detectedWineInstallations = []
    }

    // MARK: - Wine Detection

    public func detectWineInstallations() {
        Task {
            wineDetecting = true
            let detector = WineDetector()
            let installations = await detector.detectAll()
            detectedWineInstallations = installations
            wineInstallationNames = installations.map { $0.name }.joined(separator: "|||")
            wineInstallationBins  = installations.map { $0.bin  }.joined(separator: "|||")
            selectedWineIndex = 0
            wineDetecting = false
            print("[LibraryViewModel] Detected \(installations.count) wine installation(s)")
            for (i, w) in installations.enumerated() {
                print("  [\(i)] \(w.name) (\(w.type.rawValue)) → \(w.bin)")
            }
        }
    }

    // MARK: - Game Launch

    /// Resolves all launch parameters, fetches an authentication token, and starts the game process.
    public func launchGame(appName: String) {
        Task {
            isLaunching = true
            launchError = ""
            launchOutput = ""

            // Pick the selected wine binary (if any detected)
            let wineBin: String? = {
                guard !detectedWineInstallations.isEmpty,
                      selectedWineIndex < detectedWineInstallations.count
                else { return nil }
                return detectedWineInstallations[selectedWineIndex].bin
            }()

            // CrossOver bottle: if the selected wine is CrossOver, pass its bottle
            let crossoverApp: String? = {
                guard !detectedWineInstallations.isEmpty,
                      selectedWineIndex < detectedWineInstallations.count,
                      detectedWineInstallations[selectedWineIndex].type == .crossover
                else { return nil }
                let bin = detectedWineInstallations[selectedWineIndex].bin
                var current = URL(fileURLWithPath: bin)
                while current.path != "/" && current.pathExtension != "app" {
                    current = current.deletingLastPathComponent()
                }
                return current.pathExtension == "app" ? current.path : nil
            }()

            do {
                print("[LibraryViewModel] Fetching session info for launch...")
                let session = try await library.getSessionInfo()
                print("[LibraryViewModel] Fetching exchange code...")
                let exchangeCode = try await library.getExchangeCode()

                print("[LibraryViewModel] Resolving launch parameters for \(appName)...")
                let params = try library.getLaunchParameters(
                    appName: appName,
                    offline: false,
                    gameToken: exchangeCode,
                    accountId: session.accountId,
                    userName: session.displayName,
                    wineBin: crossoverApp != nil ? nil : wineBin,
                    crossoverApp: crossoverApp
                )

                print("[LibraryViewModel] Spawning game process...")
                try library.launchGame(params: params)
                print("[LibraryViewModel] Game launched successfully")

                // Optional: show a message or just close the sheet
                launchOutput = "Game launched!"
            } catch {
                launchError = error.localizedDescription
                print("[LibraryViewModel] launchGame failed: \(error.localizedDescription)")
            }

            isLaunching = false
        }
    }

    /// Called from QML to change the selected wine installation by index.
    public func selectWine(index: Int) {
        guard index >= 0 && index < detectedWineInstallations.count else { return }
        selectedWineIndex = index
    }

    public func importGame(appName: String, installPath: String) {
        Task {
            isImporting = true
            importError = ""
            do {
                try await library.importGame(appName: appName, installPath: installPath, withDlcs: true)
                reloadFromCache()

                if let game = games.asArray.first(where: { $0.appName == appName }) {
                    game.isInstalled = true
                }

                selectedIsInstalled = true
                print("[LibraryViewModel] importGame success: \(appName)")
            } catch {
                importError = error.localizedDescription
                print("[LibraryViewModel] importGame failed: \(error.localizedDescription)")
            }
            isImporting = false
        }
    }
}
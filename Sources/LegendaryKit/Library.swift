import Foundation
import EpicKit

public class Library {
    private let store: LegendaryFS
    private let timeout: Int
    // In-memory stores
    private var allGames: Set<String> = []
    private var installedGames: [String: Legendary.InstalledJsonMetadata] = [:]
    private var library: [String: Legendary.GameMetadata] = [:]
    // Asset cache (mirrors legendary's get_assets caching)
    private var assetCache: [String: [GameAssetRecord]] = [:]

    public init(autoRefresh: Bool = true) {
        self.store = try! LegendaryFS()
        self.timeout = 10

        Task { [weak self] in
            guard let self else { return }
            await self.loadCachedLibrary()
            if autoRefresh {
                _ = try? await self.refreshLegendary()
            }
        }
    }

    private func loadCachedLibrary() async {
        loadGamesInAccount()
        await refreshInstalled()
        _ = loadAll()
    }

    private func cachedClient() async throws -> EpicClient {
        guard let savedSession = try await store.loadUserSession() else {
            throw EPCAPIError.invalidCredentials("No saved credentials found.")
        }

        return EpicClient(timeout: timeout, authData: savedSession)
    }

    private static var assetPlatforms: [String] {
        #if os(macOS)
            return ["Windows", "Mac"]
        #else
            return ["Windows"]
        #endif
    }

    /// Get cached assets for a platform, fetching from API if not cached
    /// Mirrors legendary's get_assets() caching behavior
    private func getAssets(
        platform: String,
        updateAssets: Bool = false,
        client: EpicClient
    ) async throws -> [GameAssetRecord] {
        // Return cached assets if available and not forcing update
        if !updateAssets && assetCache[platform] != nil {
            return assetCache[platform]!
        }

        // Fetch from API
        let assets = try await client.getGameAssets(platform: platform)
        
        // Cache the result
        assetCache[platform] = assets
        
        return assets
    }

    private func gameInfoDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func loadCatalogGameInfo(
        client: EpicClient,
        namespace: String,
        catalogItemId: String,
        appName: String,
        platform: String
    ) async throws -> Legendary.GameMetadataInner? {
        let responseData = try await client.getGameInfo(
            namespace: namespace,
            catalogItemId: catalogItemId,
            appName: appName,
            platform: platform
        )

        let decoder = gameInfoDecoder()
        
        // Try multiple response formats
        // First, try as a dictionary with items key
        if let dict = try? decoder.decode([String: [String: Legendary.GameMetadataInner]].self, from: responseData),
           let items = dict["items"],
           let metadata = items[catalogItemId] {
            return metadata
        }
        
        // Try as direct items dictionary
        if let dict = try? decoder.decode([String: Legendary.GameMetadataInner].self, from: responseData),
           let metadata = dict[catalogItemId] {
            return metadata
        }
        
        // Try as a single metadata object (for non-DLC items)
        if let metadata = try? decoder.decode(Legendary.GameMetadataInner.self, from: responseData) {
            return metadata
        }
        
        print("[Library] Could not decode game info for \(appName)")
        return nil
    }

    private func buildGameMetadata(
        appName: String,
        assetsByPlatform: [String: GameAssetRecord],
        client: EpicClient
    ) async throws -> Legendary.GameMetadata? {
        let selectedAsset: (platform: String, asset: GameAssetRecord)
        if let windowsAsset = assetsByPlatform["Windows"] {
            selectedAsset = (platform: "Windows", asset: windowsAsset)
        } else if let firstAsset = assetsByPlatform.first {
            selectedAsset = (platform: firstAsset.key, asset: firstAsset.value)
        } else {
            return nil
        }

        guard let metadata = try await loadCatalogGameInfo(
            client: client,
            namespace: selectedAsset.asset.namespace,
            catalogItemId: selectedAsset.asset.catalogItemId,
            appName: appName,
            platform: selectedAsset.platform
        ) else {
            return nil
        }

        let title = metadata.title ?? appName

        let assetInfos = assetsByPlatform.reduce(into: [String: Legendary.AssetInfo]()) { partialResult, entry in
            let (platform, asset) = entry
            partialResult[platform] = Legendary.AssetInfo(
                appName: asset.appName,
                assetId: asset.assetId,
                buildVersion: asset.buildVersion,
                catalogItemId: asset.catalogItemId,
                labelName: asset.labelName,
                metadata: asset.metadata?.mapValues { Legendary.AnyCodable($0.value) } ?? [:],
                namespace: asset.namespace
            )
        }

        return Legendary.GameMetadata(
            appName: appName,
            appTitle: title,
            assetInfos: assetInfos,
            baseUrls: [],
            metadata: metadata
        )
    }

    // MARK: - Refresh Legendary Library (native API, updates metadata)
    public func refreshLegendary() async throws {
        let client = try await cachedClient()
        var assetMap: [String: [String: GameAssetRecord]] = [:]
        var fetchedAppNames = Set<String>()

        // Fetch assets for each platform with caching
        for platform in Self.assetPlatforms {
            do {
                let assets = try await getAssets(platform: platform, updateAssets: true, client: client)
                for asset in assets {
                    assetMap[asset.appName, default: [:]][platform] = asset
                    fetchedAppNames.insert(asset.appName)
                }
            } catch {
                print("[Library] Failed to get assets for platform \(platform): \(error)")
                throw error
            }
        }

        let libraryItems: [LibraryItemRecord]
        do {
            libraryItems = try await client.getLibraryItems()
        } catch {
            print("[Library] Failed to get library items: \(error)")
            throw error
        }

        for item in libraryItems {
            guard let appName = item.appName, !appName.isEmpty else {
                continue
            }
            guard item.namespace.lowercased() != "ue" else {
                continue
            }
            guard item.sandboxType?.uppercased() != "PRIVATE" else {
                continue
            }
            if assetMap[appName] == nil {
                fetchedAppNames.insert(appName)
            }
        }

        let appNamesToRefresh = Set(assetMap.keys).union(fetchedAppNames)
        // Fetch and save metadata for all games concurrently instead of serially
        await withTaskGroup(of: Void.self) { group in
            for appName in appNamesToRefresh {
                if let assetsByPlatform = assetMap[appName],
                   assetsByPlatform.values.contains(where: { $0.namespace.lowercased() == "ue" }) {
                    continue
                }
                group.addTask {
                    if let assetsByPlatform = assetMap[appName] {
                        do {
                            if let game = try await self.buildGameMetadata(appName: appName, assetsByPlatform: assetsByPlatform, client: client) {
                                try await self.store.saveGameMetadata(game)
                            }
                        } catch {
                            print("[Library] Failed to build/save metadata for \(appName): \(error)")
                        }
                        return
                    }

                    guard let item = libraryItems.first(where: { $0.appName == appName }) else {
                        return
                    }

                    do {
                        guard let metadata = try await self.loadCatalogGameInfo(
                            client: client,
                            namespace: item.namespace,
                            catalogItemId: item.catalogItemId,
                            appName: appName,
                            platform: "Windows"
                        ) else {
                            return
                        }
                        let title = metadata.title ?? appName
                        let game = Legendary.GameMetadata(
                            appName: appName,
                            appTitle: title,
                            assetInfos: [:],
                            baseUrls: [],
                            metadata: metadata
                        )
                        try await self.store.saveGameMetadata(game)
                    } catch {
                        print("[Library] Failed to load catalog info for \(appName): \(error)")
                    }
                }
            }
        }

        pruneMetadata(keeping: appNamesToRefresh)
        await loadCachedLibrary()
    }

    // MARK: - Load all games in account (scan metadata dir)
    public func loadGamesInAccount() {
        allGames.removeAll()
        let metadataDir = legendaryMetadata()
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: metadataDir) else {
            return
        }
        for file in files where file.hasSuffix(".json") {
            let appName = file.replacingOccurrences(of: ".json", with: "")
            allGames.insert(appName)
        }
    }

    private func pruneMetadata(keeping appNames: Set<String>) {
        let metadataDir = legendaryMetadata()
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: metadataDir) else {
            return
        }

        for file in files where file.hasSuffix(".json") {
            let appName = String(file.dropLast(5))
            if !appNames.contains(appName) {
                let fileURL = URL(fileURLWithPath: metadataDir).appendingPathComponent(file)
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    // MARK: - Refresh installed games (read installed.json via LegendaryFS)
    public func refreshInstalled() async {
        installedGames = (try? await store.loadInstalledGames()) ?? [:]
    }

    // MARK: - Load a single game’s metadata
    public func loadFile(_ appName: String) -> Bool {
        let filePath = URL(fileURLWithPath: legendaryMetadata()).appendingPathComponent("\(appName).json")
        guard let data = try? Data(contentsOf: filePath) else { return false }
        guard let meta = try? JSONDecoder().decode(Legendary.GameMetadata.self, from: data) else {
            return false
        }
        library[appName] = meta
        return true
    }

    // MARK: - Load all games’ metadata into memory
    public func loadAll() -> [String] {
        library.removeAll()
        var loaded: [String] = []
        for appName in allGames {
            if loadFile(appName) {
                loaded.append(appName)
            }
        }
        return loaded
    }

    // MARK: - List all games (returns GameInfo)
    public func getListOfGames() -> [GameInfo] {
        let games = library.values.compactMap { meta -> GameInfo? in
            let appName = meta.appName
            // Filter: Unreal Engine / Quixel / Fab marketplace items
            if meta.assetInfos.values.contains(where: { $0.namespace.lowercased() == "ue" }) {
                return nil
            }
            let categories = meta.metadata.categories ?? []
            // Filter: DLC (has a parent game)
            if meta.metadata.mainGameItem != nil {
                return nil
            }
            // Filter: mods
            if categories.contains(where: { $0.path == "mods" }) {
                return nil
            }
            // Filter: launchable addons (e.g. Quixel Bridge, Fab)
            if categories.contains(where: { $0.path == "addons/launchable" }) {
                return nil
            }
            let title = meta.appTitle
            let developer = meta.metadata.developer
            let keyImages = meta.metadata.keyImages ?? []
            let artCover = keyImages.first(where: { $0.type == "DieselGameBox" })?.url
            let artSquare =
                keyImages.first(where: { $0.type == "DieselGameBoxTall" })?.url ??
                keyImages.first(where: { $0.type == "DieselStoreFrontTall" })?.url
            let artLogo = keyImages.first(where: { $0.type == "DieselGameBoxLogo" })?.url
            let description = meta.metadata.description
            let isInstalled = installedGames[appName] != nil
            let installPath = installedGames[appName]?.installPath
            let platformVersions = meta.assetInfos.mapValues { $0.buildVersion }
            return GameInfo(
                appName: appName,
                title: title,
                developer: developer,
                artCover: artCover,
                artSquare: artSquare,
                artLogo: artLogo,
                description: description,
                isInstalled: isInstalled,
                installPath: installPath,
                platformVersions: platformVersions
            )
        }.sorted { game1, game2 in
            // Installed games first
            if game1.isInstalled != game2.isInstalled {
                return game1.isInstalled
            }
            // Then alphabetically by title
            return game1.title.localizedCaseInsensitiveCompare(game2.title) == .orderedAscending
        }
        return games
    }

    // MARK: - Get game info (loads if not present)
    public func getGameInfo(_ appName: String, forceReload: Bool = false) -> GameInfo? {
        if forceReload || library[appName] == nil {
            _ = loadFile(appName)
        }
        guard let meta = library[appName] else { return nil }
        let developer = meta.metadata.developer
        let keyImages = meta.metadata.keyImages ?? []
        let artCover = keyImages.first(where: { $0.type == "DieselGameBox" })?.url
        let artSquare =
            keyImages.first(where: { $0.type == "DieselGameBoxTall" })?.url ??
            keyImages.first(where: { $0.type == "DieselStoreFrontTall" })?.url
        let artLogo = keyImages.first(where: { $0.type == "DieselGameBoxLogo" })?.url
        let description = meta.metadata.description
        return GameInfo(
            appName: meta.appName,
            title: meta.appTitle,
            developer: developer,
            artCover: artCover,
            artSquare: artSquare,
            artLogo: artLogo,
            description: description,
            isInstalled: installedGames[meta.appName] != nil,
            installPath: installedGames[meta.appName]?.installPath
        )
    }

    // MARK: - Installed game management (write path)

    /// Record a game as installed. Updates installed.json and the in-memory cache.
    public func markGameInstalled(_ metadata: Legendary.InstalledJsonMetadata) async throws {
        try await store.saveInstalledGame(metadata.appName, metadata)
        installedGames[metadata.appName] = metadata
    }

    /// Remove a game from the installed registry. Updates installed.json and the in-memory cache.
    public func markGameUninstalled(_ appName: String) async throws {
        try await store.removeInstalledGame(appName)
        installedGames.removeValue(forKey: appName)
    }

    // MARK: - Game details (manifest-derived via legendary subprocess)

    /// Fetches manifest info for a game using `legendary info --json`.
    /// Returns disk size, download size, build version, launch exe, file/chunk counts.
    public func getGameDetails(appName: String, platform: String = "Windows") async throws -> GameDetails {
        guard library[appName] != nil else {
            throw ImportError.gameNotFound(appName)
        }

        let legendaryPlatform = LegendaryPlatform(rawValue: platform) ?? .windows
        let command = LegendaryCommand.info(InfoCommandOptions(appName: appName, platform: legendaryPlatform))
        let binaryPath = legendaryBinaryPath()

        // Run on a background thread so we don't block the main actor
        let result = try await Task.detached(priority: .userInitiated) {
            let runner = LegendaryRunner(legendaryPath: binaryPath)
            return try await runner.run(command)
        }.value

        // legendary writes JSON to stdout; stderr has log lines we can ignore
        guard !result.standardOutput.isEmpty else {
            throw ImportError.gameNotFound(appName)
        }
        let data = Data(result.standardOutput.utf8)

        let decoder = JSONDecoder()
        let info = try decoder.decode(LegendaryInfoOutput.self, from: data)

        guard let manifest = info.manifest else {
            // No manifest data — game may not be available on this platform
            throw ImportError.gameNotFound(appName)
        }

        return GameDetails(
            appName: appName,
            buildVersion: manifest.buildVersion,
            diskSize: manifest.diskSize,
            downloadSize: manifest.downloadSize,
            launchExe: manifest.launchExe,
            numFiles: manifest.numFiles,
            numChunks: manifest.numChunks,
            platform: platform
        )
    }

    public enum ImportError: Error, LocalizedError {
        case gameNotFound(String)
        case pathDoesNotExist(String)
        case alreadyInstalled(String)

        public var errorDescription: String? {
            switch self {
            case .gameNotFound(let name):   return "Game '\(name)' not found in your library."
            case .pathDoesNotExist(let p):  return "Path does not exist: \(p)"
            case .alreadyInstalled(let n):  return "'\(n)' is already registered as installed."
            }
        }
    }

    /// Import an already-installed game by pointing at its install directory.
    ///
    /// Mirrors legendary's `import_game` logic:
    /// - If `.egstore/<appName>.mancpn` exists and there is no `.egstore/bps` in-progress marker,
    ///   the install is assumed complete and `needsVerification` is set to `false`.
    /// - Otherwise `needsVerification = true` so the user knows a repair pass is needed.
    /// - Manifest fields (version, executable, launch params) are read from `.egstore` when
    ///   available; otherwise sensible defaults are used.
    public func importGame(appName: String, installPath: String, platform: String = "Windows") async throws {
        let path = URL(fileURLWithPath: installPath)

        guard FileManager.default.fileExists(atPath: path.path) else {
            throw ImportError.pathDoesNotExist(installPath)
        }

        guard library[appName] != nil else {
            throw ImportError.gameNotFound(appName)
        }

        if installedGames[appName] != nil {
            throw ImportError.alreadyInstalled(library[appName]?.appTitle ?? appName)
        }

        // --- Probe .egstore for EGL manifest metadata ---
        var needsVerification = true
        var version = "0"
        let executable = ""
        let launchParameters = ""

        let egstoreURL = path.appendingPathComponent(".egstore")
        if FileManager.default.fileExists(atPath: egstoreURL.path) {
            // Look for a .mancpn file matching this appName
            let mancpnURL = try? FileManager.default.contentsOfDirectory(
                at: egstoreURL,
                includingPropertiesForKeys: nil
            ).first(where: { $0.pathExtension == "mancpn" })

            if let mancpnURL,
               let mancpnData = try? Data(contentsOf: mancpnURL),
               let mancpn = try? JSONSerialization.jsonObject(with: mancpnData) as? [String: Any],
               (mancpn["AppName"] as? String) == appName {

                // Read version from mancpn if present
                if let v = mancpn["BuildVersion"] as? String { version = v }

                // No in-progress installation marker → assume complete
                let bpsURL = egstoreURL.appendingPathComponent("bps")
                let pendingURL = egstoreURL.appendingPathComponent("Pending")
                let hasBps = FileManager.default.fileExists(atPath: bpsURL.path)
                let hasPending: Bool = {
                    guard let contents = try? FileManager.default.contentsOfDirectory(atPath: pendingURL.path) else { return false }
                    return !contents.isEmpty
                }()
                needsVerification = hasBps || hasPending
            }
        }

        // Derive install size from disk usage (best-effort)
        let installSize: Int64 = {
            guard let enumerator = FileManager.default.enumerator(
                at: path,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { return 0 }
            var total: Int64 = 0
            for case let fileURL as URL in enumerator {
                total += Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
            return total
        }()

        let meta = Legendary.InstalledJsonMetadata(
            appName: appName,
            baseUrls: [],
            canRunOffline: library[appName]?.metadata.customAttributes?["CanRunOffline"]?.value == "true",
            eglGuid: "",
            executable: executable,
            installPath: installPath,
            installSize: installSize,
            installTags: [],
            isDlc: library[appName]?.metadata.mainGameItem != nil,
            launchParameters: launchParameters,
            manifestPath: nil,
            needsVerification: needsVerification,
            platform: Legendary.LegendaryInstallPlatform(rawValue: platform) ?? .windows,
            prereqInfo: nil,
            requiresOt: library[appName]?.metadata.customAttributes?["OwnershipToken"]?.value.lowercased() == "true",
            savePath: nil,
            title: library[appName]?.appTitle ?? appName,
            version: version
        )

        try await markGameInstalled(meta)
        print("[Library] Imported '\(appName)' from \(installPath) (needsVerification: \(needsVerification))")
    }
}

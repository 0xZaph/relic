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
        loadCachedLibrary()

        if autoRefresh {
            Task { [weak self] in
                guard let self else { return }
                _ = try? await self.refreshLegendary()
            }
        }
    }

    private func loadCachedLibrary() {
        loadGamesInAccount()
        refreshInstalled()
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
        loadCachedLibrary()
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

    // MARK: - Refresh installed games (read installed.json)
    public func refreshInstalled() {
        installedGames.removeAll()
        let installedPath = legendaryInstalled()
        guard let data = try? Data(contentsOf: installedPath) else {
            return
        }
        
        do {
            let dict = try JSONDecoder().decode([String: Legendary.InstalledJsonMetadata].self, from: data)
            installedGames = dict
        } catch {
            // ignore decode errors
        }
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
            return GameInfo(
                appName: appName,
                title: title,
                developer: developer,
                artCover: artCover,
                artSquare: artSquare,
                artLogo: artLogo,
                description: description,
                isInstalled: isInstalled,
                installPath: installPath
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
}

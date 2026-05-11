import EpicKit
import Foundation

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
    }

    public func initializeCache(autoRefresh: Bool = true) async {
        await self.loadCachedLibrary()
        if autoRefresh {
            _ = try? await self.refreshLegendary()
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

    public func getExchangeCode() async throws -> String {
        var client = try await cachedClient()
        return try await client.getExchangeCode()
    }

    public func getSessionInfo() async throws -> (accountId: String, displayName: String) {
        let client = try await cachedClient()
        guard let auth = client.authData else {
            throw EPCAPIError.noTokenProvided
        }
        return (auth.accountId ?? "", auth.displayName ?? "")
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
        if let dict = try? decoder.decode(
            [String: [String: Legendary.GameMetadataInner]].self, from: responseData),
            let items = dict["items"],
            let metadata = items[catalogItemId]
        {
            return metadata
        }

        // Try as direct items dictionary
        if let dict = try? decoder.decode(
            [String: Legendary.GameMetadataInner].self, from: responseData),
            let metadata = dict[catalogItemId]
        {
            return metadata
        }

        // Try as a single metadata object (for non-DLC items)
        if let metadata = try? decoder.decode(Legendary.GameMetadataInner.self, from: responseData)
        {
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

        guard
            let metadata = try await loadCatalogGameInfo(
                client: client,
                namespace: selectedAsset.asset.namespace,
                catalogItemId: selectedAsset.asset.catalogItemId,
                appName: appName,
                platform: selectedAsset.platform
            )
        else {
            return nil
        }

        let title = metadata.title ?? appName

        let assetInfos = assetsByPlatform.reduce(into: [String: Legendary.AssetInfo]()) {
            partialResult, entry in
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
                let assets = try await getAssets(
                    platform: platform, updateAssets: true, client: client)
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
                    assetsByPlatform.values.contains(where: { $0.namespace.lowercased() == "ue" })
                {
                    continue
                }
                group.addTask {
                    if let assetsByPlatform = assetMap[appName] {
                        do {
                            if let game = try await self.buildGameMetadata(
                                appName: appName, assetsByPlatform: assetsByPlatform, client: client
                            ) {
                                try await self.store.saveGameMetadata(game)
                            }
                        } catch {
                            print(
                                "[Library] Failed to build/save metadata for \(appName): \(error)")
                        }
                        return
                    }

                    guard let item = libraryItems.first(where: { $0.appName == appName }) else {
                        return
                    }

                    do {
                        guard
                            let metadata = try await self.loadCatalogGameInfo(
                                client: client,
                                namespace: item.namespace,
                                catalogItemId: item.catalogItemId,
                                appName: appName,
                                platform: "Windows"
                            )
                        else {
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
        let filePath = URL(fileURLWithPath: legendaryMetadata()).appendingPathComponent(
            "\(appName).json")
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
                keyImages.first(where: { $0.type == "DieselGameBoxTall" })?.url
                ?? keyImages.first(where: { $0.type == "DieselStoreFrontTall" })?.url
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
            keyImages.first(where: { $0.type == "DieselGameBoxTall" })?.url
            ?? keyImages.first(where: { $0.type == "DieselStoreFrontTall" })?.url
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
    public func getGameDetails(appName: String, platform: String = "Windows") async throws
        -> GameDetails
    {
        guard library[appName] != nil else {
            throw ImportError.gameNotFound(appName)
        }

        let legendaryPlatform = LegendaryPlatform(rawValue: platform) ?? .windows
        let command = LegendaryCommand.info(
            InfoCommandOptions(appName: appName, platform: legendaryPlatform))
        let binaryPath = legendaryBinaryPath()

        let runner = LegendaryRunner(legendaryPath: binaryPath)
        let result = try await runner.run(command)

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

    // MARK: - Launch Parameter Resolution

    /// Builds environment variable overrides for launching a game.
    /// Mirrors `get_app_environment` from legendary's core.py.
    ///
    /// - On macOS, CrossOver bottle and WINEPREFIX are resolved in priority order:
    ///   explicit param → existing env var → legendary config → sensible default.
    public func getAppEnvironment(
        appName: String,
        winePfx: String? = nil,
        cxBottle: String? = nil,
        disableWine: Bool = false
    ) -> [String: String] {
        var env: [String: String] = [:]

        // Merge default.env and <appName>.env from legendary config (best-effort)
        let configPath = legendaryConfigPath()
        let configURL = URL(fileURLWithPath: configPath).appendingPathComponent("config.ini")
        if let configContents = try? String(contentsOf: configURL, encoding: .utf8) {
            env.merge(parseIniEnvSection(configContents, section: "default.env")) { _, new in new }
            env.merge(parseIniEnvSection(configContents, section: "\(appName).env")) { _, new in new
            }
        }

        guard !disableWine else { return env }

        #if os(macOS)
            // CrossOver bottle resolution: param → env → config → "Legendary"
            if let bottle = cxBottle, !bottle.isEmpty {
                env["CX_BOTTLE"] = bottle
            } else if ProcessInfo.processInfo.environment["CX_BOTTLE"] == nil {
                // Not already set in the process environment — use config or default
                let bottle =
                    readLegendaryConfig(appName: appName, key: "crossover_bottle")
                    ?? readLegendaryConfig(appName: "default", key: "crossover_bottle")
                    ?? "Legendary"
                env["CX_BOTTLE"] = bottle
            }
        #endif

        // WINEPREFIX resolution: param → env → config
        if let pfx = winePfx, !pfx.isEmpty {
            env["WINEPREFIX"] = pfx
        } else if ProcessInfo.processInfo.environment["WINEPREFIX"] == nil {
            if let pfx = readLegendaryConfig(appName: appName, key: "wine_prefix") {
                env["WINEPREFIX"] = pfx
            }
        }

        return env
    }

    /// Builds the launch command prefix: [wrapper?, wine_binary].
    /// Mirrors `get_app_launch_command` from legendary's core.py.
    ///
    /// On macOS, CrossOver is preferred. Falls back to config wine_executable → "wine".
    public func getAppLaunchCommand(
        appName: String,
        wrapper: String? = nil,
        wineBinary: String? = nil,
        crossoverApp: String? = nil,
        disableWine: Bool = false
    ) -> [String] {
        var cmd: [String] = []

        // Wrapper (e.g. gamescope, mangohud)
        let resolvedWrapper =
            wrapper
            ?? readLegendaryConfig(appName: appName, key: "wrapper")
            ?? readLegendaryConfig(appName: "default", key: "wrapper")
        if let w = resolvedWrapper, !w.isEmpty {
            cmd += w.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        }

        #if os(Windows)
            // No wine needed on Windows
            return cmd
        #else
            guard !disableWine else { return cmd }

            #if os(macOS)
                // Resolve CrossOver app: param → config → auto-detect
                var resolvedCXApp =
                    crossoverApp
                    ?? readLegendaryConfig(appName: appName, key: "crossover_app")
                    ?? readLegendaryConfig(appName: "default", key: "crossover_app")

                if resolvedCXApp == nil && wineBinary == nil {
                    // Auto-detect CrossOver unless disabled in config
                    let disableAutoCX =
                        readLegendaryConfig(appName: "Legendary", key: "disable_auto_crossover")
                        .map { $0.lowercased() == "true" } ?? false
                    if !disableAutoCX {
                        resolvedCXApp = findCrossoverApp()
                    }
                }

                if let cxApp = resolvedCXApp, !cxApp.isEmpty {
                    let cxWine = URL(fileURLWithPath: cxApp)
                        .appendingPathComponent("Contents/SharedSupport/CrossOver/bin/wine").path
                    if FileManager.default.fileExists(atPath: cxWine) {
                        cmd.append(cxWine)
                        return cmd
                    }
                    print(
                        "[Library] CrossOver app specified but wine binary not found at: \(cxWine)")
                }
            #endif

            // Explicit wine binary or config override
            let wine =
                wineBinary
                ?? readLegendaryConfig(appName: appName, key: "wine_executable")
                ?? readLegendaryConfig(appName: "default", key: "wine_executable")
                ?? "wine"
            cmd.append(wine)
            return cmd
        #endif
    }

    /// Returns the pre-launch command and whether to wait for it.
    /// Mirrors `get_pre_launch_command` from legendary's core.py.
    public func getPreLaunchCommand(appName: String) -> (command: String?, wait: Bool) {
        if let cmd = readLegendaryConfig(appName: appName, key: "pre_launch_command"), !cmd.isEmpty
        {
            let wait =
                readLegendaryConfig(appName: appName, key: "pre_launch_wait")
                .map { $0.lowercased() == "true" } ?? false
            return (cmd, wait)
        }
        let cmd = readLegendaryConfig(appName: "default", key: "pre_launch_command")
        let wait =
            readLegendaryConfig(appName: "default", key: "pre_launch_wait")
            .map { $0.lowercased() == "true" } ?? false
        return (cmd, wait)
    }

    /// Resolves all launch parameters for a game.
    /// Mirrors `get_launch_parameters` from legendary's core.py.
    ///
    /// - Parameters:
    ///   - appName: The Epic app name.
    ///   - offline: Skip auth token fetch (game must support offline).
    ///   - gameToken: Pre-fetched auth token (pass "" for offline/dry-run).
    ///   - accountId: Epic account ID.
    ///   - userName: Epic display name.
    ///   - language: Locale override (e.g. "en").
    ///   - extraArgs: Additional user-supplied arguments.
    ///   - wineBin: Explicit wine binary path override.
    ///   - winePfx: Explicit WINEPREFIX override.
    ///   - wrapper: Wrapper command override.
    ///   - disableWine: Skip wine entirely (native executables).
    ///   - executableOverride: Override the game executable path.
    ///   - crossoverApp: Explicit CrossOver .app path.
    ///   - crossoverBottle: Explicit CrossOver bottle name.
    public func getLaunchParameters(
        appName: String,
        offline: Bool = false,
        gameToken: String = "",
        accountId: String = "",
        userName: String = "",
        language: String? = nil,
        extraArgs: [String] = [],
        wineBin: String? = nil,
        winePfx: String? = nil,
        wrapper: String? = nil,
        disableWine: Bool = false,
        executableOverride: String? = nil,
        crossoverApp: String? = nil,
        crossoverBottle: String? = nil
    ) throws -> LaunchParameters {
        guard let install = installedGames[appName] else {
            throw LaunchError.gameNotInstalled(appName)
        }
        guard library[appName] != nil else {
            throw LaunchError.gameNotFound(appName)
        }
        let game = library[appName]!

        // Disable wine for non-Windows platforms (e.g. native macOS builds)
        var resolvedDisableWine = disableWine
        if !install.platform.rawValue.hasPrefix("Win") {
            resolvedDisableWine = true
        }
        // Also check config no_wine flag
        if let noWine = readLegendaryConfig(appName: appName, key: "no_wine")
            ?? readLegendaryConfig(appName: "default", key: "no_wine"),
            noWine.lowercased() == "true"
        {
            resolvedDisableWine = true
        }

        // Resolve executable
        let resolvedExeOverride =
            executableOverride
            ?? readLegendaryConfig(appName: appName, key: "override_exe")
        let gameExe: String
        if let override = resolvedExeOverride, !override.isEmpty {
            gameExe = override.replacingOccurrences(of: "\\", with: "/")
            let exePath = (install.installPath as NSString).appendingPathComponent(gameExe)
            guard FileManager.default.fileExists(atPath: exePath) else {
                throw LaunchError.invalidExecutablePath(exePath)
            }
        } else {
            gameExe = install.executable
                .replacingOccurrences(of: "\\", with: "/")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        let exePath = (install.installPath as NSString).appendingPathComponent(gameExe)
        let workingDir = (exePath as NSString).deletingLastPathComponent

        var params = LaunchParameters(
            gameExecutable: gameExe,
            gameDirectory: install.installPath,
            workingDirectory: workingDir,
            launchCommand: getAppLaunchCommand(
                appName: appName,
                wrapper: wrapper,
                wineBinary: wineBin,
                crossoverApp: crossoverApp,
                disableWine: resolvedDisableWine
            ),
            environment: getAppEnvironment(
                appName: appName,
                winePfx: winePfx,
                cxBottle: crossoverBottle,
                disableWine: resolvedDisableWine
            )
        )

        // Pre-launch command
        let (preCmd, preWait) = getPreLaunchCommand(appName: appName)
        params.preLaunchCommand = preCmd
        params.preLaunchWait = preWait

        // Game parameters from install metadata
        if !install.launchParameters.isEmpty {
            let parts = install.launchParameters
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            params.gameParameters.append(contentsOf: parts)
        }

        // Additional command line from game metadata
        if let metaArgs = game.metadata.technicalDetails, !metaArgs.isEmpty {
            let parts = metaArgs.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            params.gameParameters.append(contentsOf: parts)
        }

        // EGL authentication parameters
        params.eglParameters = [
            "-AUTH_LOGIN=unused",
            "-AUTH_PASSWORD=\(gameToken)",
            "-AUTH_TYPE=exchangecode",
            "-epicapp=\(appName)",
            "-epicenv=Prod",
        ]

        // Locale
        let languageCode =
            language
            ?? readLegendaryConfig(appName: appName, key: "language")
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"

        params.eglParameters += [
            "-EpicPortal",
            "-epicusername=\(userName)",
            "-epicuserid=\(accountId)",
            "-epiclocale=\(languageCode)",
            "-epicsandboxid=\(game.metadata.namespace ?? "")",
        ]

        // User extra args
        if !extraArgs.isEmpty {
            params.userParameters.append(contentsOf: extraArgs)
        }
        if let configArgs = readLegendaryConfig(appName: appName, key: "start_params"),
            !configArgs.isEmpty
        {
            let parts = configArgs.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            params.userParameters.append(contentsOf: parts)
        }

        return params
    }

    // MARK: - Config helpers

    /// Reads a single key from the legendary INI config for a given section.
    /// Returns nil if the config file or key is absent.
    private func readLegendaryConfig(appName: String, key: String) -> String? {
        let configURL = URL(fileURLWithPath: legendaryConfigPath())
            .appendingPathComponent("config.ini")
        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
            return nil
        }
        return parseIniValue(contents, section: appName, key: key)
    }

    /// Minimal INI parser: finds `[section]` then returns the value for `key = value`.
    private func parseIniValue(_ ini: String, section: String, key: String) -> String? {
        var inSection = false
        for line in ini.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let name = String(trimmed.dropFirst().dropLast())
                inSection = name.lowercased() == section.lowercased()
                continue
            }
            guard inSection else { continue }
            guard !trimmed.hasPrefix(";"), !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }
            let k = parts[0].trimmingCharacters(in: .whitespaces)
            if k.lowercased() == key.lowercased() {
                return parts[1...].joined(separator: "=")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Parses a `[section]` block from an INI file into a `[String: String]` dict,
    /// skipping comment lines (starting with `;`).
    private func parseIniEnvSection(_ ini: String, section: String) -> [String: String] {
        var result: [String: String] = [:]
        var inSection = false
        for line in ini.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let name = String(trimmed.dropFirst().dropLast())
                inSection = name.lowercased() == section.lowercased()
                continue
            }
            guard inSection else { continue }
            guard !trimmed.hasPrefix(";"), !trimmed.hasPrefix("#"), !trimmed.isEmpty else {
                continue
            }
            let parts = trimmed.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }
            let k = parts[0].trimmingCharacters(in: .whitespaces)
            let v = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
            if !k.isEmpty && !v.isEmpty {
                result[k] = v
            }
        }
        return result
    }

    /// Uses `mdfind` to locate CrossOver on macOS. Returns the first result or nil.
    private func findCrossoverApp() -> String? {
        #if os(macOS)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
            task.arguments = ["kMDItemCFBundleIdentifier = \"com.codeweavers.CrossOver\""]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            guard (try? task.run()) != nil else { return nil }
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first(where: { !$0.isEmpty })
        #else
            return nil
        #endif
    }

    public enum ImportError: Error, LocalizedError {
        case gameNotFound(String)
        case pathDoesNotExist(String)
        case alreadyInstalled(String)

        public var errorDescription: String? {
            switch self {
            case .gameNotFound(let name): return "Game '\(name)' not found in your library."
            case .pathDoesNotExist(let p): return "Path does not exist: \(p)"
            case .alreadyInstalled(let n): return "'\(n)' is already registered as installed."
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
    public func importGame(
        appName: String, installPath: String, platform: String = "Windows", withDlcs: Bool = true
    ) async throws {
        guard FileManager.default.fileExists(atPath: installPath) else {
            throw ImportError.pathDoesNotExist(installPath)
        }

        guard let app = library[appName] else {
            throw ImportError.gameNotFound(appName)
        }

        if installedGames[appName] != nil {
            throw ImportError.alreadyInstalled(app.appTitle)
        }
        let legendaryPlatform = LegendaryPlatform(rawValue: platform) ?? .windows
        let command = LegendaryCommand.importGame(
            appName,
            from: installPath,
            platform: legendaryPlatform,
            withDlcs: withDlcs
        )

        let binaryPath = legendaryBinaryPath()
        let runner = LegendaryRunner(legendaryPath: binaryPath)
        print("[Library] Importing '\(appName)' from \(installPath) using legendary...")
        let result = try await runner.run(command, options: RunnerOptions(logOutput: true))
        print("[Library] Legendary import command completed with exit code \(result.exitCode)")
        if !result.success {
            throw LegendaryError.commandFailed(exitCode: result.exitCode, stderr: result.standardError)
        }

        await refreshInstalled()

        print("[Library] Imported '\(appName)' from \(installPath)")
    }

    /// Launches a game using the provided parameters.
    /// Spawns a background process and returns immediately.
    public func launchGame(params: LaunchParameters) throws {
        let process = Process()
        let command = params.fullCommandLine
        guard !command.isEmpty else {
            throw LaunchError.invalidExecutablePath("Empty command line")
        }

        process.executableURL = URL(fileURLWithPath: command[0])
        process.arguments = Array(command.dropFirst())
        process.currentDirectoryURL = URL(fileURLWithPath: params.workingDirectory)

        var environment = ProcessInfo.processInfo.environment
        for (key, value) in params.environment {
            environment[key] = value
        }
        process.environment = environment

        // Redirect output to null or a log file to avoid filling up pipes if not read
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        print("[Library] Launching: \(command.joined(separator: " "))")
        print("[Library] In directory: \(params.workingDirectory)")

        try process.run()
    }
}

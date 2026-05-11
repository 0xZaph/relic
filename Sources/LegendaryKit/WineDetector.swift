import Foundation

// MARK: - Wine Installation

/// Represents a detected Wine / CrossOver / toolkit installation.
public struct WineInstallation: Sendable, Identifiable {
    public enum WineType: String, Sendable {
        case wine = "wine"
        case crossover = "crossover"
        case toolkit = "toolkit"  // GPTK, Whisky
    }

    public var id: String { bin }
    public let bin: String  // path to the wine / wine64 binary
    public let name: String  // human-readable label
    public let type: WineType
    public let wineserver: String  // path to wineserver, or ""

    public init(bin: String, name: String, type: WineType, wineserver: String = "") {
        self.bin = bin
        self.name = name
        self.type = type
        self.wineserver = wineserver
    }
}

// MARK: - Wine Detector

/// Scans the system for Wine / CrossOver / toolkit installations on macOS.
/// Mirrors the detection logic from Heroic's `wine/utils.ts`.
public struct WineDetector: Sendable {

    public init() {}

    // MARK: - Public API

    /// Returns all detected Wine installations, CrossOver first.
    public func detectAll() async -> [WineInstallation] {
        #if os(macOS)
            async let cx = getCrossover()
            async let wine = getWineOnMac()
            async let skin = getWineskinWine()
            async let gptk = getGamePortingToolkitWine()
            async let wsky = getWhisky()
            async let hroic = getHeroicWine()

            let all = await cx + wine + skin + gptk + wsky + hroic
            // Deduplicate by bin path, preserving order (CrossOver first)
            var seen = Set<String>()
            return all.filter { seen.insert($0.bin).inserted }
        #elseif os(Linux)
            async let sys = getSystemWine()
            async let heroic = getHeroicWineLinux()
            async let steam = getSteamProton()
            async let relic = getRelicWineLinux()

            let all = await sys + heroic + steam + relic
            var seen = Set<String>()
            return all.filter { seen.insert($0.bin).inserted }
        #else
            return []
        #endif
    }

    // MARK: - CrossOver

    /// Finds CrossOver installs via Spotlight (`com.codeweavers.CrossOver`).
    public func getCrossover() async -> [WineInstallation] {
        #if os(macOS)
            let paths = await mdfind(
                query: "kMDItemCFBundleIdentifier = \"com.codeweavers.CrossOver\"")
            var results: [WineInstallation] = []
            for appPath in paths {
                let infoPath = URL(fileURLWithPath: appPath)
                    .appendingPathComponent("Contents/Info.plist")
                guard FileManager.default.fileExists(atPath: infoPath.path),
                    let info = NSDictionary(contentsOf: infoPath),
                    let version = info["CFBundleShortVersionString"] as? String
                else { continue }

                let wineBin = URL(fileURLWithPath: appPath)
                    .appendingPathComponent("Contents/SharedSupport/CrossOver/bin/wine")
                    .path
                guard FileManager.default.fileExists(atPath: wineBin) else { continue }

                results.append(
                    WineInstallation(
                        bin: wineBin,
                        name: "CrossOver \(version)",
                        type: .crossover,
                        wineserver: wineserverPath(near: wineBin)
                    ))
            }
            return results
        #else
            return []
        #endif
    }

    // MARK: - Wine .app bundles (Spotlight + tools folder)

    /// Finds Wine .app bundles via Spotlight and the Relic tools folder.
    public func getWineOnMac() async -> [WineInstallation] {
        #if os(macOS)
            var winePaths = Set<String>()

            // Relic-managed tools folder
            let toolsWinePath = relicToolsPath().appendingPathComponent("wine")
            if let entries = try? FileManager.default.contentsOfDirectory(
                at: toolsWinePath, includingPropertiesForKeys: nil
            ) {
                entries.forEach { winePaths.insert($0.path) }
            }

            // Spotlight scan
            let found = await mdfind(query: "kMDItemCFBundleIdentifier = \"*.wine\"")
            found.forEach { winePaths.insert($0) }

            var results: [WineInstallation] = []
            for winePath in winePaths {
                let infoURL = URL(fileURLWithPath: winePath)
                    .appendingPathComponent("Contents/Info.plist")
                guard FileManager.default.fileExists(atPath: infoURL.path),
                    let info = NSDictionary(contentsOf: infoURL)
                else { continue }

                let version = info["CFBundleShortVersionString"] as? String ?? ""
                let bundleName = info["CFBundleName"] as? String ?? "Wine"

                // Prefer wine64, fall back to wine
                var wineBin = URL(fileURLWithPath: winePath)
                    .appendingPathComponent("Contents/Resources/wine/bin/wine64").path
                if !FileManager.default.fileExists(atPath: wineBin) {
                    wineBin =
                        URL(fileURLWithPath: winePath)
                        .appendingPathComponent("Contents/Resources/wine/bin/wine").path
                }
                guard FileManager.default.fileExists(atPath: wineBin) else { continue }

                results.append(
                    WineInstallation(
                        bin: wineBin,
                        name: "\(bundleName) \(version)".trimmingCharacters(in: .whitespaces),
                        type: .wine,
                        wineserver: wineserverPath(near: wineBin)
                    ))
            }
            return results
        #else
            return []
        #endif
    }

    // MARK: - Wineskin

    public func getWineskinWine() async -> [WineInstallation] {
        #if os(macOS)
            let wineskinPath = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Applications/Wineskin")
            guard
                let apps = try? FileManager.default.contentsOfDirectory(
                    at: wineskinPath, includingPropertiesForKeys: nil
                )
            else { return [] }

            var results: [WineInstallation] = []
            for app in apps where app.pathExtension == "app" {
                let wineBin =
                    app
                    .appendingPathComponent("Contents/SharedSupport/wine/bin/wine64").path
                guard FileManager.default.fileExists(atPath: wineBin) else { continue }

                let version = (try? shellVersion(wineBin)) ?? ""
                results.append(
                    WineInstallation(
                        bin: wineBin,
                        name: "Wineskin\(version.isEmpty ? "" : " - \(version)")",
                        type: .wine,
                        wineserver: wineserverPath(near: wineBin)
                    ))
            }
            return results
        #else
            return []
        #endif
    }

    // MARK: - Game Porting Toolkit (Relic tools folder)

    public func getGamePortingToolkitWine() async -> [WineInstallation] {
        #if os(macOS)
            let gptkPath = relicToolsPath().appendingPathComponent("game-porting-toolkit")
            guard
                let entries = try? FileManager.default.contentsOfDirectory(
                    at: gptkPath, includingPropertiesForKeys: nil
                )
            else { return [] }

            var results: [WineInstallation] = []
            for entry in entries {
                let infoURL = entry.appendingPathComponent("Contents/Info.plist")
                guard FileManager.default.fileExists(atPath: infoURL.path) else { continue }

                let wineBin =
                    entry
                    .appendingPathComponent("Contents/Resources/wine/bin/wine64").path
                guard FileManager.default.fileExists(atPath: wineBin) else { continue }

                let name = entry.lastPathComponent
                results.append(
                    WineInstallation(
                        bin: wineBin,
                        name: name,
                        type: .toolkit,
                        wineserver: wineserverPath(near: wineBin)
                    ))
            }
            return results
        #else
            return []
        #endif
    }

    // MARK: - Whisky

    public func getWhisky() async -> [WineInstallation] {
        #if os(macOS)
            let base = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent(
                    "Library/Application Support/com.isaacmarovitz.Whisky/Libraries")
            let plistURL = base.appendingPathComponent("WhiskyWineVersion.plist")
            let wineBin = base.appendingPathComponent("Wine/bin/wine64").path

            guard FileManager.default.fileExists(atPath: plistURL.path),
                FileManager.default.fileExists(atPath: wineBin),
                let info = NSDictionary(contentsOf: plistURL),
                let versionDict = info["version"] as? [String: Any]
            else { return [] }

            let major = versionDict["major"] as? Int ?? 0
            let minor = versionDict["minor"] as? Int ?? 0
            let patch = versionDict["patch"] as? Int ?? 0
            let build = versionDict["build"] as? String ?? ""
            let versionString = "\(major).\(minor).\(patch)-\(build)"

            return [
                WineInstallation(
                    bin: wineBin,
                    name: "Whisky \(versionString)",
                    type: .toolkit,
                    wineserver: wineserverPath(near: wineBin)
                )
            ]
        #else
            return []
        #endif
    }

    public func getHeroicWine() async -> [WineInstallation] {
        #if os(macOS)
            let heroicPath = heroicToolsPath()
            var results: [WineInstallation] = []

            // Heroic stores wine versions in subfolders of 'tools'
            // Structure varies: tools/wine/xyz or tools/game-porting-toolkit/xyz
            let types: [WineInstallation.WineType] = [.wine, .toolkit]
            let subdirs = ["wine", "game-porting-toolkit"]

            for (type, subdir) in zip(types, subdirs) {
                let searchPath = heroicPath.appendingPathComponent(subdir)
                guard let entries = try? FileManager.default.contentsOfDirectory(
                    at: searchPath, includingPropertiesForKeys: nil
                ) else { continue }

                for entry in entries {
                    // Try different possible binary locations
                    let candidates = [
                        "Contents/Resources/wine/bin/wine64",
                        "Contents/SharedSupport/wine/bin/wine64",
                        "bin/wine64",
                        "bin/wine"
                    ]

                    for relPath in candidates {
                        let wineBin = entry.appendingPathComponent(relPath).path
                        if FileManager.default.fileExists(atPath: wineBin) {
                            let name = entry.lastPathComponent
                            results.append(WineInstallation(
                                bin: wineBin,
                                name: "Heroic - \(name)",
                                type: type,
                                wineserver: wineserverPath(near: wineBin)
                            ))
                            break
                        }
                    }
                }
            }
            return results
        #else
            return []
        #endif
    }

    // MARK: - Linux Detection

    #if os(Linux)
    public func getSystemWine() async -> [WineInstallation] {
        var results: [WineInstallation] = []
        let candidates = ["/usr/bin/wine64", "/usr/bin/wine"]
        for bin in candidates {
            if FileManager.default.fileExists(atPath: bin) {
                let version = (try? shellVersion(bin)) ?? "System Wine"
                results.append(WineInstallation(
                    bin: bin,
                    name: version,
                    type: .wine,
                    wineserver: wineserverPath(near: bin)
                ))
            }
        }
        return results
    }

    public func getHeroicWineLinux() async -> [WineInstallation] {
        var results: [WineInstallation] = []
        let configHomeStr = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config").path
        let heroicPath = URL(fileURLWithPath: configHomeStr).appendingPathComponent("heroic/tools")
        let subdirs = ["wine", "proton"]
        let types: [WineInstallation.WineType] = [.wine, .toolkit]

        for (type, subdir) in zip(types, subdirs) {
            let searchPath = heroicPath.appendingPathComponent(subdir)
            guard let entries = try? FileManager.default.contentsOfDirectory(at: searchPath, includingPropertiesForKeys: nil) else { continue }
            
            for entry in entries {
                let candidates = ["bin/wine64", "bin/wine", "files/bin/wine64", "files/bin/wine"]
                for rel in candidates {
                    let bin = entry.appendingPathComponent(rel).path
                    if FileManager.default.fileExists(atPath: bin) {
                        results.append(WineInstallation(
                            bin: bin,
                            name: "Heroic - \(entry.lastPathComponent)",
                            type: type,
                            wineserver: wineserverPath(near: bin)
                        ))
                        break
                    }
                }
            }
        }
        return results
    }

    public func getSteamProton() async -> [WineInstallation] {
        var results: [WineInstallation] = []
        let steamPaths = [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".steam/root/compatibilitytools.d"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/share/Steam/compatibilitytools.d"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".steam/steam/steamapps/common")
        ]
        
        for searchPath in steamPaths {
            guard let entries = try? FileManager.default.contentsOfDirectory(at: searchPath, includingPropertiesForKeys: nil) else { continue }
            for entry in entries {
                let name = entry.lastPathComponent
                if !name.lowercased().contains("proton") { continue }
                let candidates = ["files/bin/wine64", "bin/wine64", "bin/wine"]
                for rel in candidates {
                    let bin = entry.appendingPathComponent(rel).path
                    if FileManager.default.fileExists(atPath: bin) {
                        results.append(WineInstallation(
                            bin: bin,
                            name: name,
                            type: .toolkit,
                            wineserver: wineserverPath(near: bin)
                        ))
                        break
                    }
                }
            }
        }
        return results
    }

    public func getRelicWineLinux() async -> [WineInstallation] {
        var results: [WineInstallation] = []
        let toolsPath = relicToolsPath()
        let subdirs = ["wine", "proton"]
        let types: [WineInstallation.WineType] = [.wine, .toolkit]

        for (type, subdir) in zip(types, subdirs) {
            let searchPath = toolsPath.appendingPathComponent(subdir)
            guard let entries = try? FileManager.default.contentsOfDirectory(at: searchPath, includingPropertiesForKeys: nil) else { continue }
            
            for entry in entries {
                let candidates = ["bin/wine64", "bin/wine", "files/bin/wine64", "files/bin/wine"]
                for rel in candidates {
                    let bin = entry.appendingPathComponent(rel).path
                    if FileManager.default.fileExists(atPath: bin) {
                        results.append(WineInstallation(
                            bin: bin,
                            name: "Relic - \(entry.lastPathComponent)",
                            type: type,
                            wineserver: wineserverPath(near: bin)
                        ))
                        break
                    }
                }
            }
        }
        return results
    }
    #endif

    // MARK: - Helpers

    /// Path to the Heroic Games Launcher tools folder.
    private func heroicToolsPath() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("heroic/tools")
    }

    /// Path to the Relic app-support tools folder.
    private func relicToolsPath() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("relic/tools")
    }

    /// Returns the wineserver path if it exists next to the wine binary.
    private func wineserverPath(near wineBin: String) -> String {
        let candidate = URL(fileURLWithPath: wineBin)
            .deletingLastPathComponent()
            .appendingPathComponent("wineserver").path
        return FileManager.default.fileExists(atPath: candidate) ? candidate : ""
    }

    /// Runs `mdfind` and returns non-empty trimmed lines.
    private func mdfind(query: String) async -> [String] {
        await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
            task.arguments = [query]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do {
                try task.launch()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let lines = output.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                continuation.resume(returning: lines)
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    /// Runs `wine --version` synchronously and returns the first line.
    private func shellVersion(_ bin: String) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: bin)
        task.arguments = ["--version"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "")
            .components(separatedBy: "\n").first ?? ""
    }
}

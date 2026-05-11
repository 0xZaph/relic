import Foundation
import EpicKit

public actor LegendaryFS {
    private let basePath: URL

    public init(basePath: URL? = nil) throws {
        if let basePath {
            self.basePath = basePath
        } else {
            // XDG_CONFIG_HOME fallback
            if let xdgConfig = ProcessInfo.processInfo.environment[
                "XDG_CONFIG_HOME"
            ] {
                self.basePath = URL(fileURLWithPath: xdgConfig)
                    .appendingPathComponent("legendary")
            } else {
                self.basePath = URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent(".config/legendary")
            }
        }
        try createDirectories(at: self.basePath)

        let metadataDirectoryURL = self.basePath.appendingPathComponent("metadata")
        let manifestsDirectoryURL = self.basePath.appendingPathComponent("manifests")
        let tmpDirectoryURL = self.basePath.appendingPathComponent("tmp")

        try createDirectories(at: metadataDirectoryURL)
        try createDirectories(at: manifestsDirectoryURL)
        try createDirectories(at: tmpDirectoryURL)
    }

    nonisolated private func createDirectories(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    private var userTokenURL: URL {
        return basePath.appendingPathComponent("user.json")
    }

    private var metadataDirectoryURL: URL {
        basePath.appendingPathComponent("metadata")
    }

    private var manifestsDirectoryURL: URL {
        basePath.appendingPathComponent("manifests")
    }

    private var tmpDirectoryURL: URL {
        basePath.appendingPathComponent("tmp")
    }

    private func metadataURL(for appName: String) -> URL {
        metadataDirectoryURL.appendingPathComponent("\(appName).json")
    }

    public func loadUserSession() throws -> OAuthResponse? {
        guard FileManager.default.fileExists(atPath: userTokenURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: userTokenURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(OAuthResponse.self, from: data)
    }

    public func saveUserSession(_ session: OAuthResponse) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(session)
        try data.write(to: userTokenURL, options: .atomic)
    }

    public func clearUserSession() throws {
        guard FileManager.default.fileExists(atPath: userTokenURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: userTokenURL)
    }

    public func listGameMetadataFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: metadataDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }
    }

    public func loadGameMetadata(named appName: String) throws -> Legendary.GameMetadata? {
        let fileURL = metadataURL(for: appName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Legendary.GameMetadata.self, from: data)
    }

    public func saveGameMetadata(_ game: Legendary.GameMetadata) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(game)
        try data.write(to: metadataURL(for: game.appName), options: .atomic)
    }

    public func removeGameMetadata(named appName: String) throws {
        let fileURL = metadataURL(for: appName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    private var installedGamesURL: URL {
        basePath.appendingPathComponent("installed.json")
    }

    // MARK: - Installed games

    public func loadInstalledGames() throws -> [String: Legendary.InstalledJsonMetadata] {
        guard FileManager.default.fileExists(atPath: installedGamesURL.path) else {
            return [:]
        }
        let data = try Data(contentsOf: installedGamesURL)
        return try JSONDecoder().decode([String: Legendary.InstalledJsonMetadata].self, from: data)
    }

    public func saveInstalledGame(_ appName: String, _ metadata: Legendary.InstalledJsonMetadata) throws {
        var current = (try? loadInstalledGames()) ?? [:]
        current[appName] = metadata
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(current)
        try data.write(to: installedGamesURL, options: .atomic)
    }

    public func removeInstalledGame(_ appName: String) throws {
        var current = (try? loadInstalledGames()) ?? [:]
        guard current[appName] != nil else { return }
        current.removeValue(forKey: appName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(current)
        try data.write(to: installedGamesURL, options: .atomic)
    }

}

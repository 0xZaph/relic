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

}

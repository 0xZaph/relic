// MARK: - Info Command Options

public struct InfoCommandOptions: Sendable {
    public var appName: String
    public var platform: LegendaryPlatform
    public var offline: Bool

    public init(
        appName: String,
        platform: LegendaryPlatform = .windows,
        offline: Bool = false
    ) {
        self.appName = appName
        self.platform = platform
        self.offline = offline
    }

    public func toArguments() -> [String] {
        var args: [String] = ["info"]
        args.append("--json")
        args.append("--platform")
        args.append(platform.rawValue)
        if offline { args.append("--offline") }
        args.append(appName)
        return args
    }
}

// MARK: - Info JSON output models

public struct LegendaryInfoOutput: Decodable {
    public let game: LegendaryInfoGame
    public let manifest: LegendaryInfoManifest?
}

public struct LegendaryInfoGame: Decodable {
    public let appName: String
    public let title: String
    public let version: String?
    public let platformVersions: [String: String]?
    public let cloudSavesSupported: Bool?
    public let isDlc: Bool?

    enum CodingKeys: String, CodingKey {
        case appName = "app_name"
        case title
        case version
        case platformVersions = "platform_versions"
        case cloudSavesSupported = "cloud_saves_supported"
        case isDlc = "is_dlc"
    }
}

public struct LegendaryInfoManifest: Decodable {
    public let diskSize: Int64
    public let downloadSize: Int64
    public let buildVersion: String
    public let launchExe: String
    public let numFiles: Int
    public let numChunks: Int

    enum CodingKeys: String, CodingKey {
        case diskSize = "disk_size"
        case downloadSize = "download_size"
        case buildVersion = "build_version"
        case launchExe = "launch_exe"
        case numFiles = "num_files"
        case numChunks = "num_chunks"
    }
}

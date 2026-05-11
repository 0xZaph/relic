// MARK: - Install Command Options

public struct InstallCommandOptions: Sendable {
    public let appName: String
    public var basePath: String?
    public var withDlcs: Bool
    public var platform: LegendaryPlatform?

    public init(
        appName: String,
        basePath: String? = nil,
        withDlcs: Bool = false,
        platform: LegendaryPlatform? = nil
    ) {
        self.appName = appName
        self.basePath = basePath
        self.withDlcs = withDlcs
        self.platform = platform
    }

    public func toArguments() -> [String] {
        var args: [String] = ["install", appName, "-y", "--skip-sdl"]

        if let basePath {
            args.append("--base-path")
            args.append(basePath)
        }

        if withDlcs { args.append("--with-dlcs") }

        if let platform {
            args.append("--platform")
            args.append(platform.rawValue)
        }

        return args
    }
}
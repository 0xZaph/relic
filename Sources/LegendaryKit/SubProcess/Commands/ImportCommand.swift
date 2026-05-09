// MARK: - Import Command Options

public struct ImportCommandOptions {
    public let appName: String
    public let installationDirectory: String
    public var disableCheck: Bool
    public var withDlcs: Bool
    public var platform: LegendaryPlatform?

    public init(
        appName: String,
        installationDirectory: String,
        disableCheck: Bool = false,
        withDlcs: Bool = false,
        platform: LegendaryPlatform? = nil
    ) {
        self.appName = appName
        self.installationDirectory = installationDirectory
        self.disableCheck = disableCheck
        self.withDlcs = withDlcs
        self.platform = platform
    }

    public init(
        appName: String,
        installationDirectory: String
    ) {
        self.appName = appName
        self.installationDirectory = installationDirectory
        disableCheck = false
        withDlcs = false
        platform = nil
    }

    public func toArguments() -> [String] {
        var args: [String] = ["import", appName, installationDirectory]

        if disableCheck { args.append("--disable-check") }
        if withDlcs { args.append("--with-dlcs") }

        if let platform {
            args.append("--platform")
            args.append(platform.rawValue)
        }

        return args
    }
}

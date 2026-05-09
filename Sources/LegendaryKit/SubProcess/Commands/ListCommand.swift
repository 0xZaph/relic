// MARK: - List Command Options

public struct ListCommandOptions {
    public var platform: LegendaryPlatform?
    public var includeUE: Bool
    public var thirdParty: Bool
    public var includeNonInstallable: Bool
    public var csv: Bool
    public var tsv: Bool
    public var json: Bool
    public var forceRefresh: Bool

    public init(
        platform: LegendaryPlatform? = nil,
        includeUE: Bool = false,
        thirdParty: Bool = false,
        includeNonInstallable: Bool = false,
        csv: Bool = false,
        tsv: Bool = false,
        json: Bool = false,
        forceRefresh: Bool = false
    ) {
        self.platform = platform
        self.includeUE = includeUE
        self.thirdParty = thirdParty
        self.includeNonInstallable = includeNonInstallable
        self.csv = csv
        self.tsv = tsv
        self.json = json
        self.forceRefresh = forceRefresh
    }

    public init() {
        self.platform = nil
        self.includeUE = false
        self.thirdParty = false
        self.includeNonInstallable = false
        self.csv = false
        self.tsv = false
        self.json = false
        self.forceRefresh = false
    }

    public func toArguments() -> [String] {
        var args: [String] = ["list"]

        if let platform {
            args.append("--platform")
            args.append(platform.rawValue)
        }

        if includeUE { args.append("--include-ue") }
        if thirdParty {
            args.append("-T")
            args.append("--third-party")
        }
        if includeNonInstallable { args.append("--include-non-installable") }
        if csv { args.append("--csv") }
        if tsv { args.append("--tsv") }
        if json { args.append("--json") }
        if forceRefresh { args.append("--force-refresh") }

        return args
    }
}

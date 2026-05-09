// MARK: - Platform Enum

public enum LegendaryPlatform: String {
    case windows = "Windows"
    case win32 = "Win32"
    case mac = "Mac"
    case linux = "Linux"
}

// MARK: - Base Command Options

public struct BaseCommandOptions {
    public var verbose: Bool
    public var debug: Bool
    public var yes: Bool
    public var version: Bool
    public var prettyJson: Bool
    public var apiTimeout: Int?

    public init(
        verbose: Bool = false,
        debug: Bool = false,
        yes: Bool = false,
        version: Bool = false,
        prettyJson: Bool = false,
        apiTimeout: Int? = nil
    ) {
        self.verbose = verbose
        self.debug = debug
        self.yes = yes
        self.version = version
        self.prettyJson = prettyJson
        self.apiTimeout = apiTimeout
    }

    public init() {
        self.verbose = false
        self.debug = false
        self.yes = false
        self.version = false
        self.prettyJson = false
        self.apiTimeout = nil
    }

    public func toArguments() -> [String] {
        var args: [String] = []

        if verbose { args.append("-v") }
        if debug { args.append("--debug") }
        if yes { args.append("-y") }
        if version { args.append("-V") }
        if prettyJson { args.append("-J") }
        if let timeout = apiTimeout {
            args.append("-A")
            args.append("\(timeout)")
        }

        return args
    }
}

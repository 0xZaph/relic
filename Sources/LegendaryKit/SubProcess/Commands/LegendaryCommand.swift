// MARK: - Main Command Enum

public enum LegendaryCommand: Sendable {
    case auth(AuthCommandOptions)
    case `import`(ImportCommandOptions)
    case list(ListCommandOptions)
    case info(InfoCommandOptions)
    case none

    public func toArguments(withBase baseOptions: BaseCommandOptions = BaseCommandOptions())
        -> [String]
    {
        var args: [String] = []
        args += baseOptions.toArguments()
        switch self {
        case .auth(let options):    args += options.toArguments()
        case .import(let options):  args += options.toArguments()
        case .list(let options):    args += options.toArguments()
        case .info(let options):    args += options.toArguments()
        case .none:                 break
        }
        return args
    }

    public func toArguments() -> [String] {
        var args: [String] = []
        switch self {
        case .auth(let options):    args += options.toArguments()
        case .import(let options):  args += options.toArguments()
        case .list(let options):    args += options.toArguments()
        case .info(let options):    args += options.toArguments()
        case .none:                 break
        }
        return args
    }
}

// MARK: - Convenience Initializers

extension LegendaryCommand {
    /// Create an auth command with a code
    public static func authWithCode(_ code: String, disableWebview: Bool = true)
        -> LegendaryCommand
    {
        .auth(AuthCommandOptions(code: code, disableWebview: disableWebview))
    }

    /// List games for platform
    public static func listWithPlatform(_ platform: LegendaryPlatform) -> LegendaryCommand {
        .list(ListCommandOptions(platform: platform))
    }

    /// Create an import command
    public static func importGame(
        _ appName: String,
        from installationDirectory: String,
        platform: LegendaryPlatform? = nil,
        withDlcs: Bool = true
    ) -> LegendaryCommand {
        .import(
            ImportCommandOptions(
                appName: appName,
                installationDirectory: installationDirectory,
                withDlcs: withDlcs,
                platform: platform
            )
        )
    }
}

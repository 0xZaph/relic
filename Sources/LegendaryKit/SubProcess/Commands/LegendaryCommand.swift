// MARK: - Main Command Enum

public enum LegendaryCommand {
    case auth(AuthCommandOptions)
    case `import`(ImportCommandOptions)
    case list(ListCommandOptions)
    case none

    /// Convert the command to command-line arguments
    /// - Parameter baseOptions: Optional base command options that apply to all commands
    /// - Returns: Array of command-line arguments ready to be passed to legendary
    public func toArguments(withBase baseOptions: BaseCommandOptions = BaseCommandOptions())
        -> [String]
    {
        var args: [String] = []

        // Add base options first
        args += baseOptions.toArguments()

        // Add subcommand-specific arguments
        switch self {
        case .auth(let options):
            args += options.toArguments()
        case .import(let options):
            args += options.toArguments()
        case .list(let options):
            args += options.toArguments()
        case .none:
            break
        }

        return args
    }

    /// Convert the command to command-line arguments
    /// - Returns: Array of command-line arguments ready to be passed to legendary
    public func toArguments()
        -> [String]
    {
        var args: [String] = []

        // Add subcommand-specific arguments
        switch self {
        case .auth(let options):
            args += options.toArguments()
        case .import(let options):
            args += options.toArguments()
        case .list(let options):
            args += options.toArguments()
        case .none:
            break
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
        withDlcs: Bool = false
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

import Foundation

// MARK: - Launch Parameters

/// All resolved parameters needed to launch a game.
/// Mirrors legendary's `LaunchParameters` dataclass from `core.py`.
public struct LaunchParameters: Sendable {
    /// The game executable path relative to `gameDirectory`.
    public var gameExecutable: String
    /// Absolute path to the game's install directory.
    public var gameDirectory: String
    /// Working directory for the process (usually the folder containing the exe).
    public var workingDirectory: String

    /// Prefix of the launch command: [wrapper?, wine_binary] or empty for native.
    public var launchCommand: [String]
    /// Environment variable overrides to apply on top of the inherited environment.
    public var environment: [String: String]

    /// Optional pre-launch command and whether to wait for it to finish.
    public var preLaunchCommand: String?
    public var preLaunchWait: Bool

    /// Parameters derived from the game manifest / install metadata.
    public var gameParameters: [String]
    /// Epic authentication / portal parameters.
    public var eglParameters: [String]
    /// User-supplied extra parameters.
    public var userParameters: [String]

    public init(
        gameExecutable: String = "",
        gameDirectory: String = "",
        workingDirectory: String = "",
        launchCommand: [String] = [],
        environment: [String: String] = [:],
        preLaunchCommand: String? = nil,
        preLaunchWait: Bool = false,
        gameParameters: [String] = [],
        eglParameters: [String] = [],
        userParameters: [String] = []
    ) {
        self.gameExecutable = gameExecutable
        self.gameDirectory = gameDirectory
        self.workingDirectory = workingDirectory
        self.launchCommand = launchCommand
        self.environment = environment
        self.preLaunchCommand = preLaunchCommand
        self.preLaunchWait = preLaunchWait
        self.gameParameters = gameParameters
        self.eglParameters = eglParameters
        self.userParameters = userParameters
    }

    /// The full command line as a flat array: launchCommand + exe + gameParams + eglParams + userParams.
    public var fullCommandLine: [String] {
        let exePath = (gameDirectory as NSString).appendingPathComponent(gameExecutable)
        return launchCommand + [exePath] + gameParameters + eglParameters + userParameters
    }

}

// MARK: - Launch Error

public enum LaunchError: Error, LocalizedError {
    case gameNotInstalled(String)
    case gameNotFound(String)
    case invalidExecutablePath(String)
    case authenticationRequired

    public var errorDescription: String? {
        switch self {
        case .gameNotInstalled(let name):
            return "'\(name)' is not installed."
        case .gameNotFound(let name):
            return "Game '\(name)' not found in library."
        case .invalidExecutablePath(let path):
            return "Executable path is invalid: \(path)"
        case .authenticationRequired:
            return "Authentication token required for online launch."
        }
    }
}

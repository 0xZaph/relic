import Foundation
import Subprocess

#if canImport(Darwin)
    import System
#else
    import SystemPackage
#endif

// MARK: - Command Result

public struct CommandResult: Sendable {
    public let standardOutput: String
    public let standardError: String
    public let exitCode: Int32
    public let command: String
    public let processID: Int32

    public var success: Bool {
        exitCode == 0
    }

    public init(
        standardOutput: String,
        standardError: String,
        exitCode: Int32,
        command: String,
        processID: Int32
    ) {
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.exitCode = exitCode
        self.command = command
        self.processID = processID
    }
}

// MARK: - Runner Options

public struct RunnerOptions: Sendable {
    public var environment: [String: String]?
    public var workingDirectory: String?
    public var outputLimit: Int
    public var logOutput: Bool

    public init(
        environment: [String: String]? = nil,
        workingDirectory: String? = nil,
        outputLimit: Int = 1024 * 1024,
        logOutput: Bool = false
    ) {
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.outputLimit = outputLimit
        self.logOutput = logOutput
    }
}

// MARK: - Legendary Runner

/// Runner for executing Legendary CLI commands asynchronously via Subprocess
public struct LegendaryRunner: Sendable {
    private let legendaryPath: String

    public init(legendaryPath: String) {
        self.legendaryPath = legendaryPath
    }

    public init() {
        self.legendaryPath = legendaryBinaryPath()
    }

    // MARK: - Public API

    /// Run a Legendary command asynchronously and return a CommandResult
    public func run(
        _ command: LegendaryCommand,
        baseOptions: BaseCommandOptions = BaseCommandOptions(),
        options: RunnerOptions = RunnerOptions()
    ) async throws -> CommandResult {
        let args = command.toArguments(withBase: baseOptions)
        let fullCommand = ([legendaryPath] + args).joined(separator: " ")

        if options.logOutput {
            print("Running: legendary \(args.joined(separator: " "))")
        }

        // Build environment: inherit parent env, then layer in any custom vars
        var env: Subprocess.Environment = .inherit
        if let customEnv = options.environment {
            env = env.updating(
                customEnv.reduce(into: [Subprocess.Environment.Key: String]()) { dict, pair in
                    dict[Subprocess.Environment.Key(stringLiteral: pair.key)] = pair.value
                }
            )
        }
        env = env.updating(["LEGENDARY_CONFIG_PATH": legendaryConfigPath()])

        let workingDir = options.workingDirectory.map { FilePath($0) }

        let result = try await Subprocess.run(
            .path(FilePath(legendaryPath)),
            arguments: Subprocess.Arguments(args),
            environment: env,
            workingDirectory: workingDir,
            output: .string(limit: options.outputLimit),
            error: .string(limit: options.outputLimit)
        )

        let stdoutString = result.standardOutput ?? ""
        let stderrString = result.standardError ?? ""

        if options.logOutput {
            if !stdoutString.isEmpty { print("stdout:", stdoutString) }
            if !stderrString.isEmpty { print("stderr:", stderrString) }
            print("Exit code:", exitCode(from: result.terminationStatus))
        }

        return CommandResult(
            standardOutput: stdoutString,
            standardError: stderrString,
            exitCode: exitCode(from: result.terminationStatus),
            command: fullCommand,
            processID: result.processIdentifier.value
        )
    }

    // MARK: - Helpers

    private func exitCode(from status: TerminationStatus) -> Int32 {
        switch status {
        case .exited(let code): return code
        #if !os(Windows)
            case .signaled(let code): return code
        #endif
        }
    }
}

// MARK: - Error Types

public enum LegendaryError: Error, CustomStringConvertible {
    case commandFailed(exitCode: Int32, stderr: String)
    case binaryNotFound
    case invalidOutput(String)

    public var description: String {
        switch self {
        case .commandFailed(let code, let stderr):
            return "Command failed with exit code \(code): \(stderr)"
        case .binaryNotFound:
            return "Legendary binary not found in PATH"
        case .invalidOutput(let message):
            return "Invalid output: \(message)"
        }
    }
}

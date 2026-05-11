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
        exitCode == 0 && !standardError.contains("CRITICAL") && !standardError.contains("ERROR")
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

    private class StreamState: @unchecked Sendable {
        var stdoutData = Data()
        var stderrData = Data()
        var currentProgress: Double = 0.0
        var currentETA: String = ""
        let lock = NSLock()
    }

    /// Run a Legendary command using Foundation Process to intercept output and report progress
    public func runWithProgress(
        _ command: LegendaryCommand,
        baseOptions: BaseCommandOptions = BaseCommandOptions(),
        options: RunnerOptions = RunnerOptions(),
        onProgress: @escaping @Sendable (Double, String) -> Void
    ) async throws -> CommandResult {
        let args = command.toArguments(withBase: baseOptions)
        let fullCommand = ([legendaryPath] + args).joined(separator: " ")

        if options.logOutput {
            print("Running: legendary \(args.joined(separator: " "))")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: legendaryPath)
        process.arguments = args

        var env = ProcessInfo.processInfo.environment
        if let customEnv = options.environment {
            for (k, v) in customEnv {
                env[k] = v
            }
        }
        env["LEGENDARY_CONFIG_PATH"] = legendaryConfigPath()
        process.environment = env

        if let wd = options.workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        // Redirect stdin to /dev/null — legendary must never block waiting for input.
        // The -y flag handles prompts; if it tries to read stdin anyway it gets EOF.
        process.standardInput = FileHandle.nullDevice

        let state = StreamState()

        outPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty { return }
            state.lock.lock()
            state.stdoutData.append(data)
            state.lock.unlock()
        }

        // Match both integer and decimal percentages: "Progress: 45%" or "Progress: 45.23%"
        let progressRegex = try! NSRegularExpression(pattern: "Progress: (\\d+(?:\\.\\d+)?)%")
        let etaRegex = try! NSRegularExpression(pattern: "ETA: (\\d{2}:\\d{2}:\\d{2})")

        errPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty { return }
            state.lock.lock()
            state.stderrData.append(data)
            

            if let chunk = String(data: data, encoding: .utf8) {
                let parts = chunk.split(whereSeparator: { $0 == "\r" || $0 == "\n" })
                for part in parts {
                    let line = String(part)
                    var updated = false
                    
                    if let pMatch = progressRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                        if let r = Range(pMatch.range(at: 1), in: line), let val = Double(line[r]) {
                            state.currentProgress = val / 100.0
                            updated = true
                        }
                    }
                    if let eMatch = etaRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                        if let r = Range(eMatch.range(at: 1), in: line) {
                            state.currentETA = String(line[r])
                            updated = true
                        }
                    }
                    
                    if updated {
                        let prog = state.currentProgress
                        let eta = state.currentETA
                        state.lock.unlock()
                        onProgress(prog, eta)
                        return
                    }
                }
            }
            state.lock.unlock()
        }

        // Set terminationHandler BEFORE run() to eliminate the race where the process
        // exits before the handler is registered (which would hang us forever).
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                continuation.resume()
            }
            do {
                try process.run()
            } catch {
                // If the process couldn't start, resume immediately to avoid a hang.
                print("[LegendaryRunner] process.run() threw: \(error)")
                process.terminationHandler = nil
                continuation.resume()
            }
        }

        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil

        let stdoutString = String(data: state.stdoutData, encoding: .utf8) ?? ""
        let stderrString = String(data: state.stderrData, encoding: .utf8) ?? ""

        return CommandResult(
            standardOutput: stdoutString,
            standardError: stderrString,
            exitCode: process.terminationStatus,
            command: fullCommand,
            processID: process.processIdentifier
        )
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

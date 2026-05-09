import Foundation

/// Get the app support directory for Relic
private func appFolder() -> String {
    let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    return paths[0].appendingPathComponent("relic").path
}

/// Get the config path for Legendary
public func legendaryConfigPath() -> String {
    // Relic uses the same config path logic as LegendaryFS by default (~/.config/legendary)
    // but we can also provide a helper here that points to the app-specific folder if needed.
    // For compatibility with the CLI, we stick to the standard legendary paths.
    if let xdgConfig = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
        return URL(fileURLWithPath: xdgConfig).appendingPathComponent("legendary").path
    } else {
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/legendary").path
    }
}

public func legendaryUserInfo() -> URL {
    return URL(fileURLWithPath: legendaryConfigPath())
        .appendingPathComponent("user.json")
}

public func legendaryInstalled() -> URL {
    return URL(fileURLWithPath: legendaryConfigPath())
        .appendingPathComponent("installed.json")
}

public func legendaryMetadata() -> String {
    return URL(fileURLWithPath: legendaryConfigPath())
        .appendingPathComponent("metadata")
        .path
}

/// Get the path to the legendary binary
public func legendaryBinaryPath() -> String {
    #if os(macOS)
        // macOS: Inside the .app bundle at Contents/Resources/bin
        if let bundlePath = Bundle.main.resourcePath {
            return URL(fileURLWithPath: bundlePath)
                .appendingPathComponent("bin")
                .appendingPathComponent("legendary")
                .path
        }
    #else
        // Windows/Linux: In bin subdirectory next to the executable
        if let executablePath = Bundle.main.executablePath {
            return URL(fileURLWithPath: executablePath)
                .deletingLastPathComponent()
                .appendingPathComponent("bin")
                .appendingPathComponent("legendary")
                .path
        }
    #endif

    // Fallback
    return "legendary"
}

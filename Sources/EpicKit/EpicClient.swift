import Foundation

public struct EpicClient: Sendable {
    private var api: EPCAPIClient
    private let timeout: Int

    public init(timeout: Int, authData: OAuthResponse? = nil) {
        self.timeout = timeout
        self.api = EPCAPIClient(timeout: timeout)
        if let authData {
            self.api.authData = authData
        }
    }

    // MARK: - Authentication

    public mutating func login(
        authorizationCode: String
    ) async throws(EPCAPIError) {
        try await api.startSession(grantType: .authorizationCode(authorizationCode))
    }

    public mutating func login(refreshToken: String) async throws(EPCAPIError) {
        try await api.startSession(grantType: .refreshToken(refreshToken))
    }

    public mutating func logout() async throws(EPCAPIError) {
        try await api.invalidateSession()
    }

    public mutating func restoreSession(_ authData: OAuthResponse?) {
        api = EPCAPIClient(timeout: timeout)
        api.authData = authData
    }

    public var isAuthenticated: Bool {
        api.authData != nil
    }

    public var authData: OAuthResponse? {
        api.authData
    }

    public func getGameAssets(
        platform: String = "Windows",
        label: String = "Live"
    ) async throws(EPCAPIError) -> [GameAssetRecord] {
        try await api.getGameAssets(platform: platform, label: label)
    }

    public func getGameInfo(
        namespace: String,
        catalogItemId: String,
        appName: String,
        platform: String = "Windows"
    ) async throws(EPCAPIError) -> Data {
        try await api.getGameInfo(
            namespace: namespace,
            catalogItemId: catalogItemId,
            appName: appName,
            platform: platform
        )
    }

    public func getLibraryItems(
        includeMetadata: Bool = true
    ) async throws(EPCAPIError) -> [LibraryItemRecord] {
        try await api.getLibraryItems(includeMetadata: includeMetadata)
    }

    public func getGameManifest(
        namespace: String,
        catalogItemId: String,
        appName: String,
        platform: String = "Windows",
        label: String = "Live"
    ) async throws(EPCAPIError) -> Data {
        try await api.getGameManifest(
            namespace: namespace,
            catalogItemId: catalogItemId,
            appName: appName,
            platform: platform,
            label: label
        )
    }
}

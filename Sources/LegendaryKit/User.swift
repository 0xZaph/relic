import EpicKit
import Foundation

public class User {
    private var client = EpicClient(timeout: 10)
    private let store: LegendaryFS

    public init(store: LegendaryFS) {
        self.store = store
    }

    // MARK: - Native Auth (via EpicKit)

    public func login(authCode: String) async throws {
        try await client.login(authorizationCode: authCode)
        if let data = client.authData {
            try await store.saveUserSession(data)
        }
    }

    public func loginWithSaved() async throws {
        let savedSession = try await store.loadUserSession()

        guard let savedSession else {
            throw EPCAPIError.invalidCredentials("No saved credentials found.")
        }

        guard let refreshToken = savedSession.refreshToken else {
            throw EPCAPIError.invalidCredentials("No refresh token available.")
        }

        try await client.login(refreshToken: refreshToken)

        if let newSessionData = client.authData {
            try await store.saveUserSession(newSessionData)
        }
    }

    public func logout() async throws {
        try await store.clearUserSession()
        client = EpicClient(timeout: 10)
    }

    public func isLoggedIn() -> Bool {
        return client.isAuthenticated
    }

    public func getUserInfo() -> UserInfo? {
        guard let authData = client.authData else { return nil }
        return UserInfo(from: authData)
    }
}

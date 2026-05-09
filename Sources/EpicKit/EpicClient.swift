public enum EpicClient: ~Copyable, Sendable {
    case unauthenticated(EPCAPIClient<Unauthenticated>, timeout: Int)
    case authenticated(EPCAPIClient<Authenticated>, timeout: Int)

    public init(timeout: Int) {
        self = .unauthenticated(
            EPCAPIClient<Unauthenticated>(timeout: timeout),
            timeout: timeout
        )
    }

    // MARK: - Authentication

    public mutating func login(
        authorizationCode: String
    ) async throws(EPCAPIError) {
        switch consume self {
        case .unauthenticated(let client, let timeout):
            do {
                let authClient = try await client.startSession(
                    grantType: .authorizationCode(authorizationCode)
                )
                self = .authenticated(authClient, timeout: timeout)
            } catch {
                self = .unauthenticated(
                    EPCAPIClient<Unauthenticated>(timeout: timeout),
                    timeout: timeout
                )
                throw error
            }
        case .authenticated(let client, let timeout):
            self = .authenticated(client, timeout: timeout)
        }
    }

    public mutating func login(refreshToken: String) async throws(EPCAPIError) {
        switch consume self {
        case .unauthenticated(let client, let timeout):
            do {
                let authClient = try await client.startSession(
                    grantType: .refreshToken(refreshToken)
                )
                self = .authenticated(authClient, timeout: timeout)
            } catch {
                self = .unauthenticated(
                    EPCAPIClient<Unauthenticated>(timeout: timeout),
                    timeout: timeout
                )
                throw error
            }
        case .authenticated(let client, let timeout):
            self = .authenticated(client, timeout: timeout)
        }
    }

    public mutating func logout() async throws(EPCAPIError) {
        switch consume self {
        case .authenticated(let client, let timeout):
            do {
                let unauthClient = try await client.invalidateSession()
                self = .unauthenticated(unauthClient, timeout: timeout)
            } catch {
                self = .unauthenticated(
                    EPCAPIClient<Unauthenticated>(timeout: timeout),
                    timeout: timeout
                )
                throw error
            }
        case .unauthenticated(let client, let timeout):
            self = .unauthenticated(client, timeout: timeout)
        }
    }

    public var isAuthenticated: Bool {
        mutating get {
            switch consume self {
            case .authenticated(let client, let timeout):
                self = .authenticated(client, timeout: timeout)
                return true
            case .unauthenticated(let client, let timeout):
                self = .unauthenticated(client, timeout: timeout)
                return false
            }
        }
    }

    public var authData: OAuthResponse? {
        mutating get {
            switch consume self {
            case .authenticated(let client, let timeout):
                let data = client.authData
                self = .authenticated(client, timeout: timeout)
                return data
            case .unauthenticated(let client, let timeout):
                self = .unauthenticated(client, timeout: timeout)
                return nil
            }
        }
    }
}

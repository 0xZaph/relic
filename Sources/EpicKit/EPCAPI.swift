import Foundation

#if canImport(FoundationNetworking)
    // TODO: Replace this with AHC one day
    import FoundationNetworking
#endif

// This makes use of typestate
// If you want to learn more, pls refer to:
// https://swiftology.io/articles/typestate/

// MARK: - Authentication States

public enum Unauthenticated {}
public enum Authenticated {}

public enum EPCAPIError: Error, Sendable {
    case invalidCredentials(String)
    case serverError(Int, String?)
    case noTokenProvided
    case decodingError(Error)
    case networkError(Error)
    case invalidURL
    case missingUserId
    case correctiveActionRequired(String, URL?)
    case unknown(String)
    case filesystemError(Error)
}

extension EPCAPIError {
    public var isInvalidCredentials: Bool {
        if case .invalidCredentials = self { return true }
        return false
    }
}

public enum EpicConstants {
    public static let defaultClientId = "34a02cf8f4414e29b15921876da36f9a"
    public static let defaultClientSecret = "daafbccc737745039dffe53d94fc76cf"
    public static let oauthHost = "account-public-service-prod03.ol.epicgames.com"
    public static let userAgent =
        "UELauncher/11.0.1-14907503+++Portal+Release-Live Windows/10.0.19041.1.256.64bit"
}

// MARK: - Models

public struct OAuthResponse: Codable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let expiresAt: Date
    public let refreshToken: String?
    public let refreshExpires: Int?
    public let refreshExpiresAt: Date?

    public let accountId: String?
    public let displayName: String?
    public let clientId: String?
    public let inAppId: String?
    public let clientService: String?
    public let app: String?
    public let internalClient: Bool?

    public let authTime: Date?
    public let acr: String?
    public let scope: [String]?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case refreshToken = "refresh_token"
        case refreshExpires = "refresh_expires"
        case refreshExpiresAt = "refresh_expires_at"
        case accountId = "account_id"
        case displayName
        case clientId = "client_id"
        case inAppId = "in_app_id"
        case clientService = "client_service"
        case app
        case internalClient = "internal_client"
        case authTime = "auth_time"
        case acr
        case scope
    }
}

public struct APIError: Codable, Sendable {
    public let errorCode: String
    public let errorMessage: String
    public let correctiveAction: String?
    public let continuationUrl: String?
}

public enum GrantType {
    case refreshToken(String)
    case authorizationCode(String)

    var parameters: [String: String] {
        switch self {
        case .refreshToken(let token):
            return [
                "grant_type": "refresh_token",
                "refresh_token": token,
                "token_type": "eg1",
            ]
        case .authorizationCode(let code):
            return [
                "grant_type": "authorization_code",
                "code": code,
                "token_type": "eg1",
            ]
        }
    }
}

// MARK: - Typestate API Client

public struct EPCAPIClient<State>: ~Copyable, Sendable {
    private let clientId: String
    private let clientSecret: String
    private let timeout: Int
    private let session: URLSession
    private let oauthHost = EpicConstants.oauthHost

    public let authData: OAuthResponse?

    private init(
        clientId: String,
        clientSecret: String,
        timeout: Int,
        session: URLSession,
        authData: OAuthResponse?
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.timeout = timeout
        self.session = session
        self.authData = authData
    }

    private static var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func url(for host: String, path: String) throws(EPCAPIError) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        guard let url = components.url else { throw .invalidURL }
        return url
    }

    private func perform<T: Decodable>(
        _ request: URLRequest
    ) async throws(EPCAPIError) -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode >= 400 {
            if let apiError = try? Self.jsonDecoder.decode(
                APIError.self,
                from: data
            ) {
                if apiError.errorCode
                    == "errors.com.epicgames.oauth.corrective_action_required"
                {
                    let url = apiError.continuationUrl.flatMap {
                        URL(string: $0)
                    }
                    throw .correctiveActionRequired(apiError.errorMessage, url)
                }
                throw .invalidCredentials(apiError.errorCode)
            }
            let errorString = String(data: data, encoding: .utf8)
            throw .serverError(httpResponse.statusCode, errorString)
        }

        do {
            return try Self.jsonDecoder.decode(T.self, from: data)
        } catch {
            throw .decodingError(error)
        }
    }
}

// MARK: - Unauthenticated State

extension EPCAPIClient where State == Unauthenticated {

    public init(
        clientId: String = EpicConstants.defaultClientId,
        clientSecret: String = EpicConstants.defaultClientSecret,
        timeout: Int
    ) {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpMaximumConnectionsPerHost = 16
        sessionConfig.timeoutIntervalForRequest = .init(timeout)
        sessionConfig.httpAdditionalHeaders = [
            "User-Agent": EpicConstants.userAgent
        ]

        let session = URLSession(configuration: sessionConfig)

        self.init(
            clientId: clientId,
            clientSecret: clientSecret,
            timeout: timeout,
            session: session,
            authData: nil
        )
    }

    public consuming func startSession(
        grantType: GrantType
    ) async throws(EPCAPIError) -> EPCAPIClient<Authenticated> {
        let url = try url(for: oauthHost, path: "/account/api/oauth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(basicAuthHeader(), forHTTPHeaderField: "Authorization")
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )

        let bodyString = grantType.parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let oauthResponse: OAuthResponse = try await perform(request)

        return EPCAPIClient<Authenticated>(
            clientId: clientId,
            clientSecret: clientSecret,
            timeout: timeout,
            session: session,
            authData: oauthResponse
        )
    }

    private func basicAuthHeader() -> String {
        let credentials = "\(clientId):\(clientSecret)"
        let encodedCredentials = Data(credentials.utf8).base64EncodedString()
        return "Basic \(encodedCredentials)"
    }
}

// MARK: - Authenticated State

extension EPCAPIClient where State == Authenticated {

    public consuming func invalidateSession() async throws(EPCAPIError) -> EPCAPIClient<
        Unauthenticated
    > {
        guard let token = authData?.accessToken else {
            throw .noTokenProvided
        }

        let url = try url(
            for: oauthHost,
            path: "/account/api/oauth/sessions/kill/\(token)"
        )
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        _ = try? await session.data(for: request)

        return EPCAPIClient<Unauthenticated>(
            clientId: clientId,
            clientSecret: clientSecret,
            timeout: timeout
        )
    }
}

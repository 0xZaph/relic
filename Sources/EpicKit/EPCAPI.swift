import Foundation

#if canImport(FoundationNetworking)
    // TODO: Replace this with AHC one day
    import FoundationNetworking
#endif

// This was previously using typestate, but has been simplified
// to regular Swift struct management.

// MARK: - Errors

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
    public static let launcherHost = "launcher-public-service-prod06.ol.epicgames.com"
    public static let catalogHost = "catalog-public-service-prod06.ol.epicgames.com"
    public static let libraryHost = "library-service.live.use1a.on.epicgames.com"
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

public struct JSONValue: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        }
        else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        }
        else if let int = try? container.decode(Int.self) {
            self.value = int
        }
        else if let double = try? container.decode(Double.self) {
            self.value = double
        }
        else if let string = try? container.decode(String.self) {
            self.value = string
        }
        else if let array = try? container.decode([JSONValue].self) {
            self.value = array.map { $0.value }
        }
        else if let dictionary = try? container.decode([String: JSONValue].self) {
            self.value = dictionary.mapValues { $0.value }
        }
        else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "JSON value cannot be decoded"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { JSONValue($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { JSONValue($0) })
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "JSON value cannot be encoded"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}

public struct GameAssetRecord: Codable, Sendable {
    public let appName: String
    public let assetId: String
    public let buildVersion: String
    public let catalogItemId: String
    public let labelName: String
    public let namespace: String
    public let metadata: [String: JSONValue]?
    public let sidecarRvn: Int?
}

private struct LibraryItemsResponse: Codable {
    let records: [LibraryItemRecord]
    let responseMetadata: ResponseMetadata

    struct ResponseMetadata: Codable {
        let nextCursor: String?
    }
}

public struct LibraryItemRecord: Codable, Sendable {
    public let appName: String?
    public let namespace: String
    public let catalogItemId: String
    public let sandboxType: String?
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

// MARK: - API Client

public struct EPCAPIClient: Sendable {
    private let clientId: String
    private let clientSecret: String
    private let timeout: Int
    private let session: URLSession
    private let oauthHost = EpicConstants.oauthHost

    public var authData: OAuthResponse?

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

        self.clientId = clientId
        self.clientSecret = clientSecret
        self.timeout = timeout
        self.session = URLSession(configuration: sessionConfig)
        self.authData = nil
    }

    internal init(
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

    private func applyingAuthorizationHeaderIfNeeded(
        to request: URLRequest
    ) -> URLRequest {
        guard request.value(forHTTPHeaderField: "Authorization") == nil,
              let token = authData?.accessToken
        else {
            return request
        }

        var authorizedRequest = request
        authorizedRequest.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        return authorizedRequest
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
        let request = applyingAuthorizationHeaderIfNeeded(to: request)

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
            let errorString = String(data: data, encoding: .utf8)
            print("[EPCAPI] request failed status=\(httpResponse.statusCode) body=\(errorString ?? "<binary>")")
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
            throw .serverError(httpResponse.statusCode, errorString)
        }

        do {
            return try Self.jsonDecoder.decode(T.self, from: data)
        } catch {
            throw .decodingError(error)
        }
    }

    private func performData(
        _ request: URLRequest
    ) async throws(EPCAPIError) -> Data {
        let request = applyingAuthorizationHeaderIfNeeded(to: request)

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
            let errorString = String(data: data, encoding: .utf8)
            print("[EPCAPI] request failed status=\(httpResponse.statusCode) body=\(errorString ?? "<binary>")")
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
            throw .serverError(httpResponse.statusCode, errorString)
        }

        return data
    }

    public mutating func startSession(
        grantType: GrantType
    ) async throws(EPCAPIError) {
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
        self.authData = oauthResponse
    }

    public func getGameAssets(
        platform: String = "Windows",
        label: String = "Live"
    ) async throws(EPCAPIError) -> [GameAssetRecord] {
        let url = try url(
            for: EpicConstants.launcherHost,
            path: "/launcher/api/public/assets/\(platform)"
        )
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "label", value: label)]
        guard let requestURL = components?.url else {
            throw .invalidURL
        }

        let request = URLRequest(url: requestURL)
        return try await perform(request)
    }

    public func getGameInfo(
        namespace: String,
        catalogItemId: String,
        appName: String,
        platform: String = "Windows"
    ) async throws(EPCAPIError) -> Data {
        let url = try url(
            for: EpicConstants.catalogHost,
            path: "/catalog/api/shared/namespace/\(namespace)/bulk/items"
        )
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "id", value: catalogItemId),
            URLQueryItem(name: "includeDLCDetails", value: "true"),
            URLQueryItem(name: "includeMainGameDetails", value: "true"),
            URLQueryItem(name: "country", value: "US"),
            URLQueryItem(name: "locale", value: "en")
        ]
        guard let requestURL = components?.url else {
            throw .invalidURL
        }

        return try await performData(URLRequest(url: requestURL))
    }

    public func getLibraryItems(
        includeMetadata: Bool = true
    ) async throws(EPCAPIError) -> [LibraryItemRecord] {
        var records: [LibraryItemRecord] = []
        var cursor: String? = nil

        repeat {
            let url = try url(
                for: EpicConstants.libraryHost,
                path: "/library/api/public/items"
            )
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            var queryItems = [
                URLQueryItem(name: "includeMetadata", value: includeMetadata ? "true" : "false")
            ]
            if let cursor {
                queryItems.append(URLQueryItem(name: "cursor", value: cursor))
            }
            components?.queryItems = queryItems
            guard let requestURL = components?.url else {
                throw .invalidURL
            }

            let page: LibraryItemsResponse = try await perform(URLRequest(url: requestURL))
            records.append(contentsOf: page.records)
            cursor = page.responseMetadata.nextCursor
            if cursor?.isEmpty == true {
                cursor = nil
            }
        } while cursor != nil

        return records
    }

    public mutating func invalidateSession() async throws(EPCAPIError) {
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
        self.authData = nil
    }

    private func basicAuthHeader() -> String {
        let credentials = "\(clientId):\(clientSecret)"
        let encodedCredentials = Data(credentials.utf8).base64EncodedString()
        return "Basic \(encodedCredentials)"
    }
}


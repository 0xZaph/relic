import Foundation
import EpicKit

// MARK: - App Models

public struct UserInfo {
    public let username: String
    public let userID: String

    public init(username: String, userID: String) {
        self.username = username
        self.userID = userID
    }

    init(from user: Legendary.UserInfo) {
        self.username = user.displayName
        self.userID = user.accountID
    }

    init(from oauth: OAuthResponse) {
        self.username = oauth.displayName ?? "Unknown User"
        self.userID = oauth.accountId ?? "unknown_id"
    }
}

public struct GameInfo {
    public let appName: String
    public let title: String
    public let developer: String?
    public let artCover: String?
    public let artSquare: String?
    public let artLogo: String?
    public let description: String?
    public let isInstalled: Bool
    public let installPath: String?
    /// Keys are platform strings e.g. "Windows", "Mac"
    public let platformVersions: [String: String]

    public init(
        appName: String,
        title: String,
        developer: String? = nil,
        artCover: String? = nil,
        artSquare: String? = nil,
        artLogo: String? = nil,
        description: String? = nil,
        isInstalled: Bool = false,
        installPath: String? = nil,
        platformVersions: [String: String] = [:]
    ) {
        self.appName = appName
        self.title = title
        self.developer = developer
        self.artCover = artCover
        self.artSquare = artSquare
        self.artLogo = artLogo
        self.description = description
        self.isInstalled = isInstalled
        self.installPath = installPath
        self.platformVersions = platformVersions
    }
}

/// Manifest-derived details fetched on demand (requires an API call).
public struct GameDetails {
    public let appName: String
    public let buildVersion: String
    public let diskSize: Int64       // bytes, uncompressed install size
    public let downloadSize: Int64   // bytes, compressed download size
    public let launchExe: String
    public let numFiles: Int
    public let numChunks: Int
    public let platform: String

    public init(
        appName: String,
        buildVersion: String,
        diskSize: Int64,
        downloadSize: Int64,
        launchExe: String,
        numFiles: Int,
        numChunks: Int,
        platform: String
    ) {
        self.appName = appName
        self.buildVersion = buildVersion
        self.diskSize = diskSize
        self.downloadSize = downloadSize
        self.launchExe = launchExe
        self.numFiles = numFiles
        self.numChunks = numChunks
        self.platform = platform
    }
}

// MARK: - Legendary Models (Internal representation)

public enum Legendary {
    public enum LegendaryInstallPlatform: String, Codable {
        case windows = "Windows"
        case win32 = "Win32"
        case mac = "Mac"
        case android = "Android"
        case iOS = "iOS"
    }
    public struct Prerequisite: Codable {
        public let args: String
        public let ids: [String]
        public let name: String
        public let path: String
    }
    public struct CustomAttributeValue: Codable {
        public let type: String
        public let value: String
    }
    public struct KeyImage: Codable {
        public let height: Int
        public let md5: String
        public let size: Int
        public let type: String
        public let uploadedDate: String
        public let url: String
        public let width: Int
        public let alt: String?
    }
    public struct Category: Codable {
        public let path: String
    }
    public struct ReleaseInfo: Codable {
        public let appId: String
        public let id: String
        public let platform: [String]?
        public let dateAdded: String?
    }
    public struct MainGameItem: Codable {
        public let id: String
        public let namespace: String
        public let unsearchable: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case namespace
            case unsearchable
        }
    }
    public struct AssetInfo: Codable {
        public let appName: String
        public let assetId: String
        public let buildVersion: String
        public let catalogItemId: String
        public let labelName: String
        public let metadata: [String: AnyCodable]
        public let namespace: String

        enum CodingKeys: String, CodingKey {
            case appName = "app_name"
            case assetId = "asset_id"
            case buildVersion = "build_version"
            case catalogItemId = "catalog_item_id"
            case labelName = "label_name"
            case metadata
            case namespace
        }
    }
    public struct GameMetadataInner: Codable {
        public let ageGatings: AnyCodable?
        public let applicationId: String?
        public let categories: [Category]?
        public let creationDate: String?
        public let customAttributes: [String: CustomAttributeValue]?
        public let description: String?
        public let developer: String?
        public let developerId: String?
        public let dlcItemList: [GameMetadataInner]?
        public let endOfSupport: Bool?
        public let entitlementName: String?
        public let entitlementType: String?
        public let eulaIds: [String]?
        public let id: String?
        public let itemType: String?
        public let keyImages: [KeyImage]?
        public let lastModifiedDate: String?
        public let mainGameItem: MainGameItem?
        public let mainGameItemList: [MainGameItem]?
        public let shortDescription: String?
        public let namespace: String?
        public let releaseInfo: [ReleaseInfo]?
        public let requiresSecureAccount: Bool?
        public let selfRefundable: Bool?
        public let status: String?
        public let technicalDetails: String?
        public let title: String?
        public let unsearchable: Bool?
        public let useCount: Int?

        enum CodingKeys: String, CodingKey {
            case ageGatings
            case applicationId
            case categories
            case creationDate
            case customAttributes
            case description
            case developer
            case developerId
            case dlcItemList
            case endOfSupport
            case entitlementName
            case entitlementType
            case eulaIds
            case id
            case itemType
            case keyImages
            case lastModifiedDate
            case mainGameItem
            case mainGameItemList
            case shortDescription
            case namespace
            case releaseInfo
            case requiresSecureAccount
            case selfRefundable
            case status
            case technicalDetails
            case title
            case unsearchable
            case useCount
        }
    }
    public struct GameMetadata: Codable {
        public let appName: String
        public let appTitle: String
        public let assetInfos: [String: AssetInfo]
        public let baseUrls: [String]
        public let metadata: GameMetadataInner

        enum CodingKeys: String, CodingKey {
            case appName = "app_name"
            case appTitle = "app_title"
            case assetInfos = "asset_infos"
            case baseUrls = "base_urls"
            case metadata
        }
    }
    public struct InstalledJsonMetadata: Codable {
        public let appName: String
        public let baseUrls: [String]
        public let canRunOffline: Bool
        public let eglGuid: String
        public let executable: String
        public let installPath: String
        public let installSize: Int64
        public let installTags: [String]
        public let isDlc: Bool
        public let launchParameters: String
        public let manifestPath: String?
        public let needsVerification: Bool
        public let platform: LegendaryInstallPlatform
        public let prereqInfo: [Prerequisite]?
        public let requiresOt: Bool
        public let savePath: String?
        public let title: String
        public let version: String

        enum CodingKeys: String, CodingKey {
            case appName = "app_name"
            case baseUrls = "base_urls"
            case canRunOffline = "can_run_offline"
            case eglGuid = "egl_guid"
            case executable
            case installPath = "install_path"
            case installSize = "install_size"
            case installTags = "install_tags"
            case isDlc = "is_dlc"
            case launchParameters = "launch_parameters"
            case manifestPath = "manifest_path"
            case needsVerification = "needs_verification"
            case platform
            case prereqInfo = "prereq_info"
            case requiresOt = "requires_ot"
            case savePath = "save_path"
            case title
            case version
        }
    }
    public struct DLCInfo: Codable {
        public let appName: String
        public let title: String
        public let isInstalled: Bool?

        enum CodingKeys: String, CodingKey {
            case appName = "app_name"
            case title
            case isInstalled = "is_installed"
        }
    }
    public struct LaunchOption: Codable {
        public let name: String
        public let parameters: String
    }
    public struct TagInfo: Codable {
        public let tag: String
        public let count: Int
        public let size: Int64
    }
    public struct GameManifest: Codable {
        public let appName: String
        public let buildId: String
        public let buildVersion: String
        public let diskSize: Int64
        public let downloadSize: Int64
        public let featureLevel: Int
        public let installTags: [String]
        public let launchCommand: String
        public let launchExe: String
        public let numChunks: Int
        public let numFiles: Int
        public let prerequisites: Prerequisite?
        public let size: Int64
        public let tagDiskSize: [TagInfo]
        public let tagDownloadSize: [TagInfo]
        public let type: String
        public let version: Int

        enum CodingKeys: String, CodingKey {
            case appName = "app_name"
            case buildId = "build_id"
            case buildVersion = "build_version"
            case diskSize = "disk_size"
            case downloadSize = "download_size"
            case featureLevel = "feature_level"
            case installTags = "install_tags"
            case launchCommand = "launch_command"
            case launchExe = "launch_exe"
            case numChunks = "num_chunks"
            case numFiles = "num_files"
            case prerequisites
            case size
            case tagDiskSize = "tag_disk_size"
            case tagDownloadSize = "tag_download_size"
            case type
            case version
        }
    }
    public struct GameInstallInfo: Codable {
        public let appName: String
        public let cloudSaveFolder: String?
        public let cloudSaveFolderMac: String?
        public let cloudSavesSupported: Bool
        public let externalActivation: String
        public let isDlc: Bool
        public let launchOptions: [LaunchOption]
        public let ownedDlc: [DLCInfo]
        public let platformVersions: [String: String]
        public let title: String
        public let version: String

        enum CodingKeys: String, CodingKey {
            case appName = "app_name"
            case cloudSaveFolder = "cloud_save_folder"
            case cloudSaveFolderMac = "cloud_save_folder_mac"
            case cloudSavesSupported = "cloud_saves_supported"
            case externalActivation = "external_activation"
            case isDlc = "is_dlc"
            case launchOptions = "launch_options"
            case ownedDlc = "owned_dlc"
            case platformVersions = "platform_versions"
            case title
            case version
        }
    }
    public struct LegendaryInstallInfo: Codable {
        public let game: GameInstallInfo
        public let manifest: GameManifest
    }
    public struct SelectiveDownload: Codable {
        public let tags: [String]
        public let name: String
        public let description: String
        public let required: Bool?
    }
    public struct GameOverride: Codable {
        public let executableOverride: [String: [String: String]]
        public let reorderOptimization: [String: [String]]
        public let sdlConfig: [String: Int]

        enum CodingKeys: String, CodingKey {
            case executableOverride = "executable_override"
            case reorderOptimization = "reorder_optimization"
            case sdlConfig = "sdl_config"
        }
    }
    public struct LegendaryConfig: Codable {
        public let webviewKillswitch: Bool

        enum CodingKeys: String, CodingKey {
            case webviewKillswitch = "webview_killswitch"
        }
    }
    public struct ResponseDataLegendaryAPI: Codable {
        public let eglConfig: AnyCodable
        public let gameOverrides: GameOverride
        public let legendaryConfig: LegendaryConfig
        public let runtimes: [AnyCodable]

        enum CodingKeys: String, CodingKey {
            case eglConfig = "egl_config"
            case gameOverrides = "game_overrides"
            case legendaryConfig = "legendary_config"
            case runtimes
        }
    }
    public struct UserInfo: Codable {
        public let accessToken: String
        public let accountID: String
        public let acr: String
        public let app: String
        public let authTime: String
        public let clientID: String
        public let clientService: String
        public let displayName: String
        public let expiresAt: String
        public let expiresIn: Int
        public let inAppId: String
        public let internalClient: Bool
        public let refreshExpiresIn: Int
        public let refreshExpiresAt: String
        public let refreshToken: String
        public let scope: [String]
        public let tokenType: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountID = "account_id"
            case acr
            case app
            case authTime = "auth_time"
            case clientID = "client_id"
            case clientService = "client_service"
            case displayName
            case expiresAt = "expires_at"
            case expiresIn = "expires_in"
            case inAppId = "in_app_id"
            case internalClient = "internal_client"
            case refreshExpiresIn = "refresh_expires"
            case refreshExpiresAt = "refresh_expires_at"
            case refreshToken = "refresh_token"
            case scope
            case tokenType = "token_type"
        }
    }
    public struct AnyCodable: Codable {
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
            else if let array = try? container.decode([AnyCodable].self) {
                self.value = array.map { $0.value }
            }
            else if let dictionary = try? container.decode([String: AnyCodable].self) {
                self.value = dictionary.mapValues { $0.value }
            }
            else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "AnyCodable value cannot be decoded"
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
                try container.encode(array.map { AnyCodable($0) })
            case let dictionary as [String: Any]:
                try container.encode(dictionary.mapValues { AnyCodable($0) })
            default:
                let context = EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
                throw EncodingError.invalidValue(value, context)
            }
        }
    }
}

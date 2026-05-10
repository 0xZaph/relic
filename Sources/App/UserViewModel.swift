import Foundation
import QtBridge
import LegendaryKit

@MainActor
@QtBridgeable
public final class UserViewModel {
    private let user: User
    private let store: LegendaryFS

    public var isLoggedIn: Bool = false
    public var username: String = ""
    public var errorMessage: String = ""

    public var onAuthenticated: (() -> Void)?

    public init() {
        self.store = try! LegendaryFS()
        self.user = User(store: store)

        print("[UserViewModel] init")
        refreshState()
    }

    public func refreshState() {
        self.isLoggedIn = user.isLoggedIn()
        if let info = user.getUserInfo() {
            self.username = info.username
        } else {
            self.username = ""
        }
        print("[UserViewModel] refreshState loggedIn=\(isLoggedIn) username=\(username)")
    }

    public func login(code: String) {
        print("[UserViewModel] login requested")
        Task {
            do {
                try await user.login(authCode: code)
                refreshState()
                errorMessage = ""
                onAuthenticated?()
            } catch {
                errorMessage = "Login failed: \(error.localizedDescription)"
            }
        }
    }

    public func loginWithSaved() {
        print("[UserViewModel] loginWithSaved requested")
        Task {
            do {
                try await user.loginWithSaved()
                refreshState()
                errorMessage = ""
                onAuthenticated?()
            } catch {
                // Not necessarily an error the user needs to see if it just means no saved session
                refreshState()
            }
        }
    }

    public func logout() {
        print("[UserViewModel] logout requested")
        Task {
            try? await user.logout()
            refreshState()
        }
    }
}

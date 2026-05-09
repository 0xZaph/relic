import Foundation
import QtBridge
import LegendaryKit

@MainActor
@QtBridgeable
public final class AppViewModel {
    private let user: User
    private let store: LegendaryFS

    public var isLoggedIn: Bool = false
    public var username: String = ""
    public var errorMessage: String = ""

    public init() {
        self.store = try! LegendaryFS()
        self.user = User(store: store)
        
        refreshState()
        loginWithSaved()
    }

    public func refreshState() {
        self.isLoggedIn = user.isLoggedIn()
        if let info = user.getUserInfo() {
            self.username = info.username
        } else {
            self.username = ""
        }
    }

    public func login(code: String) {
        Task {
            do {
                try await user.login(authCode: code)
                refreshState()
                errorMessage = ""
            } catch {
                errorMessage = "Login failed: \(error.localizedDescription)"
            }
        }
    }

    public func loginWithSaved() {
        Task {
            do {
                try await user.loginWithSaved()
                refreshState()
                errorMessage = ""
            } catch {
                // Not necessarily an error the user needs to see if it just means no saved session
                refreshState()
            }
        }
    }

    public func logout() {
        Task {
            try? await user.logout()
            refreshState()
        }
    }
}

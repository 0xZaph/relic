import Foundation
import QtBridge
import LegendaryKit

@MainActor
@QtBridgeable
public final class AppViewModel {
    @QtTracked public var userViewModel: UserViewModel
    @QtTracked public var libraryViewModel: LibraryViewModel

    public var isLoggedIn: Bool { userViewModel.isLoggedIn }
    public var username: String { userViewModel.username }
    public var errorMessage: String { userViewModel.errorMessage }

    public init() {
        print("[AppViewModel] init")
        self.userViewModel = UserViewModel()
        self.libraryViewModel = LibraryViewModel()

        self.userViewModel.onAuthenticated = { [weak libraryViewModel] in
            print("[AppViewModel] authenticated, refreshing library")
            libraryViewModel?.refreshLibrary()
        }

        print("[AppViewModel] attempting saved-session login")
        self.userViewModel.loginWithSaved()
    }

    public func refreshState() {
        userViewModel.refreshState()
    }

    public func login(code: String) {
        userViewModel.login(code: code)
    }

    public func loginWithSaved() {
        userViewModel.loginWithSaved()
    }

    public func logout() {
        userViewModel.logout()
    }
}

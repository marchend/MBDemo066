import XCTest
@testable import AcmeBank

final class LoginViewModelTests: XCTestCase {

    // MARK: - isSignInEnabled

    func test_isSignInEnabled_falseWhenBothEmpty() {
        let vm = LoginViewModel()
        XCTAssertFalse(vm.isSignInEnabled)
    }

    func test_isSignInEnabled_falseWhenUsernameEmpty() {
        let vm = LoginViewModel()
        vm.password = "secret"
        XCTAssertFalse(vm.isSignInEnabled)
    }

    func test_isSignInEnabled_falseWhenPasswordEmpty() {
        let vm = LoginViewModel()
        vm.username = "user@example.com"
        XCTAssertFalse(vm.isSignInEnabled)
    }

    func test_isSignInEnabled_trueWhenBothNonEmpty() {
        let vm = LoginViewModel()
        vm.username = "user@example.com"
        vm.password = "secret"
        XCTAssertTrue(vm.isSignInEnabled)
    }

    // MARK: - isPasswordVisible

    func test_isPasswordVisible_defaultsFalse() {
        let vm = LoginViewModel()
        XCTAssertFalse(vm.isPasswordVisible)
    }

    func test_isPasswordVisible_togglesCorrectly() {
        let vm = LoginViewModel()
        vm.isPasswordVisible = true
        XCTAssertTrue(vm.isPasswordVisible)
        vm.isPasswordVisible = false
        XCTAssertFalse(vm.isPasswordVisible)
    }

    // MARK: - keepSignedIn

    func test_keepSignedIn_defaultsFalse() {
        let vm = LoginViewModel()
        XCTAssertFalse(vm.keepSignedIn)
    }

    func test_keepSignedIn_togglesCorrectly() {
        let vm = LoginViewModel()
        vm.keepSignedIn = true
        XCTAssertTrue(vm.keepSignedIn)
        vm.keepSignedIn = false
        XCTAssertFalse(vm.keepSignedIn)
    }

    // MARK: - signIn() closure invocation

    func test_signIn_invokesClosureWithCorrectArguments() {
        var capturedUsername: String?
        var capturedPassword: String?
        var capturedKeepSignedIn: Bool?

        let vm = LoginViewModel { username, password, keep in
            capturedUsername = username
            capturedPassword = password
            capturedKeepSignedIn = keep
        }

        vm.username = "alice@example.com"
        vm.password = "hunter2"
        vm.keepSignedIn = true
        vm.signIn()

        XCTAssertEqual(capturedUsername, "alice@example.com")
        XCTAssertEqual(capturedPassword, "hunter2")
        XCTAssertEqual(capturedKeepSignedIn, true)
    }

    func test_signIn_isNoOpWhenFieldsEmpty() {
        var callCount = 0
        let vm = LoginViewModel { _, _, _ in callCount += 1 }

        vm.signIn()

        XCTAssertEqual(callCount, 0)
    }

    func test_signIn_isNoOpWhenOnlyUsernamePopulated() {
        var callCount = 0
        let vm = LoginViewModel { _, _, _ in callCount += 1 }
        vm.username = "alice@example.com"

        vm.signIn()

        XCTAssertEqual(callCount, 0)
    }

    func test_signIn_isNoOpWhenOnlyPasswordPopulated() {
        var callCount = 0
        let vm = LoginViewModel { _, _, _ in callCount += 1 }
        vm.password = "hunter2"

        vm.signIn()

        XCTAssertEqual(callCount, 0)
    }

    // MARK: - errorMessage

    func test_errorMessage_nilByDefault() {
        let vm = LoginViewModel()
        XCTAssertNil(vm.errorMessage)
    }

    func test_errorMessage_canBeSetExternally() {
        let vm = LoginViewModel()
        vm.errorMessage = "Incorrect username or password."
        XCTAssertEqual(vm.errorMessage, "Incorrect username or password.")
    }

    func test_errorMessage_clearsWhenUsernameChanges() {
        let vm = LoginViewModel()
        vm.errorMessage = "Some error"
        vm.username = "new_user"
        // errorMessage should be cleared by the didSet observer on username
        XCTAssertNil(vm.errorMessage)
    }

    func test_errorMessage_clearsWhenPasswordChanges() {
        let vm = LoginViewModel()
        vm.errorMessage = "Some error"
        vm.password = "new_pass"
        // errorMessage should be cleared by the didSet observer on password
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - keepSignedIn passed through signIn

    func test_signIn_passesKeepSignedInFalseByDefault() {
        var capturedKeepSignedIn: Bool?
        let vm = LoginViewModel { _, _, keep in capturedKeepSignedIn = keep }
        vm.username = "u"
        vm.password = "p"
        vm.signIn()
        XCTAssertEqual(capturedKeepSignedIn, false)
    }

    func test_signIn_passesKeepSignedInTrue_whenToggled() {
        var capturedKeepSignedIn: Bool?
        let vm = LoginViewModel { _, _, keep in capturedKeepSignedIn = keep }
        vm.username = "u"
        vm.password = "p"
        vm.keepSignedIn = true
        vm.signIn()
        XCTAssertEqual(capturedKeepSignedIn, true)
    }
}

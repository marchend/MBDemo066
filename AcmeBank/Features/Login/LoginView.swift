import SwiftUI

/// The login screen.
///
/// Has two integration shapes, mirroring the established
/// `isHelpSheetPresented` / `isOpenAccountSheetPresented` split pattern
/// already in this file — separate stored properties for separate
/// ownership contracts:
///
/// 1. **Standalone / preview path** (`init(onSignIn:)`):
///    `LoginView` OWNS the `LoginViewModel`'s lifetime, so it's stored
///    in a `@StateObject`. `@StateObject` is the right wrapper when
///    the view creates and owns the object.
///
/// 2. **Composition-root path** (`init(viewModel:)`):
///    The `AppCoordinator` OWNS the `LoginViewModel` (so coordinator
///    mutations to `errorMessage` / `isSigningIn` land on the SAME
///    instance driving the form). For an externally-owned
///    `ObservableObject` crossing a view boundary, the correct wrapper
///    is `@ObservedObject` — using `@StateObject(wrappedValue: …)`
///    here would silently DROP the injected instance on any
///    subsequent re-init of `LoginView`, because `@StateObject`
///    only consults `wrappedValue` on first creation in a given
///    view lifetime.
///
/// The `body` reads through a single computed `viewModel` property
/// that dispatches to whichever stored property is the active one
/// for this instance, keyed by the `useInjectedViewModel` flag set
/// at init time. Two-way bindings (`Binding(get:set:)`) are also
/// dispatched through the same selector so writes land on the
/// active viewModel.
struct LoginView: View {

    // MARK: - State

    /// Owned viewModel — used when `useInjectedViewModel == false`.
    /// Lifetime is bound to this view instance.
    @StateObject private var ownedViewModel: LoginViewModel

    /// Injected viewModel — used when `useInjectedViewModel == true`.
    /// Lifetime is owned upstream by the `AppCoordinator`.
    @ObservedObject private var injectedViewModel: LoginViewModel

    /// `true` when the view was built via `init(viewModel:)` and should
    /// render against `injectedViewModel`; `false` when built via
    /// `init(onSignIn:)` and should render against `ownedViewModel`.
    private let useInjectedViewModel: Bool

    @State private var isHelpSheetPresented: Bool = false
    @State private var isOpenAccountSheetPresented: Bool = false

    // MARK: - Active view model

    /// The viewModel the `body` actually reads. Dispatches to whichever
    /// stored property is the live one for this init shape.
    private var viewModel: LoginViewModel {
        useInjectedViewModel ? injectedViewModel : ownedViewModel
    }

    /// Two-way binding to a `WritableKeyPath` on the active viewModel.
    /// Used in place of `$viewModel.foo` because `viewModel` is a
    /// computed property, not a property wrapper, so it has no `$`
    /// projection. We construct the binding explicitly against the
    /// active instance so writes from the standalone path land on
    /// `ownedViewModel` and writes from the injected path land on
    /// `injectedViewModel`.
    private func bind<Value>(
        _ keyPath: ReferenceWritableKeyPath<LoginViewModel, Value>
    ) -> Binding<Value> {
        Binding(
            get: { self.viewModel[keyPath: keyPath] },
            set: { self.viewModel[keyPath: keyPath] = $0 }
        )
    }

    // MARK: - Init

    /// Standalone / preview init. `LoginView` owns the `LoginViewModel`'s
    /// lifetime, so it is held in a `@StateObject`.
    ///
    /// The `injectedViewModel` slot still needs an initial value (Swift
    /// doesn't allow uninitialised stored properties), so it's seeded
    /// with the same instance — but `useInjectedViewModel` is `false`
    /// so the `body` only ever reads from `ownedViewModel`.
    init(onSignIn: @escaping (String, String, Bool) -> Void = { _, _, _ in }) {
        let vm = LoginViewModel(onSignIn: onSignIn)
        _ownedViewModel    = StateObject(wrappedValue: vm)
        _injectedViewModel = ObservedObject(initialValue: vm)
        self.useInjectedViewModel = false
    }

    /// Composition-root init: lets the `AppCoordinator` own the
    /// `LoginViewModel` so it can mutate `errorMessage` / `isSigningIn`
    /// on the SAME instance the view renders. Without this, the
    /// coordinator's mutations would land on a different viewModel
    /// from the one driving the on-screen form.
    ///
    /// Held in `@ObservedObject` (not `@StateObject`) because the
    /// object's lifetime is owned upstream by the coordinator —
    /// `@StateObject(wrappedValue:)` would silently drop the injected
    /// instance on any subsequent re-init of this view, so mutations
    /// from the coordinator could stop reaching the on-screen form
    /// after the view is re-instantiated (e.g. a scene reconnect, or
    /// a sign-out / sign-in cycle once tab navigation is added).
    init(viewModel: LoginViewModel) {
        // `ownedViewModel` still needs a value but won't be read from
        // because `useInjectedViewModel` is `true`. We seed it with the
        // same instance for parity, but the body and bindings dispatch
        // through `injectedViewModel`.
        _ownedViewModel    = StateObject(wrappedValue: viewModel)
        _injectedViewModel = ObservedObject(initialValue: viewModel)
        self.useInjectedViewModel = true
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            OktaHeaderView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Logo + title ───────────────────────────────────────────────
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            AcmeLogoView()

                            Text("AcmeBank")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.acmeNavy)

                            Text("Sign in to your account")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 32)

                    // ── Username field ─────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.primary)

                        TextField("name@acmebank.com", text: bind(\.username))
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .disabled(viewModel.isSigningIn)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .accessibilityIdentifier("usernameField")
                    }

                    // ── Password field ─────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.primary)

                        PasswordFieldView(
                            text: bind(\.password),
                            isVisible: bind(\.isPasswordVisible)
                        )
                        .disabled(viewModel.isSigningIn)
                        .padding(.leading, 12)
                        .padding(.trailing, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .accessibilityIdentifier("passwordField")
                    }

                    // ── Inline error banner ────────────────────────────────────────
                    InlineErrorBannerView(message: viewModel.errorMessage)

                    // ── Keep me signed in + Need help ──────────────────────────────
                    HStack {
                        Button {
                            viewModel.keepSignedIn.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.keepSignedIn ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(viewModel.keepSignedIn ? Color.acmeNavy : Color.secondary)
                                Text("Keep me signed in")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        .disabled(viewModel.isSigningIn)
                        .accessibilityIdentifier("keepSignedInToggle")

                        Spacer()

                        Button {
                            isHelpSheetPresented = true
                        } label: {
                            Text("Need help?")
                                .font(.subheadline)
                                .foregroundStyle(Color.acmeNavy)
                                .underline()
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("needHelpButton")
                    }

                    // ── Sign in button ─────────────────────────────────────────────
                    Button {
                        viewModel.signIn()
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isSigningIn {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .accessibilityIdentifier("signInSpinner")
                            }
                            Text("Sign in")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                viewModel.isSignInEnabled
                                    ? Color.acmeNavy
                                    : Color.acmeNavy.opacity(0.4)
                            )
                    )
                    .disabled(!viewModel.isSignInEnabled)
                    .accessibilityIdentifier("signInButton")

                    // ── Open account ───────────────────────────────────────────────
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)

                            Button {
                                isOpenAccountSheetPresented = true
                            } label: {
                                Text("Open one")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.acmeNavy)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityIdentifier("openAccountButton")
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            OktaFooterView()
        }
        .ignoresSafeArea(edges: .top)
        // ── Help sheet ─────────────────────────────────────────────────────────────
        .sheet(isPresented: $isHelpSheetPresented) {
            HelpPlaceholderView()
        }
        // ── Open account sheet ─────────────────────────────────────────────────────
        .sheet(isPresented: $isOpenAccountSheetPresented) {
            OpenAccountPlaceholderView()
        }
    }
}

// MARK: - Help placeholder

/// Temporary placeholder sheet for "Need help?" until a real help flow ships.
private struct HelpPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.acmeNavy)

            Text("Help")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Support resources coming soon.")
                .font(.body)
                .foregroundStyle(Color.secondary)
        }
        .padding()
        .accessibilityIdentifier("helpPlaceholder")
    }
}

// MARK: - Preview

#Preview {
    LoginView()
}

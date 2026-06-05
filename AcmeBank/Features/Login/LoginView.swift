import SwiftUI

/// The login screen.
///
/// Owns a `LoginViewModel` as a `@StateObject` and composes all sub-views.
/// The `onSignIn` closure is the sole integration seam — it defaults to a
/// no-op stub so the view can be previewed and tested independently of Okta.
struct LoginView: View {

    // MARK: - State

    @StateObject private var viewModel: LoginViewModel

    @State private var isHelpSheetPresented: Bool = false
    @State private var isOpenAccountSheetPresented: Bool = false

    // MARK: - Init

    init(onSignIn: @escaping (String, String, Bool) -> Void = { _, _, _ in }) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(onSignIn: onSignIn))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            OktaHeaderView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Logo + title ────────────────────────────────────────────────
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

                    // ── Username field ──────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.primary)

                        TextField("name@acmebank.com", text: $viewModel.username)
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .accessibilityIdentifier("usernameField")
                    }

                    // ── Password field ──────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.primary)

                        PasswordFieldView(
                            text: $viewModel.password,
                            isVisible: $viewModel.isPasswordVisible
                        )
                        .padding(.leading, 12)
                        .padding(.trailing, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .accessibilityIdentifier("passwordField")
                    }

                    // ── Inline error banner ─────────────────────────────────────────
                    InlineErrorBannerView(message: viewModel.errorMessage)

                    // ── Keep me signed in + Need help ───────────────────────────────
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

                    // ── Sign in button ──────────────────────────────────────────────
                    Button {
                        viewModel.signIn()
                    } label: {
                        Text("Sign in")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
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

                    // ── Open account ────────────────────────────────────────────────
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
        // ── Help sheet ──────────────────────────────────────────────────────────────
        .sheet(isPresented: $isHelpSheetPresented) {
            HelpPlaceholderView()
        }
        // ── Open account sheet ──────────────────────────────────────────────────────
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

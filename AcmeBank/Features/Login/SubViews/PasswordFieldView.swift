import SwiftUI

/// A password entry field that toggles between `SecureField` and `TextField`
/// via an eye-icon button.
struct PasswordFieldView: View {
    @Binding var text: String
    @Binding var isVisible: Bool

    var placeholder: String = "Password"

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(Color.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(isVisible ? "Hide password" : "Show password")
            .accessibilityIdentifier("passwordToggleButton")
        }
    }
}

// MARK: - Preview

private struct PasswordFieldViewPreview: View {
    @State private var text = ""
    @State private var visible = false

    var body: some View {
        PasswordFieldView(text: $text, isVisible: $visible)
            .padding()
    }
}

#Preview {
    PasswordFieldViewPreview()
}

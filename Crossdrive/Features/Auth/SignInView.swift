import DesignSystem
import SwiftUI

/// Email and password. Used full screen (an app that requires sign-in) and
/// inside the login gate sheet.
struct SignInView: View {
    @State private var viewModel: SignInViewModel
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool
    @State private var emailShakes = 0
    @State private var passwordShakes = 0
    @State private var formShakes = 0

    @Environment(\.theme) private var theme

    init(viewModel: SignInViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.groupGap) {
                Text("Sign in")
                    .textRole(.largeTitle, emphasized: true)

                if let message = viewModel.formError {
                    DSBanner(message, kind: .error)
                        .errorShake(trigger: formShakes)
                }

                DSTextField(
                    "Email",
                    text: $viewModel.email,
                    isFocused: $emailFocused,
                    errorMessage: viewModel.emailError,
                    keyboardType: .emailAddress,
                    textContentType: .username,
                    autocapitalization: .never,
                    autocorrectionDisabled: true
                )
                .submitLabel(.next)
                .onSubmit { passwordFocused = true }
                .errorShake(trigger: emailShakes)

                DSSecureField(
                    "Password",
                    text: $viewModel.password,
                    isFocused: $passwordFocused,
                    errorMessage: viewModel.passwordError
                )
                .submitLabel(.go)
                .onSubmit(submit)
                .errorShake(trigger: passwordShakes)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .screenMargins()
            .padding(.vertical, theme.spacing.groupGap)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.background)
        .dsBottomBar {
            Button("Sign in", action: submit)
                .buttonStyle(.ds(.primary, isLoading: viewModel.isSubmitting))
        }
        .dsHaptic(.error, trigger: viewModel.failureCount)
        .privacyCover()
        .onChange(of: emailFocused) { wasFocused, isFocused in
            if wasFocused, !isFocused {
                viewModel.emailDidEndEditing()
            }
        }
        .onChange(of: passwordFocused) { wasFocused, isFocused in
            if wasFocused, !isFocused {
                viewModel.passwordDidEndEditing()
            }
        }
    }

    private func submit() {
        Task {
            switch await viewModel.submit() {
            case .email:
                emailFocused = true
                emailShakes += 1
            case .password:
                passwordFocused = true
                passwordShakes += 1
            case nil:
                // A problem that isn't about one field (offline, server): shake the message.
                if viewModel.formError != nil {
                    formShakes += 1
                }
            }
        }
    }
}

#Preview {
    SignInView(viewModel: SignInViewModel { _ in })
        .theme(.system)
}

#Preview("Wrong password") {
    SignInView(viewModel: SignInViewModel { _ in throw AuthError.invalidCredentials })
        .theme(.system)
}

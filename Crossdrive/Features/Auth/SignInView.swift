import DesignSystem
import SwiftUI

/// Email and password. Used full screen (an app that requires sign-in) and
/// inside the login gate sheet.
struct SignInView: View {
    @State private var viewModel: SignInViewModel
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

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

                DSSecureField(
                    "Password",
                    text: $viewModel.password,
                    isFocused: $passwordFocused,
                    errorMessage: viewModel.passwordError
                )
                .submitLabel(.go)
                .onSubmit(submit)
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
            case .email: emailFocused = true
            case .password: passwordFocused = true
            case nil: break
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

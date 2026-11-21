import DesignSystem
import SwiftUI

// MARK: - Email

struct EntryEmailStep: View {
    @Bindable var viewModel: EntryViewModel
    let onCancel: () -> Void

    @FocusState private var emailFocused: Bool
    @State private var emailShakes = 0

    @Environment(\.theme) private var theme

    var body: some View {
        EntryScaffold(focusedID: emailFocused ? "email" : nil, onCancel: onCancel) {
            EntryHeading(
                title: viewModel.trip == nil ? "Sign in" : "Sign in to join the trip",
                message: viewModel.canUseFacebook
                    ? Text("Enter your email, or use Apple or Facebook.")
                    : Text("Enter your email, or use Apple.")
            )
            if let trip = viewModel.trip {
                EntryTripChip(trip: trip, image: viewModel.tripImage).padding(.top, 16)
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
            .submitLabel(.continue)
            .onSubmit { submit(viewModel.continueTapped) }
            .errorShake(trigger: emailShakes)
            .id("email")
            .padding(.top, 18)
            Text("CrossDrive Missions keeps your details only to run its trips.")
                .textRole(.footnote)
                .foregroundStyle(theme.labelSecondary)
                .padding(.top, 12)
            EntrySocialButtons(viewModel: viewModel).padding(.top, 20)
        } bar: {
            VStack(spacing: 12) {
                if let message = viewModel.formError {
                    EntryStatusLine(
                        systemImage: "exclamationmark.circle",
                        text: message,
                        isError: true
                    )
                    .errorShake(trigger: viewModel.failureCount)
                }
                Button("Continue") { submit(viewModel.continueTapped) }
                    .buttonStyle(.ds(.primary))
                Button("Create an account") { submit(viewModel.createTapped) }
                    .buttonStyle(.ds(.tonal))
            }
        }
        .dsHaptic(.error, trigger: viewModel.failureCount)
        .onChange(of: emailFocused) { wasFocused, isFocused in
            if wasFocused, !isFocused {
                viewModel.emailDidEndEditing()
            }
        }
    }

    private func submit(_ choose: () -> EntryViewModel.Field?) {
        if choose() == .email {
            emailFocused = true
            emailShakes += 1
        }
    }
}

// MARK: - Password

struct EntryPasswordStep: View {
    @Bindable var viewModel: EntryViewModel
    let onCancel: () -> Void

    @FocusState private var passwordFocused: Bool
    @State private var passwordShakes = 0
    @State private var formShakes = 0

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline

    /// The email in bold, inside a sentence.
    private var emailText: Text {
        Text(viewModel.trimmedEmail).fontWeight(.semibold).foregroundStyle(theme.labelPrimary)
    }

    var body: some View {
        EntryScaffold(
            back: "Email",
            focusedID: passwordFocused ? "password" : nil,
            onCancel: onCancel
        ) {
            EntryHeading(
                title: "Enter your password",
                message: Text("Enter the password for \(emailText) to keep going.")
            )
            if let message = viewModel.formError {
                EntryStatusLine(systemImage: "exclamationmark.circle", text: message, isError: true)
                    .errorShake(trigger: formShakes)
                    .padding(.top, 14)
            }
            if let trip = viewModel.trip {
                EntryTripChip(trip: trip, image: viewModel.tripImage).padding(.top, 18)
            }
            CDPasswordField(
                label: String(localized: "Password"),
                text: $viewModel.password,
                isFocused: $passwordFocused,
                errorMessage: viewModel.passwordError
            )
            .submitLabel(.go)
            .onSubmit(submit)
            .errorShake(trigger: passwordShakes)
            .id("password")
            .padding(.top, 18)
            Button("Forgot your password?") { viewModel.showReset() }
                .textRole(.subheadline, emphasized: true)
                .foregroundStyle(theme.accent)
                .frame(minHeight: DesignSystem.minTapTarget)
        } bar: {
            VStack(spacing: 12) {
                if !isOnline {
                    EntryStatusLine(
                        systemImage: "wifi.slash",
                        text: String(
                            localized: "You're offline. Connect to the internet to sign in."
                        )
                    )
                }
                if viewModel.isLocked {
                    Button("Reset my password") { viewModel.showReset() }
                        .buttonStyle(.ds(.primary))
                } else {
                    Button(
                        viewModel.isSubmitting ? "Signing in…" : "Sign in and continue",
                        action: submit
                    )
                    .buttonStyle(.ds(.primary, isLoading: viewModel.isSubmitting))
                    .disabled(!isOnline)
                }
            }
        }
        .dsHaptic(.error, trigger: viewModel.failureCount)
        .onChange(of: viewModel.password) { _, _ in viewModel.passwordDidChange() }
    }

    private func submit() {
        Task {
            switch await viewModel.signInTapped() {
            case .password:
                passwordFocused = true
                passwordShakes += 1
            case .email, .name: break
            case nil:
                if viewModel.formError != nil {
                    formShakes += 1
                }
            }
        }
    }
}

// MARK: - Create account

struct EntryCreateStep: View {
    @Bindable var viewModel: EntryViewModel
    let onCancel: () -> Void

    @FocusState private var nameFocused: Bool
    @FocusState private var passwordFocused: Bool
    @State private var nameShakes = 0
    @State private var passwordShakes = 0
    @State private var formShakes = 0

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline

    /// The email in bold, inside a sentence.
    private var emailText: Text {
        Text(viewModel.trimmedEmail).fontWeight(.semibold).foregroundStyle(theme.labelPrimary)
    }

    var body: some View {
        EntryScaffold(
            back: "Email",
            focusedID: nameFocused ? "name" : (passwordFocused ? "newPassword" : nil),
            onCancel: onCancel
        ) {
            EntryHeading(
                title: "Create your account",
                message: Text(
                    """
                    We'll make an account for \(emailText). \
                    Two more things, then you're back to joining the trip.
                    """
                )
            )
            if let message = viewModel.formError {
                EntryStatusLine(systemImage: "exclamationmark.circle", text: message, isError: true)
                    .errorShake(trigger: formShakes)
                    .padding(.top, 14)
            }
            VStack(alignment: .leading, spacing: 14) {
                DSTextField(
                    "Your name",
                    text: $viewModel.name,
                    isFocused: $nameFocused,
                    errorMessage: viewModel.nameError,
                    textContentType: .name,
                    autocapitalization: .words
                )
                .submitLabel(.next)
                .onSubmit { passwordFocused = true }
                .errorShake(trigger: nameShakes)
                .id("name")
                CDPasswordField(
                    label: String(localized: "Create a password"),
                    text: $viewModel.password,
                    isFocused: $passwordFocused,
                    helperMessage: String(localized: "At least 8 characters."),
                    errorMessage: viewModel.passwordError,
                    contentType: .newPassword
                )
                .submitLabel(.go)
                .onSubmit(submit)
                .errorShake(trigger: passwordShakes)
                .id("newPassword")
                agreement
            }
            .padding(.top, 18)
        } bar: {
            VStack(spacing: 12) {
                if !isOnline {
                    EntryStatusLine(
                        systemImage: "wifi.slash",
                        text: String(
                            localized: "You're offline. Connect to the internet to sign in."
                        )
                    )
                }
                Button(
                    viewModel
                        .isSubmitting ? "Creating your account…" : "Create account and continue",
                    action: submit
                )
                .buttonStyle(.ds(.primary, isLoading: viewModel.isSubmitting))
                .disabled(!isOnline)
            }
        }
        .dsHaptic(.error, trigger: viewModel.failureCount)
        .onChange(of: viewModel.password) { _, _ in viewModel.passwordDidChange() }
    }

    private var agreement: some View {
        Button {
            viewModel.hasAgreed.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(viewModel.hasAgreed ? theme.accent : theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                viewModel.hasAgreed ? theme.accent : theme.labelTertiary,
                                lineWidth: 1.5
                            )
                    )
                    .overlay {
                        if viewModel.hasAgreed {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.onAccent)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("I agree that CrossDrive Missions keeps my details to run its trips.")
                        .textRole(.subheadline)
                        .foregroundStyle(theme.labelPrimary)
                        .multilineTextAlignment(.leading)
                    if let error = viewModel.agreementError {
                        Text(error).textRole(.footnote).foregroundStyle(theme.destructive)
                    }
                }
            }
            .frame(minHeight: DesignSystem.minTapTarget, alignment: .top)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(Text(viewModel.hasAgreed ? "Agreed" : "Not agreed"))
    }

    private func submit() {
        Task {
            switch await viewModel.createAccountTapped() {
            case .name:
                nameFocused = true
                nameShakes += 1
            case .password:
                passwordFocused = true
                passwordShakes += 1
            case .email: break
            case nil:
                if viewModel.formError != nil || viewModel.agreementError != nil {
                    formShakes += 1
                }
            }
        }
    }
}

// MARK: - Check your email

struct EntryCheckEmailStep: View {
    @Bindable var viewModel: EntryViewModel
    let onCancel: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    /// The email in bold, inside a sentence.
    private var emailText: Text {
        Text(viewModel.trimmedEmail).fontWeight(.semibold).foregroundStyle(theme.labelPrimary)
    }

    var body: some View {
        EntryScaffold(onCancel: onCancel) {
            EntryHeading(
                title: "Check your email",
                message: Text(
                    """
                    We sent a link to \(emailText). \
                    Open it on this phone to finish, then you're back to joining the trip.
                    """
                )
            )
            .padding(.top, 52)
            if let message = viewModel.formError {
                EntryStatusLine(systemImage: "exclamationmark.circle", text: message, isError: true)
                    .padding(.top, 14)
            }
        } bar: {
            VStack(spacing: 12) {
                Button("Open Mail") {
                    if let url = URL(string: "message://") {
                        openURL(url)
                    }
                }
                .buttonStyle(.ds(.primary))
                Button("Send the link again") {
                    Task { await viewModel.resendVerificationTapped() }
                }
                .buttonStyle(.ds(.secondary, isLoading: viewModel.isSubmitting))
            }
        }
        // Back from Mail with the email confirmed: carry on without another tap.
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task { await viewModel.resumeAfterVerification() }
            }
        }
    }
}

// MARK: - Reset password

struct EntryResetStep: View {
    @Bindable var viewModel: EntryViewModel
    let onCancel: () -> Void

    @FocusState private var emailFocused: Bool
    @State private var emailShakes = 0

    @Environment(\.theme) private var theme
    @Environment(\.isOnline) private var isOnline

    var body: some View {
        EntryScaffold(
            back: "Sign in",
            focusedID: emailFocused ? "email" : nil,
            onCancel: onCancel
        ) {
            EntryHeading(
                title: "Reset your password",
                message: Text(
                    "Enter the email you signed up with. We'll send you a link to set a new password."
                )
            )
            .padding(.top, 8)
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
            .submitLabel(.send)
            .onSubmit(submit)
            .errorShake(trigger: emailShakes)
            .id("email")
            .padding(.top, 20)
            if let notice = viewModel.resetNotice {
                EntryStatusLine(systemImage: "checkmark.circle", text: notice)
                    .padding(.top, 14)
            } else if let message = viewModel.formError {
                EntryStatusLine(systemImage: "exclamationmark.circle", text: message, isError: true)
                    .padding(.top, 14)
            }
            Button(viewModel.isSubmitting ? "Sending…" : "Send the reset link", action: submit)
                .buttonStyle(.ds(.primary, isLoading: viewModel.isSubmitting))
                .disabled(!isOnline)
                .padding(.top, 22)
            Text("No email after a few minutes? Check your spam folder.")
                .textRole(.footnote)
                .foregroundStyle(theme.labelSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        } bar: {
            EmptyView()
        }
        .dsHaptic(.error, trigger: viewModel.failureCount)
    }

    private func submit() {
        Task {
            if await viewModel.sendResetLinkTapped() == .email {
                emailFocused = true
                emailShakes += 1
            }
        }
    }
}

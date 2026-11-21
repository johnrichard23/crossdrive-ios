import AuthenticationServices
import DesignSystem
import SwiftUI

/// "or", then two round logo buttons: Apple, and Facebook once it is set up.
///
/// Each is a small raised disc: white on a light page, lifted by a soft
/// two-layer shadow and a hairline edge instead of a hard outline; black on a dark
/// page, where shadows don't read, lifted by a faint top light instead. Apple's
/// rules allow a logo-only button in black or white using Apple's own artwork,
/// uncropped; Facebook's logo is its round blue mark.
struct EntrySocialButtons: View {
    @Bindable var viewModel: EntryViewModel

    @State private var isAppleOpen = false

    @Environment(\.authorizationController) private var authorizationController
    @Environment(\.theme) private var theme

    private let size: CGFloat = 56
    /// Apple's logo file is the button plus a 6-in-56 margin; only the button shows.
    private let appleFileScale: CGFloat = 56.0 / 44.0
    /// A filled circle reads heavier than the Apple outline, so it sits a touch smaller.
    private let facebookLogoSize: CGFloat = 23

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                theme.separator.frame(height: 1)
                Text("or").textRole(.footnote).foregroundStyle(theme.labelSecondary)
                theme.separator.frame(height: 1)
            }
            .accessibilityHidden(true)

            HStack(spacing: 24) {
                Button {
                    // One Apple sheet at a time: a second tap while it is up does nothing.
                    guard !isAppleOpen else { return }
                    isAppleOpen = true
                    Task {
                        let result = await AppleSignIn.signIn(using: authorizationController)
                        isAppleOpen = false
                        await viewModel.appleFinished(result)
                    }
                } label: {
                    Image("AppleSignInLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * appleFileScale, height: size * appleFileScale)
                        .accessibilityLabel(Text("Continue with Apple"))
                }

                if viewModel.canUseFacebook {
                    Button {
                        Task { await viewModel.facebookTapped() }
                    } label: {
                        Image("FacebookLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: facebookLogoSize, height: facebookLogoSize)
                            .accessibilityLabel(Text("Continue with Facebook"))
                    }
                }
            }
            .buttonStyle(RaisedDiscStyle(size: size))
            .disabled(viewModel.isSubmitting)
        }
    }
}

/// A raised round button for a logo.
private struct RaisedDiscStyle: ButtonStyle {
    let size: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let isDark = colorScheme == .dark
        let pressed = configuration.isPressed
        configuration.label
            .frame(width: size, height: size)
            .background(isDark ? Color.black : Color.white)
            .clipShape(Circle())
            .overlay {
                if isDark {
                    // A faint light along the top edge, the way a raised surface catches it.
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                } else {
                    Circle().strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                }
            }
            // Two shadows: a tight one where the disc meets the page, a soft one for lift.
            .shadow(color: .black.opacity(isDark ? 0 : 0.10), radius: 1, y: 1)
            .shadow(
                color: .black.opacity(isDark ? 0 : (pressed ? 0.06 : 0.10)),
                radius: pressed ? 4 : 10,
                y: pressed ? 2 : 5
            )
            .scaleEffect(pressed && !reduceMotion ? 0.96 : 1)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(DesignSystem.Motion.press, value: pressed)
            .contentShape(Circle())
    }
}

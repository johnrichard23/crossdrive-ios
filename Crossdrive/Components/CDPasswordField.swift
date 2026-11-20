import DesignSystem
import SwiftUI

/// A password field with a "Show" / "Hide" text button, in the design system's
/// field frame. (The package's own field uses an eye icon.)
struct CDPasswordField: View {
    let label: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var helperMessage: String?
    var errorMessage: String?
    var contentType: UITextContentType = .password

    @State private var isVisible = false
    @Environment(\.theme) private var theme

    var body: some View {
        DSFieldLayout(
            label: label,
            helperMessage: helperMessage,
            errorMessage: errorMessage,
            isFocused: isFocused.wrappedValue,
            isReadOnly: false
        ) {
            Group {
                if isVisible {
                    TextField(text: $text, prompt: Text(verbatim: "")) { Text(label) }
                } else {
                    SecureField(text: $text, prompt: Text(verbatim: "")) { Text(label) }
                }
            }
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused(isFocused)
            .accessibilityLabel(Text(label))
        } trailing: {
            if !text.isEmpty {
                Button(isVisible ? "Hide" : "Show") { isVisible.toggle() }
                    .textRole(.subheadline, emphasized: true)
                    .foregroundStyle(theme.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(Text(isVisible ? "Hide password" : "Show password"))
            }
        }
    }
}

import DesignSystem
import SwiftUI

// MARK: - Role (trips only)

struct RegistrationRoleStep: View {
    @Bindable var viewModel: RegistrationViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RegistrationHeading(
                "How will you help?",
                subtitle: "Pick a team, or let the coordinators place you on the day."
            )
            card(RegistrationChoice(
                role: .anywhere,
                icon: .globe,
                name: String(localized: "Wherever I'm needed"),
                summary: String(localized: "The coordinators place you on the day")
            ))
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(viewModel.detail.roles) { role in
                    card(RegistrationChoice(
                        role: .team(role.id),
                        icon: EventIcon.source(for: role.iconKey),
                        name: role.name,
                        summary: role.summary,
                        slots: role.slotsLabel,
                        isFull: role.isFull
                    ))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Teams"))
            if let error = viewModel.errors[.role] {
                RegistrationError(error)
            }
        }
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: count)
    }

    private func card(_ choice: RegistrationChoice) -> some View {
        RegistrationChoiceCard(choice: choice, isSelected: viewModel.form.role == choice.role) {
            viewModel.choose(choice.role)
        }
    }
}

/// One answer to "How will you help?".
struct RegistrationChoice {
    var role: RegistrationForm.Role
    var icon: DSIcon.Source
    var name: String
    var summary: String
    var slots: String?
    var isFull = false
}

/// "Wherever I'm needed" is a row; a team is a card in the grid. A full team
/// shows "Full" and can't be picked.
struct RegistrationChoiceCard: View {
    let choice: RegistrationChoice
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.theme) private var theme

    private var isRow: Bool {
        choice.role == .anywhere
    }

    var body: some View {
        Button(action: onSelect) {
            content
                .foregroundStyle(theme.labelPrimary)
                .frame(maxWidth: .infinity, minHeight: isRow ? 0 : 120, alignment: .topLeading)
                .padding(12)
                .background(
                    isSelected ? CDColor.brandSoft : theme.surface,
                    in: DesignSystem.Radius.shape(16)
                )
                .overlay {
                    DesignSystem.Radius.shape(16)
                        .strokeBorder(
                            isSelected ? theme.accent : theme.border,
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .overlay(alignment: .topTrailing) { checkBadge }
                .opacity(choice.isFull ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .disabled(choice.isFull)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(choice.isFull ? Text("This team is full") : Text(""))
    }

    private var content: some View {
        let layout = isRow
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
        return layout {
            DSIcon(choice.icon, role: .body)
                .foregroundStyle(CDColor.onBrandSoft)
                .frame(width: 36, height: 36)
                .background(
                    isSelected ? theme.surface : CDColor.brandSoft,
                    in: DesignSystem.Radius.shape(10)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(choice.name).textRole(.headline, emphasized: true)
                Text(choice.summary)
                    .textRole(.footnote)
                    .foregroundStyle(theme.labelSecondary)
                if let slots = choice.slots {
                    Text(slots)
                        .textRole(.footnote, emphasized: true)
                        .foregroundStyle(choice.isFull ? theme.labelSecondary : theme.accent)
                }
            }
            .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder private var checkBadge: some View {
        if isSelected {
            DSIcon(.check, role: .caption1)
                .foregroundStyle(theme.onAccent)
                .frame(width: 22, height: 22)
                .background(theme.accent, in: Circle())
                .padding(10)
        }
    }
}

// MARK: - Details

struct RegistrationDetailsStep: View {
    @Bindable var viewModel: RegistrationViewModel

    @FocusState private var mobileFocused: Bool
    @FocusState private var messengerFocused: Bool
    @FocusState private var emergencyNameFocused: Bool
    @FocusState private var emergencyMobileFocused: Bool
    @FocusState private var notesFocused: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RegistrationHeading("How the coordinators reach you")
            DSTextField(
                String(localized: "Your mobile number"),
                placeholder: "0917 123 4567",
                text: $viewModel.form.mobile,
                isFocused: $mobileFocused,
                helperMessage: String(
                    localized: "The coordinators text trip updates to this number."
                ),
                errorMessage: viewModel.errors[.mobile],
                keyboardType: .phonePad,
                textContentType: .telephoneNumber
            )
            DSTextField(
                String(localized: "Your name on Messenger (optional)"),
                text: $viewModel.form.messengerName,
                isFocused: $messengerFocused,
                helperMessage: String(
                    localized: "So a coordinator can add you to the trip group chat."
                ),
                autocapitalization: .words,
                autocorrectionDisabled: true
            )
            if viewModel.detail.event.kind == .trip {
                Toggle("I'm under 18", isOn: $viewModel.form.isMinor)
                    .textRole(.body)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("If something happens").textRole(.headline, emphasized: true)
                DSTextField(
                    String(localized: "Who should we call?"),
                    text: $viewModel.form.emergencyName,
                    isFocused: $emergencyNameFocused,
                    errorMessage: viewModel.errors[.emergencyName],
                    textContentType: .name,
                    autocapitalization: .words
                )
                DSTextField(
                    String(localized: "Their mobile number"),
                    placeholder: "0917 123 4567",
                    text: $viewModel.form.emergencyMobile,
                    isFocused: $emergencyMobileFocused,
                    errorMessage: viewModel.errors[.emergencyMobile],
                    keyboardType: .phonePad
                )
            }
            .padding(14)
            .background(theme.surface, in: DesignSystem.Radius.shape(16))
            .overlay { DesignSystem.Radius.shape(16).strokeBorder(theme.border, lineWidth: 1) }
            // Medical notes: no autocorrect, so the keyboard never learns them.
            DSTextField(
                String(localized: "Anything the coordinators should know? (optional)"),
                placeholder: String(localized: "Allergies, medicine, a fear of boats"),
                text: $viewModel.form.notes,
                isFocused: $notesFocused,
                helperMessage: String(localized: "Only the trip coordinators see this."),
                autocorrectionDisabled: true
            )
        }
    }
}

// MARK: - Waiver, and the last slot taken

struct RegistrationWaiverStep: View {
    @Bindable var viewModel: RegistrationViewModel

    @FocusState private var signatureFocused: Bool
    @FocusState private var guardianNameFocused: Bool
    @FocusState private var guardianMobileFocused: Bool

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    private var event: Event {
        viewModel.detail.event
    }

    var body: some View {
        if viewModel.sendState == .lastSlotTaken {
            lastSlotTaken
        } else {
            VStack(alignment: .leading, spacing: 16) {
                RegistrationHeading(
                    event.kind == .camp
                        ? LocalizedStringKey("Sign the waiver, add a permit")
                        : LocalizedStringKey("Read and sign the waiver")
                )
                waiverText
                if let pdf = viewModel.detail.waiver?.pdfURL {
                    Button("Download the waiver (PDF)") { openURL(pdf) }
                        .registrationLink()
                }
                signature
                if event.kind == .camp || viewModel.form.needsGuardian(for: event.kind) {
                    guardian
                }
                if case let .failed(message) = viewModel.sendState {
                    RegistrationError(message)
                }
            }
        }
    }

    private var waiverText: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(event.title) · \(event.dateRangeLabel)").textRole(
                    .callout,
                    emphasized: true
                )
                Text(viewModel.detail.waiver?.text
                    ?? String(localized: "The coordinators will share the waiver before the trip."))
                    .textRole(.callout)
                    .foregroundStyle(theme.labelSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(height: 220)
        .background(theme.surface, in: DesignSystem.Radius.shape(16))
        .overlay { DesignSystem.Radius.shape(16).strokeBorder(theme.border, lineWidth: 1) }
        .accessibilityLabel(Text("Waiver text"))
    }

    private var signature: some View {
        let error = viewModel.errors[.signature]
        return VStack(alignment: .leading, spacing: 6) {
            Text("Sign with your full name").textRole(.subheadline, emphasized: true)
            TextField("", text: $viewModel.form.signature)
                .textRole(.title2)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($signatureFocused)
                .frame(minHeight: 56)
                .accessibilityLabel(Text("Sign with your full name"))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(error == nil ? theme.labelPrimary : theme.destructive)
                        .frame(height: 2)
                }
            if let error {
                RegistrationError(error)
            } else {
                Text(signedHelp)
                    .textRole(.footnote)
                    .foregroundStyle(theme.labelSecondary)
            }
        }
    }

    private var signedHelp: String {
        let today = Date.now.formatted(.dateTime.month(.abbreviated).day().year())
        let signed = String(localized: "Signed today, \(today).")
        guard event.kind == .trip else { return signed }
        return signed + " " +
            String(localized: "Under 18? We'll text your parent or guardian to sign too.")
    }

    private var guardian: some View {
        let isCamp = event.kind == .camp
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isCamp
                    ? LocalizedStringKey("A parent or guardian will sign a permit")
                    : LocalizedStringKey("Your parent or guardian signs too"))
                    .textRole(.headline, emphasized: true)
                Text(isCamp
                    ? LocalizedStringKey(
                        "Camps are for adults. We'll text them a link to sign. You can finish registering now."
                    )
                    :
                    LocalizedStringKey(
                        "We'll text them a link to sign. You can finish registering now."
                    ))
                    .textRole(.footnote)
                    .foregroundStyle(theme.labelSecondary)
            }
            DSTextField(
                isCamp
                    ? String(localized: "Parent or guardian's name (optional)")
                    : String(localized: "Parent or guardian's name"),
                text: $viewModel.form.guardianName,
                isFocused: $guardianNameFocused,
                errorMessage: viewModel.errors[.guardianName],
                autocapitalization: .words
            )
            DSTextField(
                String(localized: "Their mobile number"),
                placeholder: "0917 123 4567",
                text: $viewModel.form.guardianMobile,
                isFocused: $guardianMobileFocused,
                errorMessage: viewModel.errors[.guardianMobile],
                keyboardType: .phonePad
            )
        }
        .padding(14)
        .background(theme.surface, in: DesignSystem.Radius.shape(16))
        .overlay { DesignSystem.Radius.shape(16).strokeBorder(theme.border, lineWidth: 1) }
    }

    private var lastSlotTaken: some View {
        VStack(alignment: .leading, spacing: 16) {
            RegistrationHeading(
                "Sorry, the last slot was just taken",
                subtitle: """
                Someone joined a moment before you. \
                Join the waiting list and we'll text you if a slot opens.
                """
            )
            Button("Join the waiting list") {
                Task { await viewModel.joinWaitingList() }
            }
            .buttonStyle(.ds(.primary, isLoading: viewModel.sendState == .sending))
        }
    }
}

// MARK: - Shared pieces

struct RegistrationHeading: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?

    @Environment(\.theme) private var theme

    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .textRole(.title2, emphasized: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .textRole(.callout)
                    .foregroundStyle(theme.labelSecondary)
            }
        }
    }
}

extension View {
    /// A text link in the accent colour, like "Forgot your password?" on sign-in.
    func registrationLink() -> some View {
        modifier(RegistrationLink())
    }
}

private struct RegistrationLink: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .textRole(.subheadline, emphasized: true)
            .foregroundStyle(theme.accent)
            .frame(minHeight: DesignSystem.minTapTarget)
    }
}

struct RegistrationError: View {
    private let message: String

    @Environment(\.theme) private var theme

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .textRole(.footnote, emphasized: true)
            .foregroundStyle(theme.destructive)
    }
}

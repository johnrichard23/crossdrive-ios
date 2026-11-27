import DesignSystem
import SwiftUI

/// "You're registered": the trip and its status, the
/// guardian's permit, the trip chat, and how to pay.
struct RegistrationDoneStep: View {
    let viewModel: RegistrationViewModel
    let onSeeHowToPay: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    private var event: Event {
        viewModel.detail.event
    }

    private var isWaitlisted: Bool {
        viewModel.result?.status == .waitlisted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isWaitlisted ? "You're on the waiting list" : "You're registered")
                    .textRole(.title1, emphasized: true)
                    .accessibilityAddTraits(.isHeader)
                if let line = subtitle {
                    Text(line)
                        .textRole(.callout)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
            tripCard
            if viewModel.result?.isPermitWaiting == true {
                permit
            }
            if !isWaitlisted {
                chat
                if let fee = event.fee {
                    pay(fee)
                }
            }
        }
    }

    private var subtitle: String? {
        if isWaitlisted {
            return String(localized: "We'll text you if a slot opens.")
        }
        switch viewModel.form.role {
        case .anywhere: return String(localized: "Your team: wherever you're needed")
        case .team: return viewModel.selectedTeam.map { String(localized: "Your team: \($0.name)") }
        case nil: return event.kind == .camp ? String(localized: "See you at the camp.") : nil
        }
    }

    private var tripCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            DSRemoteImage(url: event.heroImageURL)
                .frame(height: 92)
                .frame(maxWidth: .infinity)
                .clipped()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title).textRole(.headline, emphasized: true)
                Text([event.dateRangeLabel, event.place].compactMap(\.self)
                    .joined(separator: " · "))
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
                CDChip(
                    text: isWaitlisted
                        ? String(localized: "On the waiting list")
                        : String(localized: "Waiting for a coordinator to confirm"),
                    tone: .pending
                )
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
        }
        .background(theme.surface, in: DesignSystem.Radius.shape(20))
        .clipShape(DesignSystem.Radius.shape(20))
        .overlay { DesignSystem.Radius.shape(20).strokeBorder(theme.border, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    private var permit: some View {
        card {
            Text("Permit waiting").textRole(.headline, emphasized: true)
            Text(String(localized: "\(viewModel.form.guardianName) hasn't signed yet."))
                .textRole(.subheadline)
                .foregroundStyle(theme.labelSecondary)
        }
    }

    private var chat: some View {
        let hasName = !viewModel.form.messengerName.trimmingCharacters(in: .whitespaces).isEmpty
        return card {
            Text("Your trip chat").textRole(.headline, emphasized: true)
            Text(hasName
                ?
                String(
                    localized: "A coordinator is adding \(viewModel.form.messengerName) to the group chat on Messenger."
                )
                :
                String(
                    localized: "Message us on Messenger and a coordinator will add you to the group chat."
                ))
                .textRole(.subheadline)
                .foregroundStyle(theme.labelSecondary)
            if let url = TripLinks.messenger {
                Button(hasName ? "Open Messenger" : "Message us on Messenger") { openURL(url) }
                    .buttonStyle(.ds(.secondary, size: .regular))
                    .padding(.top, 4)
            }
        }
    }

    private func pay(_ fee: Money) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Pay \(fee.formatted) before \(event.feeDueDateLabel)"))
                .textRole(.headline, emphasized: true)
            Text(
                "Send it from your own GCash, Maya or bank app. A coordinator marks it paid once it arrives."
            )
            .textRole(.subheadline)
            .foregroundStyle(theme.labelSecondary)
            Button("See how to pay", action: onSeeHowToPay)
                .registrationLink()
        }
        .padding(.top, 4)
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(theme.surface, in: DesignSystem.Radius.shape(16))
            .overlay { DesignSystem.Radius.shape(16).strokeBorder(theme.border, lineWidth: 1) }
    }
}

import DataLayer
import DesignSystem
import SwiftUI

/// "Before you go": what is still open for this trip. The fee row hands over
/// to the Pay screen on My trip; the permit and waiver rows only say where
/// things stand.
struct MyTripToDoSheet: View {
    let trip: MyTrip
    /// The fee row was tapped. My trip closes the sheet and opens Pay.
    let onPay: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    Text("Before you go")
                        .textRole(.title2, emphasized: true)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    Button("Done") { dismiss() }
                        .textRole(.body, emphasized: true)
                        .frame(minHeight: 44)
                }
                VStack(spacing: 0) {
                    ForEach(Array(trip.toDos.enumerated()), id: \.offset) { index, toDo in
                        row(for: toDo)
                            .overlay(alignment: .top) {
                                if index > 0 {
                                    Rectangle().fill(theme.separator).frame(height: 1)
                                }
                            }
                    }
                }
                .background(theme.surface, in: DesignSystem.Radius.shape(16))
                .overlay(DesignSystem.Radius.shape(16).stroke(theme.separator, lineWidth: 1))

                if trip.waiverSigned {
                    Label { Text("Waiver signed") } icon: { DSIcon(.check, role: .subheadline) }
                        .textRole(.subheadline)
                        .foregroundStyle(theme.success)
                }
            }
            .screenMargins()
            .padding(.top, 12)
        }
        .background(theme.background)
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private func row(for toDo: MyTrip.ToDo) -> some View {
        switch toDo {
        case .fee:
            Button(action: onPay) {
                content(toDo, icon: .peso, showsChevron: true)
            }
            .buttonStyle(.plain)
        case .permit:
            content(toDo, icon: .people, showsChevron: false)
        case .waiver:
            content(toDo, icon: .bible, showsChevron: false)
        }
    }

    private func content(
        _ toDo: MyTrip.ToDo,
        icon: DSIcon.Source,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 12) {
            DSIcon(icon, role: .title3)
                .foregroundStyle(CDColor.onHarvestSoft)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(toDo.title).textRole(.body, emphasized: true)
                Text(toDo.detail)
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
            }
            Spacer(minLength: 0)
            if showsChevron {
                DSIcon(.chevronRight, role: .subheadline)
                    .foregroundStyle(theme.labelTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Loads the trip's pay details, then shows the Pay screen.
struct MyTripPayLoader: View {
    let trip: MyTrip
    let eventsAPI: EventsAPI
    let imageLoader: any ImageLoading
    let onDone: () -> Void

    @State private var payViewModel: PayTripViewModel?
    @State private var failed = false

    var body: some View {
        Group {
            if let payViewModel {
                PayTripView(viewModel: payViewModel, onDone: onDone)
            } else if failed {
                DSStateView.error(message: "Check your connection, then try again.") {
                    Task { await load() }
                }
            } else {
                ProgressView()
            }
        }
        .task { await load() }
    }

    private func load() async {
        failed = false
        do {
            let detail = try await eventsAPI.event(id: trip.id)
            payViewModel = PayTripViewModel(
                detail: detail,
                registration: registration,
                api: eventsAPI,
                imageLoader: imageLoader
            )
        } catch {
            failed = true
        }
    }

    /// What the Pay screen needs to know about this registration.
    private var registration: RegistrationResult {
        RegistrationResult(
            id: trip.registrationID,
            status: trip.status == .waitlisted ? .waitlisted : .pending,
            reference: nil,
            isPermitWaiting: trip.permit.map { !$0.signed } ?? false
        )
    }
}

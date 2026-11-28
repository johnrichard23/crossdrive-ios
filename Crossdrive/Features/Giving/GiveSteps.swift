import DesignSystem
import SwiftUI

// MARK: - Amount

/// Monthly or yearly (or one time), a few amounts to tap, Change for another,
/// and for the school fund how far the gift goes.
struct GiveAmountStep: View {
    @Bindable var viewModel: GiveViewModel

    @State private var isChanging = false
    @State private var customText = ""

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your gift")
                .textRole(.title1, emphasized: true)
                .accessibilityAddTraits(.isHeader)
            Picker("How often", selection: frequency) {
                ForEach(viewModel.frequencies, id: \.self) { Text(title(of: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
            amountRow
            presets
            if viewModel.ministry.kind == .school, let fund = viewModel.ministry.fund {
                schoolCard(fund)
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.pesos)
        .alert("Your gift", isPresented: $isChanging) {
            TextField("Amount in pesos", text: $customText)
                .keyboardType(.numberPad)
            Button("Done") {
                if !viewModel.setCustomAmount(customText) {
                    viewModel
                        .toast =
                        .info(String(localized: "Give \(minimum) or more, in whole pesos."))
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("From \(minimum).")
        }
    }

    private var minimum: String {
        Gift(frequency: .once, pesos: GiveViewModel.minimumPesos).amount.formatted
    }

    private var frequency: Binding<Gift.Frequency> {
        Binding(get: { viewModel.frequency }, set: { viewModel.setFrequency($0) })
    }

    private func title(of frequency: Gift.Frequency) -> String {
        switch frequency {
        case .monthly: String(localized: "Monthly")
        case .yearly: String(localized: "Yearly")
        case .once: String(localized: "One time")
        }
    }

    /// At accessibility sizes the parts stack, so no word breaks in the middle.
    private var amountRow: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(viewModel.gift.amount.formatted)
                .textRole(.largeTitle, emphasized: true)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            if let label = viewModel.frequencyLabel {
                Text(label)
                    .textRole(.headline)
                    .foregroundStyle(theme.labelSecondary)
            }
            if !isLarge {
                Spacer(minLength: 8)
            }
            Button("Change") {
                customText = ""
                isChanging = true
            }
            .registrationLink()
        }
        .accessibilityElement(children: .contain)
    }

    private var presets: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 8),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 4
        )
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(viewModel.presets, id: \.self) { pesos in
                let isOn = viewModel.pesos == pesos
                Button {
                    viewModel.choose(pesos)
                } label: {
                    Text(Gift(frequency: .once, pesos: pesos).amount.formatted)
                        .textRole(.callout, emphasized: true)
                        .monospacedDigit()
                        .foregroundStyle(isOn ? theme.background : theme.labelPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isOn ? theme.labelPrimary : theme.surface, in: Capsule())
                        .overlay(Capsule().stroke(isOn ? .clear : theme.separator, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func schoolCard(_ fund: Ministry.Fund) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your gift keeps one kid in school")
                .textRole(.subheadline, emphasized: true)
            MinistryGoalBar(raised: fund.fraction, gift: viewModel.giftFraction)
            if let raised = fund.raised, let goal = fund.goal {
                Text("\(raised.formatted) raised of \(goal.formatted)")
                    .textRole(.footnote)
                    .foregroundStyle(theme.labelSecondary)
            }
            if let line = viewModel.yearLine {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    CDDateStamp(text: String(localized: "Your gift"))
                    Text(line)
                        .textRole(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: DesignSystem.Radius.shape(16))
        .overlay(DesignSystem.Radius.shape(16).stroke(theme.separator, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pledge

/// The saved pledge: the reference, how to send the first gift, and a monthly
/// reminder.
struct GivePledgeStep: View {
    @Bindable var viewModel: GiveViewModel

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.gift.frequency == .once ? "Send your gift" : "Send your first gift")
                    .textRole(.title1, emphasized: true)
                    .accessibilityAddTraits(.isHeader)
                Text(viewModel.pledgeLead)
                    .textRole(.callout)
                    .foregroundStyle(theme.labelSecondary)
            }
            if let pledge = viewModel.pledge {
                slip(pledge)
            }
            if viewModel.gift.frequency == .monthly {
                Toggle("Remind me each month", isOn: $viewModel.remindMonthly)
                    .textRole(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.surface, in: DesignSystem.Radius.shape(14))
                    .overlay(DesignSystem.Radius.shape(14).stroke(theme.separator, lineWidth: 1))
            }
        }
    }

    private func slip(_ pledge: Pledge) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your reference")
                    .textRole(.subheadline)
                    .foregroundStyle(CDColor.onBrandSoft)
                Spacer()
                Text(pledge.reference)
                    .textRole(.title2, emphasized: true)
                    .monospacedDigit()
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(CDColor.brandSoft)
            VStack(alignment: .leading, spacing: 0) {
                sendRow(pledge)
                Divider().overlay(theme.separator)
                row(
                    number: 2,
                    title: String(localized: "Type \(pledge.reference) in the message"),
                    detail: String(localized: "so we know it's from you"),
                    copy: pledge.reference
                )
                Divider().overlay(theme.separator)
                row(
                    number: 3,
                    title: String(localized: "We confirm it within a day"),
                    detail: String(localized: "and email you a receipt"),
                    copy: nil
                )
            }
            .padding(.horizontal, 16)
        }
        .background(theme.surface, in: DesignSystem.Radius.shape(18))
        .clipShape(DesignSystem.Radius.shape(18))
        .overlay(DesignSystem.Radius.shape(18).stroke(theme.separator, lineWidth: 1))
    }

    @ViewBuilder private func sendRow(_ pledge: Pledge) -> some View {
        let amount = viewModel.gift.amount.formatted
        if viewModel.paysByBank, let bank = pledge.bank {
            row(
                number: 1,
                title: String(localized: "Send \(amount) by bank transfer"),
                detail: String(localized: "to \(bank.name) \(bank.account), \(pledge.accountName)"),
                copy: bank.account
            )
        } else {
            row(
                number: 1,
                title: String(localized: "Send \(amount) by GCash"),
                detail: String(localized: "to \(pledge.gcashNumber), \(pledge.accountName)"),
                copy: pledge.gcashNumber
            )
        }
    }

    private func row(number: Int, title: String, detail: String, copy: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .textRole(.footnote, emphasized: true)
                .foregroundStyle(theme.background)
                .frame(width: 24, height: 24)
                .background(theme.labelPrimary, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textRole(.callout, emphasized: true)
                Text(detail)
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            if let copy {
                Button("Copy") {
                    UIPasteboard.general.string = copy
                    viewModel.toast = .success(String(localized: "Copied"))
                }
                .registrationLink()
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Thanks

/// Salamat: the ministry's photo, a note from CrossDrive, and that the first
/// gift is still on its way.
struct GiveThanksStep: View {
    let viewModel: GiveViewModel

    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var photoHeight: CGFloat = 300

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: photoHeight)
                    .overlay {
                        DSRemoteImage(url: viewModel.ministry.heroURL) { CDColor.pineBand }
                    }
                    .clipped()
                    .accessibilityHidden(true)
                note
                    .background(theme.background, in: UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        topTrailingRadius: 24,
                        style: .continuous
                    ))
                    .padding(.top, -24)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(theme.accent).frame(width: 56, height: 2)
                Capsule().fill(theme.accent).frame(width: 56, height: 2)
            }
            .accessibilityHidden(true)
            Text(viewModel.thanksTitle)
                .textRole(.largeTitle, emphasized: true)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.thanksMessage)
                .textRole(.body)
            Text("CrossDrive Missions")
                .textRole(.headline, emphasized: true)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle().fill(CDColor.harvest).frame(width: 8, height: 8).accessibilityHidden(true)
                Text("**\(viewModel.waitingLine)** We confirm it within a day.")
                    .textRole(.subheadline)
                    .foregroundStyle(CDColor.onHarvestSoft)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CDColor.harvestSoft, in: DesignSystem.Radius.shape(12))
        }
        .screenMargins()
        .padding(.top, 26)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

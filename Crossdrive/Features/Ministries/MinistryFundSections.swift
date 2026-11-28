import DesignSystem
import SwiftUI

/// The school fund's progress: raised so far, the share of the goal, how many
/// kids are paid for and what is left.
struct MinistryFundProgress: View {
    let fund: Ministry.Fund

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let raised = fund.raised, let goal = fund.goal {
                HStack(alignment: .firstTextBaseline) {
                    Text(raised.formatted)
                        .textRole(.title1, emphasized: true)
                        .monospacedDigit()
                    Spacer()
                    Text(fund.fraction, format: .percent.precision(.fractionLength(0)))
                        .textRole(.headline, emphasized: true)
                        .foregroundStyle(CDColor.onBrandSoft)
                }
                Text("raised of \(goal.formatted) this school year")
                    .textRole(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
                MinistryGoalBar(raised: fund.fraction)
                    .padding(.vertical, 4)
            }
            HStack {
                Text("**\(fund.kidsPaid) of \(fund.kidsGoal)** kids paid for")
                Spacer()
                if let toGo = fund.toGo {
                    Text("**\(toGo.formatted)** to go")
                }
            }
            .textRole(.footnote)
            .foregroundStyle(theme.labelSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: DesignSystem.Radius.shape(16))
        .overlay(DesignSystem.Radius.shape(16).stroke(theme.separator, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// What one kid needs for one month, item by item.
struct MinistryFundCosts: View {
    let costs: [MinistryFundCost]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("One kid for one month")
                .textRole(.headline, emphasized: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 4)
            ForEach(costs, id: \.self) { cost in
                HStack {
                    Text(cost.title)
                    Spacer()
                    Text(cost.amount.formatted).monospacedDigit()
                }
                .textRole(.callout)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(theme.separator).frame(height: 1) }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// A goal bar: what is raised in the accent colour, then an optional gift in gold.
struct MinistryGoalBar: View {
    let raised: Double
    var gift: Double = 0

    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Rectangle().fill(theme.accent).frame(width: proxy.size.width * raised)
                Rectangle().fill(CDColor.harvest).frame(width: proxy.size.width * gift)
                Spacer(minLength: 0)
            }
            .background(CDColor.meterTrack)
            .clipShape(Capsule())
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// The pinned Give button. The school fund says how often and from how much.
struct MinistryGiveBar: View {
    let ministry: Ministry
    let action: () -> Void

    @Environment(\.theme) private var theme

    private var minimum: String {
        Gift(frequency: .once, pesos: GiveViewModel.minimumPesos).amount.formatted
    }

    var body: some View {
        VStack(spacing: 6) {
            if ministry.kind == .school {
                Button("Give to the school fund", action: action)
                    .buttonStyle(.ds(.primary))
                Text("Monthly or yearly, from \(minimum)")
                    .textRole(.footnote)
                    .foregroundStyle(theme.labelSecondary)
            } else {
                Button("Give to \(ministry.name)", action: action)
                    .buttonStyle(.ds(.primary))
            }
        }
        .screenMargins()
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 20) {
        MinistryFundProgress(fund: Ministry.Fund(
            kidsPaid: 12,
            kidsGoal: 20,
            raised: Money(amountMinor: 9_600_000, currency: "PHP"),
            goal: Money(amountMinor: 16_000_000, currency: "PHP")
        ))
        MinistryFundCosts(costs: [
            .init(title: "School fees", amount: Money(amountMinor: 45000, currency: "PHP")),
            .init(
                title: "Jeepney fare to school",
                amount: Money(amountMinor: 25000, currency: "PHP")
            ),
        ])
    }
    .padding()
    .theme(.crossdrive)
}

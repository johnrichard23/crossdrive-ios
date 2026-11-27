import DesignSystem
import SwiftUI

/// A Bible-study community: a grid of three photos over the dark Pine panel
/// with how often, the community and the place. Opens the ministry.
struct MinistryCommunityCard: View {
    let ministry: Ministry

    var body: some View {
        NavigationLink(value: MinistriesRoute.detail(ministry.id)) {
            VStack(alignment: .leading, spacing: 0) {
                MinistryPhotoGrid(urls: ministry.photoURLs)
                VStack(alignment: .leading, spacing: 2) {
                    if let schedule = ministry.schedule {
                        Text(schedule)
                            .textRole(.footnote, emphasized: true)
                            .foregroundStyle(CDColor.accentOnPine)
                    }
                    Text(ministry.name)
                        .textRole(.title2, emphasized: true)
                        .foregroundStyle(CDColor.onPine)
                    if let place = ministry.place {
                        Text(place)
                            .textRole(.subheadline)
                            .foregroundStyle(CDColor.onPineMuted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(CDColor.pineGround, in: DesignSystem.Radius.shape(20))
            .clipShape(DesignSystem.Radius.shape(20))
            .contentShape(DesignSystem.Radius.shape(20))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// One large photo with two small ones stacked beside it.
struct MinistryPhotoGrid: View {
    let urls: [URL]

    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 68

    var body: some View {
        GeometryReader { proxy in
            let big = (proxy.size.width - 3) * 2 / 3
            HStack(spacing: 3) {
                photo(0).frame(width: big)
                VStack(spacing: 3) {
                    photo(1)
                    photo(2)
                }
            }
        }
        .frame(height: rowHeight * 2 + 3)
        .accessibilityHidden(true)
    }

    private func photo(_ index: Int) -> some View {
        DSRemoteImage(url: urls.indices.contains(index) ? urls[index] : nil) {
            CDColor.pineBand
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

/// The school fund: photo, how often, what a gift pays for, how many kids are
/// paid for this year, and a Give button.
struct MinistryFundCard: View {
    let ministry: Ministry

    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var photoHeight: CGFloat = 190

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: MinistriesRoute.detail(ministry.id)) {
                VStack(alignment: .leading, spacing: 0) {
                    DSRemoteImage(url: ministry.imageURL) { theme.surfacePressed }
                        .frame(maxWidth: .infinity)
                        .frame(height: photoHeight)
                        .clipped()
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        if let schedule = ministry.schedule {
                            CDDateStamp(text: schedule)
                        }
                        Text(ministry.name)
                            .textRole(.title2, emphasized: true)
                            .foregroundStyle(theme.labelPrimary)
                        Text(ministry.summary)
                            .textRole(.subheadline)
                            .foregroundStyle(theme.labelSecondary)
                        if let fund = ministry.fund {
                            progress(fund)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)

            // shortcut: opens the fund's page until the giving steps are built.
            NavigationLink(value: MinistriesRoute.detail(ministry.id)) {
                Text("Give to the school fund")
            }
            .buttonStyle(.ds(.primary, size: .regular))
            .padding(16)
        }
        .background(theme.surface, in: DesignSystem.Radius.shape(20))
        .clipShape(DesignSystem.Radius.shape(20))
        .overlay(DesignSystem.Radius.shape(20).stroke(theme.separator, lineWidth: 1))
    }

    private func progress(_ fund: Ministry.Fund) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                Capsule()
                    .fill(CDColor.brandSoft)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(theme.accent)
                            .frame(width: proxy.size
                                .width * Double(fund.kidsPaid) / Double(fund.kidsGoal))
                    }
            }
            .frame(height: 8)
            .padding(.top, 6)
            .accessibilityHidden(true)
            Text("**\(fund.kidsPaid) of \(fund.kidsGoal)** kids are paid for this year")
                .textRole(.footnote)
                .foregroundStyle(theme.labelSecondary)
        }
    }
}

/// A skills program: a tall photo, its name, the partner who runs it, one line.
struct MinistrySkillCard: View {
    let ministry: Ministry

    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var photoHeight: CGFloat = 210

    var body: some View {
        NavigationLink(value: MinistriesRoute.detail(ministry.id)) {
            VStack(alignment: .leading, spacing: 5) {
                DSRemoteImage(url: ministry.imageURL) { theme.surfacePressed }
                    .frame(maxWidth: .infinity)
                    .frame(height: photoHeight)
                    .clipShape(DesignSystem.Radius.shape(16))
                    .accessibilityHidden(true)
                Text(ministry.name)
                    .textRole(.headline, emphasized: true)
                    .foregroundStyle(theme.labelPrimary)
                    .padding(.top, 4)
                if let partner = ministry.partner {
                    Text("With \(partner)")
                        .textRole(.footnote, emphasized: true)
                        .foregroundStyle(CDColor.onBrandSoft)
                }
                Text(ministry.summary)
                    .textRole(.footnote)
                    .foregroundStyle(theme.labelSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

import Foundation

/// One section of the Ministries list: the ministries of one kind, in the
/// order the admins set, with the section's heading.
struct MinistrySection: Identifiable, Equatable {
    let kind: Ministry.Kind
    let ministries: [Ministry]

    var id: Ministry.Kind {
        kind
    }

    /// The section heading, which is also the filter chip's name.
    var title: String {
        Self.title(of: kind)
    }

    /// "Every week, in 3 places." under Bible studies; a line under Teach a skill.
    var subtitle: String? {
        switch kind {
        case .bibleStudy:
            guard ministries.count > 1 else { return nil }
            // A shared schedule only when every community keeps the same one.
            let schedules = Set(ministries.map(\.schedule))
            let schedule = schedules.count == 1 ? schedules.first ?? nil : nil
            return schedule.map { String(localized: "\($0), in \(ministries.count) places.") }
                ?? String(localized: "In \(ministries.count) places.")
        case .skill:
            return String(
                localized: "Programs and workshops we run with partners for the community."
            )
        case .school, .other:
            return nil
        }
    }

    static func title(of kind: Ministry.Kind) -> String {
        switch kind {
        case .bibleStudy: String(localized: "Bible studies")
        case .school: String(localized: "Send a kid to school")
        case .skill: String(localized: "Teach a skill")
        case .other: String(localized: "More ministries")
        }
    }

    /// The kinds present, in the list's fixed order, for the filter chips.
    static func kinds(in ministries: [Ministry]) -> [Ministry.Kind] {
        let present = Set(ministries.map(\.kind))
        return Ministry.Kind.allCases.filter(present.contains)
    }

    /// Every kind in its fixed order, or only `kind` when one is picked.
    static func sections(
        from ministries: [Ministry],
        showing kind: Ministry.Kind?
    ) -> [MinistrySection] {
        kinds(in: ministries)
            .filter { kind == nil || $0 == kind }
            .map { kind in MinistrySection(
                kind: kind,
                ministries: ministries.filter { $0.kind == kind }
            ) }
    }
}

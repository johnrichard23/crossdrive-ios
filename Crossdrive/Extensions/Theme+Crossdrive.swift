import DesignSystem

/// The CrossDrive Missions theme, from the CrossDrive design system
/// (`CrossdriveDesign.md`, tokens Day = light, Night = dark).
extension DesignSystem.Theme {
    /// CrossDrive: Cross Purple on a Pine-tinted ground.
    ///
    /// Night's accent is `brand-text` (#B9A0EA) with Pine on it, not
    /// `purple-500`: the theme uses `accent` for links and tint too, and
    /// `purple-500` is only 3.5:1 on Pine.
    static let crossdrive = DesignSystem.Theme(
        accent: DesignSystem.color(light: 0x6A44B4, dark: 0xB9A0EA),
        accentPressed: DesignSystem.color(light: 0x573693, dark: 0x9C7AD6),
        onAccent: DesignSystem.color(light: 0xFFFFFF, dark: 0x151E1D),
        background: DesignSystem.color(light: 0xF5F7F6, dark: 0x151E1D),
        surface: DesignSystem.color(light: 0xFFFFFF, dark: 0x1F2A29),
        surfacePressed: DesignSystem.color(light: 0xE7ECEB, dark: 0x2E3B3A),
        labelPrimary: DesignSystem.color(light: 0x151E1D, dark: 0xEEF2F1),
        labelSecondary: DesignSystem.color(light: 0x4A5857, dark: 0xA3AFAE),
        labelTertiary: DesignSystem.color(light: 0x6F7D7C, dark: 0x6F7E7D),
        // A light edge at rest; focus (purple) and errors (red) carry the emphasis.
        border: DesignSystem.color(light: 0xC3CCCA, dark: 0x43514F),
        separator: DesignSystem.color(light: 0xD3DBDA, dark: 0x2E3B3A),
        success: DesignSystem.color(light: 0x1E7048, dark: 0x6FD39E),
        warning: DesignSystem.color(light: 0x8A5D0B, dark: 0xF2C96E),
        destructive: DesignSystem.color(light: 0xB3261E, dark: 0xFF9A90),
        info: DesignSystem.color(light: 0x2B62A3, dark: 0x93BDF0),
        typeface: .init(
            text: .init(
                regular: "DMSans-Regular",
                medium: "DMSans-Medium",
                semibold: "DMSans-SemiBold",
                bold: "DMSans-SemiBold"
            ),
            display: .init(
                regular: "Outfit-SemiBold",
                semibold: "Outfit-SemiBold",
                bold: "Outfit-Bold"
            )
        ),
        radius: .standard.with {
            $0.field = 8
            $0.card = 20
        },
        size: .standard.with { $0.fieldHeight = 48 }
    )
}

/// CrossDrive's brand extras: colours that are not one of the theme's roles.
/// Harvest gold appears once per screen at most (a date stamp).
enum CDColor {
    static let harvest = DesignSystem.color(light: 0xE8A93A, dark: 0xE8A93A)
    static let onHarvest = DesignSystem.color(light: 0x151E1D, dark: 0x151E1D)
    /// A soft Harvest for a status that waits on someone else ("Waiting for a coordinator").
    static let harvestSoft = DesignSystem.color(light: 0xFBF0D9, dark: 0x3A2E14)
    static let onHarvestSoft = DesignSystem.color(light: 0x8A5D0B, dark: 0xF2C877)
    static let brandSoft = DesignSystem.color(light: 0xECE4FA, dark: 0x2B2442)
    static let onBrandSoft = DesignSystem.color(light: 0x573693, dark: 0xD4C4F5)
    /// The light lavender-gray fill behind small fact chips.
    static let chipFill = DesignSystem.color(light: 0xDFE1F0, dark: 0x2B2F44)
    /// `brandSoft` while pressed.
    static let brandSoftPressed = DesignSystem.color(light: 0xDFD2F6, dark: 0x362D52)
    /// The Pine panel (verse and prayer cards) and the colours used on it.
    static let pineGround = DesignSystem.color(light: 0x151E1D, dark: 0x0E1514)
    static let onPine = DesignSystem.color(light: 0xEEF2F1, dark: 0xEEF2F1)
    static let onPineMuted = DesignSystem.color(light: 0xA3AFAE, dark: 0xA3AFAE)
    /// The band of facts under the trip photo.
    static let pineBand = DesignSystem.color(light: 0x1F2E2C, dark: 0x243634)
    static let pineDivider = DesignSystem.color(light: 0x3A4B49, dark: 0x34504D)
    static let pineLine = DesignSystem.color(light: 0x6F7E7D, dark: 0x6F7E7D)
    static let lanesOnPine = DesignSystem.color(light: 0x9C7AD6, dark: 0x9C7AD6)
    /// The ring around the round photo on the Home ticket.
    static let pineRing = DesignSystem.color(light: 0x2E3F3C, dark: 0x34504D)
    /// The empty part of a slots bar, and the small grey captions beside it.
    static let meterTrack = DesignSystem.color(light: 0xE3E8E7, dark: 0x2E3B3A)
    static let captionMuted = DesignSystem.color(light: 0x5A6A69, dark: 0xA3AFAE)
    /// Small text on a photo scrim.
    static let onScrimMuted = DesignSystem.color(light: 0xDDE6E4, dark: 0xDDE6E4)
}

extension DesignSystem.ButtonKind {
    /// A quiet second action: a soft purple fill and deep purple label, no outline.
    /// Sits under a primary button without competing with it.
    static let tonal = DesignSystem.ButtonKind { _ in
        DesignSystem.ButtonColors(
            fill: CDColor.brandSoft,
            pressedFill: CDColor.brandSoftPressed,
            foreground: CDColor.onBrandSoft
        )
    }
}

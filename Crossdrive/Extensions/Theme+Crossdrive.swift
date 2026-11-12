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
        accent: DesignSystem.color(light: 0x835BCC, dark: 0xB9A0EA),
        accentPressed: DesignSystem.color(light: 0x6A44B4, dark: 0x9C7AD6),
        onAccent: DesignSystem.color(light: 0xFFFFFF, dark: 0x151E1D),
        background: DesignSystem.color(light: 0xF5F7F6, dark: 0x151E1D),
        surface: DesignSystem.color(light: 0xFFFFFF, dark: 0x1F2A29),
        surfacePressed: DesignSystem.color(light: 0xE7ECEB, dark: 0x2E3B3A),
        labelPrimary: DesignSystem.color(light: 0x151E1D, dark: 0xEEF2F1),
        labelSecondary: DesignSystem.color(light: 0x4A5857, dark: 0xA3AFAE),
        labelTertiary: DesignSystem.color(light: 0x6F7D7C, dark: 0x6F7E7D),
        border: DesignSystem.color(light: 0x6F7D7C, dark: 0x6F7E7D),
        separator: DesignSystem.color(light: 0xD3DBDA, dark: 0x2E3B3A),
        success: DesignSystem.color(light: 0x1E7048, dark: 0x6FD39E),
        warning: DesignSystem.color(light: 0x8A5D0B, dark: 0xF2C96E),
        destructive: DesignSystem.color(light: 0xB3261E, dark: 0xFF9A90),
        info: DesignSystem.color(light: 0x2B62A3, dark: 0x93BDF0),
        radius: .standard.with {
            $0.field = 8
            $0.card = 20
        },
        size: .standard.with { $0.fieldHeight = 48 }
    )
}

import SwiftUI

/// Roles:
/// - `teal`, `purple`, `sky`, `peach`, `amber`, `rose`: bright brand fills (tiles, icon wells,
///   buttons, charts). Content on them uses `onAccent`.
/// - `tealDark`, `purpleInk`, `skyInk`, `peachInk`, `roseInk`: the same hues as text. Each clears
///   WCAG AA 4.5:1 on `bg`, `card` and its own `…Soft` tint, in both modes.
/// - `muted`: secondary text, 4.5:1 on `bg` and `card`.
///
/// The palette follows the system light/dark setting.
struct Palette {
  var bg, card, ink, muted, line: Color
  var teal, tealDark, tealSoft: Color
  var purple, purpleInk, purpleSoft: Color
  var sky, skyInk, skySoft: Color
  var peach, peachInk, peachSoft: Color
  var amber, amberSoft: Color
  var rose, roseInk, roseSoft: Color
  var napFill: Color
  var danger, onDanger, onAccent, onInk: Color

  static let light = Palette(
    bg: Color(hex: 0xF3F4F6), card: Color(hex: 0xFFFFFF), ink: Color(hex: 0x12141A),
    muted: Color(hex: 0x646A74), line: Color(hex: 0xE4E6EA),
    teal: Color(hex: 0x14C4B2), tealDark: Color(hex: 0x0F766E), tealSoft: Color(hex: 0xE6FAF7),
    purple: Color(hex: 0x7F72F7), purpleInk: Color(hex: 0x5B4FE0), purpleSoft: Color(hex: 0xEEEBFF),
    sky: Color(hex: 0x4BA3E3), skyInk: Color(hex: 0x1D6FA8), skySoft: Color(hex: 0xE5F3FC),
    peach: Color(hex: 0xFF8A65), peachInk: Color(hex: 0xB8461F), peachSoft: Color(hex: 0xFFE8DF),
    amber: Color(hex: 0xF5C84C), amberSoft: Color(hex: 0xFFF6D9),
    rose: Color(hex: 0xE86B9A), roseInk: Color(hex: 0xBE185D), roseSoft: Color(hex: 0xFCE8F1),
    napFill: Color(hex: 0xC4BEF8),
    danger: Color(hex: 0xC0392B), onDanger: .white, onAccent: Color(hex: 0x12141A), onInk: .white
  )

  static let dark = Palette(
    bg: Color(hex: 0x12141A), card: Color(hex: 0x1C1E26), ink: Color(hex: 0xF3F4F6),
    muted: Color(hex: 0xA3A9B1), line: Color(hex: 0x2A2D36),
    teal: Color(hex: 0x14C4B2), tealDark: Color(hex: 0x5EE0D2), tealSoft: Color(hex: 0x163330),
    purple: Color(hex: 0x8B80FF), purpleInk: Color(hex: 0xA59DFF), purpleSoft: Color(hex: 0x2A2648),
    sky: Color(hex: 0x5BB4EE), skyInk: Color(hex: 0x7CC4F2), skySoft: Color(hex: 0x1A3040),
    peach: Color(hex: 0xFF8A65), peachInk: Color(hex: 0xFF9E7F), peachSoft: Color(hex: 0x3D2A24),
    amber: Color(hex: 0xF5C84C), amberSoft: Color(hex: 0x3A3218),
    rose: Color(hex: 0xE86B9A), roseInk: Color(hex: 0xF08DB3), roseSoft: Color(hex: 0x3A2430),
    napFill: Color(hex: 0x4A4380),
    danger: Color(hex: 0xF07A6C), onDanger: Color(hex: 0x12141A), onAccent: Color(hex: 0x12141A), onInk: Color(hex: 0x12141A)
  )

  /// Every token resolves per trait collection, so views, sheets and system UI follow the setting.
  /// Dynamic colours are built from the hex values, not via `UIColor(Color)`, which can
  /// resolve once at load and drop the light/dark pair.
  static let adaptive: Palette = {
    func pick(light: UInt32, dark: UInt32, lightUI: UIColor? = nil, darkUI: UIColor? = nil) -> Color {
      let l = lightUI ?? UIColor(hex: light)
      let d = darkUI ?? UIColor(hex: dark)
      return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? d : l })
    }
    return Palette(
      bg: pick(light: 0xF3F4F6, dark: 0x12141A),
      card: pick(light: 0xFFFFFF, dark: 0x1C1E26),
      ink: pick(light: 0x12141A, dark: 0xF3F4F6),
      muted: pick(light: 0x646A74, dark: 0xA3A9B1),
      line: pick(light: 0xE4E6EA, dark: 0x2A2D36),
      teal: pick(light: 0x14C4B2, dark: 0x14C4B2),
      tealDark: pick(light: 0x0F766E, dark: 0x5EE0D2),
      tealSoft: pick(light: 0xE6FAF7, dark: 0x163330),
      purple: pick(light: 0x7F72F7, dark: 0x8B80FF),
      purpleInk: pick(light: 0x5B4FE0, dark: 0xA59DFF),
      purpleSoft: pick(light: 0xEEEBFF, dark: 0x2A2648),
      sky: pick(light: 0x4BA3E3, dark: 0x5BB4EE),
      skyInk: pick(light: 0x1D6FA8, dark: 0x7CC4F2),
      skySoft: pick(light: 0xE5F3FC, dark: 0x1A3040),
      peach: pick(light: 0xFF8A65, dark: 0xFF8A65),
      peachInk: pick(light: 0xB8461F, dark: 0xFF9E7F),
      peachSoft: pick(light: 0xFFE8DF, dark: 0x3D2A24),
      amber: pick(light: 0xF5C84C, dark: 0xF5C84C),
      amberSoft: pick(light: 0xFFF6D9, dark: 0x3A3218),
      rose: pick(light: 0xE86B9A, dark: 0xE86B9A),
      roseInk: pick(light: 0xBE185D, dark: 0xF08DB3),
      roseSoft: pick(light: 0xFCE8F1, dark: 0x3A2430),
      napFill: pick(light: 0xC4BEF8, dark: 0x4A4380),
      danger: pick(light: 0xC0392B, dark: 0xF07A6C),
      onDanger: pick(light: 0xFFFFFF, dark: 0x12141A, lightUI: .white),
      onAccent: pick(light: 0x12141A, dark: 0x12141A),
      onInk: pick(light: 0xFFFFFF, dark: 0x12141A, lightUI: .white)
    )
  }()
}

/// Shorthand used everywhere: `C.teal`.
let C = Palette.adaptive

enum Radius {
  static let card: CGFloat = 32
  static let tile: CGFloat = 28
}

/// Space so scroll content clears the floating dock.
let tabDockInset: CGFloat = 88

enum AppFont {
  case display, displayBold, body, medium, bold

  var name: String {
    switch self {
    case .display: "Fredoka-SemiBold"
    case .displayBold: "Fredoka-Bold"
    case .body: "Nunito-Regular"
    case .medium: "Nunito-SemiBold"
    case .bold: "Nunito-Bold"
    }
  }
}

extension Font {
  /// Bundled font that still scales with Dynamic Type.
  static func app(_ face: AppFont, _ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
    .custom(face.name, size: size, relativeTo: style)
  }
}

extension UIColor {
  convenience init(hex: UInt32, opacity: Double = 1) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: opacity
    )
  }
}

extension Color {
  init(hex: UInt32, opacity: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: opacity
    )
  }
}

extension View {
  /// The RN `shadow` token (0 8 18, 7% black). Black, not `ink`, so it stays a shadow in dark mode.
  func cardShadow(opacity: Double = 0.07) -> some View {
    shadow(color: Color.black.opacity(opacity), radius: 9, x: 0, y: 8)
  }
}

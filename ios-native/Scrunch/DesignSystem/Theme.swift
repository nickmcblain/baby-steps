import SwiftUI

/// Port of lib/theme.ts. The app is forced light (Info.plist), like the RN build;
/// `dark` is kept so following the system later is a one-key change.
struct Palette {
  var bg, card, ink, muted, line: Color
  var teal, tealDark, tealSoft: Color
  var purple, purpleSoft: Color
  var sky, skySoft: Color
  var peach, peachSoft: Color
  var amber, amberSoft: Color
  var rose, roseSoft: Color
  var danger, onAccent, onInk: Color

  static let light = Palette(
    bg: Color(hex: 0xF3F4F6), card: Color(hex: 0xFFFFFF), ink: Color(hex: 0x12141A),
    muted: Color(hex: 0x8A9099), line: Color(hex: 0xEEF0F3),
    teal: Color(hex: 0x14C4B2), tealDark: Color(hex: 0x0B9E90), tealSoft: Color(hex: 0xE6FAF7),
    purple: Color(hex: 0x6D5EF5), purpleSoft: Color(hex: 0xEEEBFF),
    sky: Color(hex: 0x4BA3E3), skySoft: Color(hex: 0xE5F3FC),
    peach: Color(hex: 0xFF8A65), peachSoft: Color(hex: 0xFFE8DF),
    amber: Color(hex: 0xF5C84C), amberSoft: Color(hex: 0xFFF6D9),
    rose: Color(hex: 0xE86B9A), roseSoft: Color(hex: 0xFCE8F1),
    danger: Color(hex: 0xE15B4C), onAccent: .white, onInk: .white
  )

  static let dark = Palette(
    bg: Color(hex: 0x12141A), card: Color(hex: 0x1C1E26), ink: Color(hex: 0xF3F4F6),
    muted: Color(hex: 0x9AA0A8), line: Color(hex: 0x2A2D36),
    teal: Color(hex: 0x14C4B2), tealDark: Color(hex: 0x5EE0D2), tealSoft: Color(hex: 0x163330),
    purple: Color(hex: 0x8B80FF), purpleSoft: Color(hex: 0x2A2648),
    sky: Color(hex: 0x5BB4EE), skySoft: Color(hex: 0x1A3040),
    peach: Color(hex: 0xFF8A65), peachSoft: Color(hex: 0x3D2A24),
    amber: Color(hex: 0xF5C84C), amberSoft: Color(hex: 0x3A3218),
    rose: Color(hex: 0xE86B9A), roseSoft: Color(hex: 0x3A2430),
    danger: Color(hex: 0xF07A6C), onAccent: .white, onInk: Color(hex: 0x12141A)
  )
}

/// Shorthand used everywhere: `C.teal`.
let C = Palette.light

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
  /// The RN `shadow` token (0 8 18, 7% ink).
  func cardShadow(opacity: Double = 0.07) -> some View {
    shadow(color: C.ink.opacity(opacity), radius: 9, x: 0, y: 8)
  }
}

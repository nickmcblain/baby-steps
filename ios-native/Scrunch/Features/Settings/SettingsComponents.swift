import SwiftUI
import UIKit

/// Links that change per environment, read from Info.plist (set in the xcconfigs).
enum PrivacyConfig {
  static var policyURL: URL? { string("PrivacyPolicyURL").flatMap(URL.init(string:)) }
  static var supportEmail: String? { string("SupportEmail") }
  static var supportURL: URL? { supportEmail.flatMap { URL(string: "mailto:\($0)") } }
  static let nhs111 = URL(string: "https://111.nhs.uk")!

  static var appVersion: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "\(version) (\(build))"
  }

  private static func string(_ key: String) -> String? {
    let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "").trimmingCharacters(in: .whitespaces)
    return raw.isEmpty || raw.hasPrefix("$(") ? nil : raw
  }
}

/// A titled card of rows, like a grouped iOS Settings section.
struct SettingsSection<Content: View>: View {
  var title: String?
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let title {
        Text(title)
          .font(.app(.bold, 13, relativeTo: .footnote))
          .foregroundStyle(C.muted)
          .padding(.leading, 12)
          .accessibilityAddTraits(.isHeader)
      }
      Card(padding: 6, spacing: 0) { content }
    }
  }
}

struct SettingsDivider: View {
  var body: some View {
    Rectangle().fill(C.line).frame(height: 1).padding(.leading, 56)
  }
}

struct SettingsRowLabel: View {
  let title: String
  var value: String?
  let systemImage: String
  var tint: Color = C.teal
  var destructive = false
  var accessory = "chevron.right"

  var body: some View {
    HStack(spacing: 12) {
      IconWell(systemImage: systemImage, tint: destructive ? C.danger : tint, size: 32)
      Text(title)
        .font(.app(.bold, 16))
        .foregroundStyle(destructive ? C.danger : C.ink)
        .multilineTextAlignment(.leading)
      Spacer(minLength: 8)
      if let value {
        Text(value)
          .font(.app(.medium, 15))
          .foregroundStyle(C.muted)
          .lineLimit(1)
      }
      Image(systemName: accessory)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(C.muted)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, 10)
    .frame(minHeight: 52)
    .contentShape(Rectangle())
  }
}

struct SettingsRow: View {
  let title: String
  var value: String?
  let systemImage: String
  var tint: Color = C.teal
  var destructive = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      SettingsRowLabel(title: title, value: value, systemImage: systemImage, tint: tint, destructive: destructive)
    }
    .buttonStyle(PressScale())
  }
}

/// Opens an external link (web or mail) from a settings row.
struct SettingsLinkRow: View {
  let title: String
  var value: String?
  let systemImage: String
  var tint: Color = C.teal
  let url: URL?

  var body: some View {
    if let url {
      Link(destination: url) {
        SettingsRowLabel(title: title, value: value, systemImage: systemImage, tint: tint, accessory: "arrow.up.right")
      }
      .buttonStyle(PressScale())
    } else {
      SettingsRowLabel(title: title, value: "Coming soon", systemImage: systemImage, tint: tint, accessory: "minus")
        .opacity(0.6)
    }
  }
}

/// Share sheet for a file on disk.
struct ActivityShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Sheet chrome shared by the settings sheets: title, close button, scrolling body.
struct SettingsSheetScaffold<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          Text(title)
            .font(.app(.displayBold, 28, relativeTo: .title))
            .foregroundStyle(C.ink)
            .accessibilityAddTraits(.isHeader)
          Spacer()
          CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
        }
        content
      }
      .padding(20)
      .padding(.top, 8)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(C.bg.ignoresSafeArea())
  }
}

struct BulletList: View {
  let items: [String]
  var marker = "circle.fill"
  var tint: Color = C.tealDark

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(items, id: \.self) { item in
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Image(systemName: marker)
            .font(.system(size: marker == "circle.fill" ? 6 : 13, weight: .bold))
            .foregroundStyle(tint)
            .accessibilityHidden(true)
          Text(item)
            .font(.app(.body, 15))
            .foregroundStyle(C.ink)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }
}

/// The square tick box used for consent (matches New baby).
struct ConsentCheckbox: View {
  @Binding var isOn: Bool
  let text: String

  var body: some View {
    Button { isOn.toggle() } label: {
      HStack(alignment: .top, spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isOn ? C.teal : C.card)
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(isOn ? C.teal : C.tealDark, lineWidth: 2))
          if isOn {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(C.onAccent)
          }
        }
        .frame(width: 24, height: 24)
        .padding(.top, 2)
        Text(text)
          .font(.app(.body, 14))
          .foregroundStyle(C.ink)
          .lineSpacing(4)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isOn ? [.isSelected] : [])
    .accessibilityHint("Checkbox")
  }
}

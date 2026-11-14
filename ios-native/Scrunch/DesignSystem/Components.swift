import SwiftUI

// Port of components/ui.tsx and components/Screen.tsx.

struct Card<Content: View>: View {
  var padding: CGFloat = 20
  var spacing: CGFloat = 12
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: spacing) { content }
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(C.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
      .cardShadow()
  }
}

struct ScreenTitle: View {
  let text: Text
  init(_ key: LocalizedStringKey) { text = Text(key) }
  init(verbatim: String) { text = Text(verbatim: verbatim) }

  var body: some View {
    text
      .font(.app(.displayBold, 34, relativeTo: .largeTitle))
      .tracking(-0.6)
      .foregroundStyle(C.ink)
      .accessibilityAddTraits(.isHeader)
  }
}

struct Subtitle: View {
  let text: LocalizedStringKey
  init(_ text: LocalizedStringKey) { self.text = text }

  var body: some View {
    Text(text)
      .font(.app(.body, 16))
      .foregroundStyle(C.muted)
      .lineSpacing(4)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct FieldLabel: View {
  let text: LocalizedStringKey
  init(_ text: LocalizedStringKey) { self.text = text }

  var body: some View {
    Text(text)
      .font(.app(.medium, 13, relativeTo: .footnote))
      .foregroundStyle(C.muted)
      .padding(.leading, 8)
  }
}

struct Pill: View {
  let label: LocalizedStringKey
  var selected = false
  var tint: Color = C.tealSoft
  var ink: Color = C.tealDark
  var selectedTint: Color = C.ink
  var selectedInk: Color = C.onInk
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.app(.bold, 15))
        .foregroundStyle(selected ? selectedInk : ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(selected ? selectedTint : tint, in: Capsule())
    }
    .buttonStyle(PressScale())
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// Teal pill button. An async action shows a spinner and blocks double taps.
struct PrimaryButton: View {
  let label: LocalizedStringKey
  var disabled = false
  var tint: Color = C.teal
  let action: () async -> Void

  @State private var busy = false

  var body: some View {
    Button {
      guard !busy, !disabled else { return }
      busy = true
      Task {
        await action()
        busy = false
      }
    } label: {
      ZStack {
        if busy {
          ProgressView().tint(C.onAccent)
        } else {
          Text(label).font(.app(.bold, 17)).foregroundStyle(C.onAccent)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 56)
      .padding(.horizontal, 22)
      .background(tint, in: Capsule())
      .opacity(disabled || busy ? 0.45 : 1)
    }
    .buttonStyle(PressScale())
    .disabled(disabled || busy)
  }
}

struct SecondaryButton: View {
  let label: LocalizedStringKey
  var ink: Color = C.ink
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.app(.bold, 16))
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(C.card, in: Capsule())
        .cardShadow()
    }
    .buttonStyle(PressScale())
  }
}

/// 44pt white circle with a shadow (RN `IconButton`).
struct CircleIconButton: View {
  let systemImage: String
  let label: LocalizedStringKey
  var ink: Color = C.ink
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(ink)
        .frame(width: 44, height: 44)
        .background(C.card, in: Circle())
        .cardShadow()
    }
    .buttonStyle(PressScale())
    .accessibilityLabel(label)
  }
}

struct FormField: View {
  let label: LocalizedStringKey
  @Binding var text: String
  var placeholder: LocalizedStringKey = ""
  var axis: Axis = .horizontal
  var keyboard: UIKeyboardType = .default

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      FieldLabel(label)
      TextField(placeholder, text: $text, axis: axis)
        .font(.app(.medium, 16))
        .foregroundStyle(C.ink)
        .keyboardType(keyboard)
        .lineLimit(axis == .vertical ? 3...6 : 1...1)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(C.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .cardShadow()
    }
  }
}

struct PressScale: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

/// RN `Screen`: bg colour, 20pt padding, 16pt gaps, optional floating back button.
struct ScreenScaffold<Content: View, Trailing: View>: View {
  var showsBack = true
  var clearDock = false
  var scrolls = true
  @ViewBuilder var trailing: Trailing
  @ViewBuilder var content: Content

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack(alignment: .top) {
      C.bg.ignoresSafeArea()
      Group {
        if scrolls {
          ScrollView(showsIndicators: false) { column }
            .scrollDismissesKeyboard(.interactively)
        } else {
          column.frame(maxHeight: .infinity, alignment: .top)
        }
      }
      if hasChrome {
        HStack {
          if showsBack {
            CircleIconButton(systemImage: "chevron.left", label: "Back") { dismiss() }
          }
          Spacer()
          trailing
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
  }

  private var hasChrome: Bool { showsBack || Trailing.self != EmptyView.self }

  private var column: some View {
    VStack(alignment: .leading, spacing: 16) { content }
      .padding(20)
      .padding(.top, hasChrome ? 40 : 0)
      .padding(.bottom, clearDock ? tabDockInset + 20 : 20)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension ScreenScaffold where Trailing == EmptyView {
  init(showsBack: Bool = true, clearDock: Bool = false, scrolls: Bool = true, @ViewBuilder content: () -> Content) {
    self.init(showsBack: showsBack, clearDock: clearDock, scrolls: scrolls, trailing: { EmptyView() }, content: content)
  }
}

struct LoadingView: View {
  var label: LocalizedStringKey? = nil

  var body: some View {
    VStack(spacing: 12) {
      ProgressView().tint(C.teal)
      if let label {
        Text(label).font(.app(.body, 15)).foregroundStyle(C.muted)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(C.bg.ignoresSafeArea())
  }
}

/// Circular icon well used on tiles and the add-log sheet.
struct IconWell: View {
  let systemImage: String
  let tint: Color
  var size: CGFloat = 40
  var ink: Color = C.onInk

  var body: some View {
    Image(systemName: systemImage)
      .font(.system(size: size * 0.45, weight: .semibold))
      .foregroundStyle(ink)
      .frame(width: size, height: size)
      .background(tint, in: Circle())
      .accessibilityHidden(true)
  }
}

/// Hidden navigation bars disable the edge-swipe back gesture; this restores it.
extension UINavigationController: UIGestureRecognizerDelegate {
  override open func viewDidLoad() {
    super.viewDidLoad()
    interactivePopGestureRecognizer?.delegate = self
  }

  public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    viewControllers.count > 1
  }
}

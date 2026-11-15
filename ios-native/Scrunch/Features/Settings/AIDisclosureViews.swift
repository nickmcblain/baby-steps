import ScrunchCore
import SwiftUI

/// What Ask and Speak send, to whom, and what stays private.
struct AIDisclosureContent: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Subtitle(LocalizedStringKey(AIDisclosure.summary))
      Card {
        Text("Who answers").font(.app(.bold, 17)).foregroundStyle(C.ink)
        Text(AIDisclosure.provider).font(.app(.body, 15)).foregroundStyle(C.ink).lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
      Card {
        Text("What's sent").font(.app(.bold, 17)).foregroundStyle(C.ink)
        BulletList(items: AIDisclosure.sent)
      }
      Card {
        Text("What isn't sent").font(.app(.bold, 17)).foregroundStyle(C.ink)
        BulletList(items: AIDisclosure.notSent, tint: C.muted)
      }
      Card {
        Text("How it's handled").font(.app(.bold, 17)).foregroundStyle(C.ink)
        Text(AIDisclosure.handling).font(.app(.body, 15)).foregroundStyle(C.ink).lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
        Text(AIDisclosure.medical).font(.app(.medium, 14)).foregroundStyle(C.muted).lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

/// Settings › About Ask and Speak (AI). Also lets people withdraw consent.
struct AboutAIView: View {
  @AppStorage(AIDisclosure.consentKey) private var aiConsent = ""

  var body: some View {
    SettingsSheetScaffold(title: AIDisclosure.title) {
      AIDisclosureContent()
      if AIDisclosure.hasConsented(aiConsent) {
        SecondaryButton(label: "Turn off Ask and Speak", ink: C.danger) { aiConsent = "" }
        Text("You'll be asked again before you next use them. Past Ask chats stay in the app until you delete your account.")
          .font(.app(.body, 13)).foregroundStyle(C.muted).lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        Text("Ask and Speak are off. You'll be asked to agree before you first use them.")
          .font(.app(.body, 13)).foregroundStyle(C.muted).lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

/// One-time agreement shown before the first Ask or Speak.
struct AIConsentView: View {
  var title = "Before you use Ask"
  let onAgree: () -> Void
  let onCancel: () -> Void

  @AppStorage(AIDisclosure.consentKey) private var aiConsent = ""
  @State private var agreed = false

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 16) {
        Text(title)
          .font(.app(.displayBold, 30, relativeTo: .largeTitle))
          .foregroundStyle(C.ink)
          .accessibilityAddTraits(.isHeader)
        AIDisclosureContent()
        ConsentCheckbox(isOn: $agreed, text: AIDisclosure.consent)
        PrimaryButton(label: "Continue", disabled: !agreed) {
          aiConsent = AIDisclosure.consentVersion
          onAgree()
        }
        SecondaryButton(label: "Not now", action: onCancel)
      }
      .padding(20)
      .padding(.top, 8)
    }
    .background(C.bg.ignoresSafeArea())
  }
}

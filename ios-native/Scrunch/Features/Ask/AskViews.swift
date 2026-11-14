import ScrunchCore
import SwiftUI

/// Port of ask/index.tsx: chat with the NHS-grounded agent.
struct AskView: View {
  let babyId: BabyID
  let initialQuestion: String?

  @Environment(ConvexService.self) private var convex
  @Environment(AppRouter.self) private var router
  @Environment(\.dismiss) private var dismiss
  @State private var threadId: ThreadID?
  @State private var messages = Live<[ChatMessage]>()
  @State private var draft = ""
  @State private var sending = false
  @State private var pendingUser: String?
  @State private var sentQuestion: String?
  @State private var alert: FormAlert?
  @FocusState private var composerFocused: Bool

  init(babyId: BabyID, initialQuestion: String?, threadId: ThreadID? = nil) {
    self.babyId = babyId
    self.initialQuestion = initialQuestion
    _threadId = State(initialValue: threadId)
  }

  private var showPendingUser: Bool {
    guard let pendingUser else { return false }
    return !(messages.value ?? []).contains { $0.role == .user && $0.content == pendingUser }
  }

  private var canSend: Bool {
    !sending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    ZStack(alignment: .top) {
      C.bg.ignoresSafeArea()
      ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
          LazyVStack(spacing: 10) {
            if messages.value?.isEmpty == true && !sending && !showPendingUser {
              starters
            }
            ForEach(messages.value ?? []) { message in
              bubble(message)
            }
            if showPendingUser, let pendingUser {
              userBubble(pendingUser)
            }
            if sending {
              HStack(spacing: 10) {
                ProgressView().tint(C.teal)
                Text("Thinking…").font(.app(.body, 15)).foregroundStyle(C.muted)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
            }
            Color.clear.frame(height: 1).id("bottom")
          }
          .padding(.horizontal, 20)
          .padding(.top, 64)
          .padding(.bottom, 12)
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: messages.value?.count) { scrollToEnd(proxy) }
        .onChange(of: sending) { scrollToEnd(proxy) }
        .onChange(of: showPendingUser) { scrollToEnd(proxy) }
      }
      .safeAreaInset(edge: .bottom) { composer }

      HStack {
        CircleIconButton(systemImage: "chevron.left", label: "Back") { dismiss() }
        Spacer()
        CircleIconButton(systemImage: "plus", label: "New chat") { Task { await startNewChat() } }
        CircleIconButton(systemImage: "list.bullet", label: "Past chats") { router.push(babyId, .askHistory) }
          .padding(.leading, 8)
      }
      .padding(.horizontal, 16)
      .padding(.top, 4)
    }
    .toolbar(.hidden, for: .navigationBar)
    .formAlert($alert)
    .task {
      guard threadId == nil else { return }
      do {
        threadId = try await convex.mutation(API.chat.ensureThread(babyId))
      } catch {
        alert = FormAlert(title: "Could not open chat", message: UserMessage.from(error, fallback: String(localized: "Try again")))
      }
    }
    .task(id: threadId) {
      guard let threadId else { return }
      await messages.bind(API.chat.listMessages(threadId), convex)
    }
    .task(id: threadId) {
      let question = initialQuestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard !question.isEmpty, threadId != nil, !sending, sentQuestion != question else { return }
      sentQuestion = question
      await send(question)
    }
  }

  private var starters: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(AskSafety.entryTitle).font(.app(.displayBold, 28)).foregroundStyle(C.ink).accessibilityAddTraits(.isHeader)
      Text("\(AskSafety.entrySubtitle). Every answer says where it comes from.")
        .font(.app(.body, 15)).foregroundStyle(C.muted)
        .padding(.bottom, 6)
      ForEach(AskSafety.starterQuestions, id: \.self) { question in
        Button { Task { await send(question) } } label: {
          Text(question)
            .font(.app(.medium, 15))
            .foregroundStyle(C.ink)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .cardShadow()
        }
        .buttonStyle(PressScale())
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var composer: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(AskSafety.disclaimer)
        .font(.app(.body, 12))
        .foregroundStyle(C.muted)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
      HStack(alignment: .bottom, spacing: 8) {
        TextField(AskSafety.placeholder, text: $draft, axis: .vertical)
          .font(.app(.body, 16))
          .foregroundStyle(C.ink)
          .lineLimit(1...5)
          .focused($composerFocused)
          .disabled(sending)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .frame(minHeight: 48)
          .background(C.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
          .cardShadow()
        Button { Task { await send(nil) } } label: {
          Image(systemName: "arrow.up")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(C.teal, in: Circle())
            .opacity(canSend ? 1 : 0.45)
        }
        .disabled(!canSend)
        .accessibilityLabel("Send")
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
    .padding(.bottom, 8)
    .background(C.bg)
  }

  @ViewBuilder
  private func bubble(_ message: ChatMessage) -> some View {
    if message.role == .user {
      userBubble(message.content)
    } else {
      VStack(alignment: .leading, spacing: 6) {
        MarkdownText(text: message.content)
        VStack(alignment: .leading, spacing: 2) {
          Text(AskSafety.sourcesHeading).font(.app(.bold, 12)).foregroundStyle(C.ink)
          ForEach(AskSafety.sourceLines(message.citations), id: \.self) { citation in
            if let url = citation.url.flatMap(URL.init(string:)) {
              Link("· \(citation.title)", destination: url)
                .font(.app(.medium, 12))
                .foregroundStyle(C.tealDark)
            } else {
              Text("· \(citation.title)").font(.app(.medium, 12)).foregroundStyle(C.muted)
            }
          }
        }
        .padding(.top, 4)
        Text(AskSafety.helpLine)
          .font(.app(.bold, 12))
          .foregroundStyle(C.ink)
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(C.peachSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(C.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      .cardShadow()
      .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in width * 0.92 }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func userBubble(_ text: String) -> some View {
    Text(text)
      .font(.app(.body, 15))
      .foregroundStyle(.white)
      .lineSpacing(4)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(C.teal, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.leading, 28)
  }

  private func scrollToEnd(_ proxy: ScrollViewProxy) {
    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
  }

  private func send(_ textArg: String?) async {
    let text = (textArg ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, let threadId, !sending else { return }
    if AskSafety.isEmergency(text) {
      alert = FormAlert(verbatimTitle: AskSafety.emergencyTitle, message: AskSafety.emergencyBody)
    }
    draft = ""
    pendingUser = text
    sending = true
    defer {
      sending = false
      pendingUser = nil
    }
    do {
      _ = try await convex.action(API.chatAgent.ask(babyId: babyId, threadId: threadId, message: text))
    } catch {
      alert = FormAlert(title: "Ask failed", message: UserMessage.from(error, fallback: String(localized: "Try again")))
      draft = text
    }
  }

  private func startNewChat() async {
    do {
      let id = try await convex.mutation(API.chat.createThread(babyId))
      messages.reset()
      threadId = id
      draft = ""
      pendingUser = nil
    } catch {
      alert = FormAlert(title: "Could not start chat", message: UserMessage.from(error, fallback: String(localized: "Try again")))
    }
  }
}

/// Renders the assistant's markdown: block structure from `MarkdownBlocks`, inline
/// bold/italic/links via `AttributedString(markdown:)`.
struct MarkdownText: View {
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(MarkdownBlocks.parse(text).enumerated()), id: \.offset) { _, block in
        switch block {
        case .heading(let value):
          inline(value).font(.app(.bold, 16)).accessibilityAddTraits(.isHeader)
        case .paragraph(let value):
          inline(value).font(.app(.body, 15))
        case .bullet(let value):
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").font(.app(.body, 15))
            inline(value).font(.app(.body, 15))
          }
        case .numbered(let number, let value):
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number).").font(.app(.body, 15))
            inline(value).font(.app(.body, 15))
          }
        }
      }
    }
    .foregroundStyle(C.ink)
    .tint(C.tealDark)
  }

  private func inline(_ value: String) -> Text {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    let attributed = (try? AttributedString(markdown: value, options: options)) ?? AttributedString(value)
    return Text(attributed)
  }
}

/// Port of ask/history.tsx.
struct AskHistoryView: View {
  let babyId: BabyID

  @Environment(ConvexService.self) private var convex
  @Environment(AppRouter.self) private var router
  @State private var threads = Live<[ChatThread]>()

  var body: some View {
    let now = Date().epochMs
    ScreenScaffold {
      ScreenTitle("Chats")
      if (threads.value ?? []).isEmpty {
        Text("No chats yet — tap + on Ask to start one.").font(.app(.body, 15)).foregroundStyle(C.muted).lineSpacing(4)
      } else {
        VStack(spacing: 10) {
          ForEach(threads.value ?? []) { thread in
            Button { router.replaceTop(babyId, .ask(thread: thread.id)) } label: {
              VStack(alignment: .leading, spacing: 6) {
                Text(thread.title?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? "New chat")
                  .font(.app(.bold, 16))
                  .foregroundStyle(C.ink)
                  .lineLimit(2)
                  .multilineTextAlignment(.leading)
                Text(Format.relative(thread.updatedAt, now: now)).font(.app(.medium, 13)).foregroundStyle(C.muted)
              }
              .padding(16)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(C.card, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
              .cardShadow()
            }
            .buttonStyle(PressScale())
          }
        }
      }
    }
    .task { await threads.bind(API.chat.listThreads(babyId), convex) }
  }
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}

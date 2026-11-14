import Foundation

// Ask screen safety copy and a small markdown block parser for assistant replies.

public enum AskSafety {
  static let emergencyPhrases = ["not breathing", "unresponsive", "blue lips", "turning blue", "seizure", "choking badly"]

  /// Mirrors `/\b(not breathing|unresponsive|blue lips|turning blue|seizure|choking badly)\b/i`.
  public static func isEmergency(_ text: String) -> Bool {
    let lowered = text.lowercased()
    return emergencyPhrases.contains { phrase in
      var searchStart = lowered.startIndex
      while let range = lowered.range(of: phrase, range: searchStart..<lowered.endIndex) {
        let beforeOK = range.lowerBound == lowered.startIndex || !isWordChar(lowered[lowered.index(before: range.lowerBound)])
        let afterOK = range.upperBound == lowered.endIndex || !isWordChar(lowered[range.upperBound])
        if beforeOK && afterOK { return true }
        searchStart = range.upperBound
      }
      return false
    }
  }

  static func isWordChar(_ c: Character) -> Bool {
    c == "_" || (c.isASCII && (c.isLetter || c.isNumber))
  }

  public static let emergencyTitle = "Seek urgent help"
  public static let emergencyBody =
    "If your baby is not breathing normally, is unresponsive, blue/grey, or having a seizure, call 999 now."

  public static let disclaimer =
    "Scrunch is not a medical or healthcare service. Guidance only — not diagnosis, clinical advice, or triage. Emergencies: call 999. Urgent advice: NHS 111 or your midwife. Scrunch is independent and not affiliated with the NHS or The Lullaby Trust; it summarises their public guidance."

  public static let placeholder = "Ask about newborn care…"

  public static let entryTitle = "Ask Scrunch"
  public static let entrySubtitle = "Answers from NHS and Lullaby Trust guidance"

  public static let sourcesHeading = "Where this comes from"
  public static let noSourceNote =
    "General guidance. No specific NHS or Lullaby Trust page matched, so check nhs.uk or ask your health visitor."
  public static let helpLine = "Worried? Call your GP or NHS 111. Emergency: call 999."

  public static let starterQuestions = [
    "What should my baby wear to sleep tonight?",
    "How many wet nappies should I expect?",
    "How often do newborns usually feed?",
    "What does safer sleep look like?",
  ]

  /// Source lines for a reply. Never empty: with no citations it says so plainly.
  public static func sourceLines(_ citations: [Citation]?) -> [Citation] {
    let list = citations ?? []
    return list.isEmpty ? [Citation(title: noSourceNote, url: nil)] : list
  }
}

public enum MarkdownBlock: Equatable, Sendable {
  case heading(String)
  case paragraph(String)
  case bullet(String)
  case numbered(Int, String)
}

public enum MarkdownBlocks {
  /// Splits a reply into headings, bullets, numbered items and paragraphs. Inline
  /// styling (bold, italics, links) is left for `AttributedString(markdown:)`.
  public static func parse(_ text: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    var paragraph: [String] = []

    func flush() {
      if !paragraph.isEmpty {
        blocks.append(.paragraph(paragraph.joined(separator: " ")))
        paragraph = []
      }
    }

    for raw in text.components(separatedBy: "\n") {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.isEmpty {
        flush()
        continue
      }
      if line.hasPrefix("#") {
        flush()
        blocks.append(.heading(line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)))
      } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
        flush()
        blocks.append(.bullet(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
      } else if let dot = line.firstIndex(of: "."), let number = Int(line[..<dot]),
                line.index(after: dot) < line.endIndex, line[line.index(after: dot)] == " " {
        flush()
        blocks.append(.numbered(number, String(line[line.index(dot, offsetBy: 2)...])))
      } else {
        paragraph.append(line)
      }
    }
    flush()
    return blocks
  }
}

/// The agent sometimes ends a reply with its own "---" / "Sources:" block. That is pulled
/// out so the app can show sources as links instead of raw markdown.
public enum AskAnswer {
  public static func split(_ text: String) -> (body: String, sources: [Citation]) {
    let lines = text.components(separatedBy: "\n")
    guard let start = lines.firstIndex(where: { sourcesRemainder($0) != nil }) else {
      return (text, [])
    }
    var bodyLines = Array(lines[..<start])
    while let last = bodyLines.last, isRule(last) || last.trimmingCharacters(in: .whitespaces).isEmpty {
      bodyLines.removeLast()
    }
    var items: [String] = []
    if let inline = sourcesRemainder(lines[start]), !inline.isEmpty {
      items += inline.components(separatedBy: ";")
    }
    items += lines[(start + 1)...]
    let sources = items.compactMap(citation)
    return (bodyLines.joined(separator: "\n"), sources)
  }

  /// Parsed sources first, then stored citations, without repeats.
  public static func merge(_ parsed: [Citation], _ stored: [Citation]?) -> [Citation] {
    var seen = Set<String>()
    return (parsed + (stored ?? [])).filter { citation in
      let keys = Set([citation.title, citation.url].compactMap { $0?.lowercased() })
      guard seen.isDisjoint(with: keys) else { return false }
      seen.formUnion(keys)
      return true
    }
  }

  static func isRule(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return trimmed.count >= 3 && trimmed.allSatisfy { $0 == "-" || $0 == "*" || $0 == "_" }
  }

  /// Text after "Sources:" when the line is a sources heading (any markdown dressing).
  static func sourcesRemainder(_ line: String) -> String? {
    var trimmed = line.trimmingCharacters(in: .whitespaces)
    while let first = trimmed.first, "-*_#> ".contains(first) { trimmed.removeFirst() }
    let lowered = trimmed.lowercased()
    for heading in ["sources", "source"] where lowered.hasPrefix(heading) {
      var rest = trimmed.dropFirst(heading.count)
      while let first = rest.first, "*_".contains(first) { rest.removeFirst() }
      if rest.trimmingCharacters(in: .whitespaces).isEmpty { return "" }
      guard rest.first == ":" else { continue }
      rest.removeFirst()
      while let first = rest.first, "*_ ".contains(first) { rest.removeFirst() }
      return rest.trimmingCharacters(in: .whitespaces)
    }
    return nil
  }

  static func citation(_ raw: String) -> Citation? {
    var line = raw.trimmingCharacters(in: .whitespaces)
    for prefix in ["- ", "* ", "• "] where line.hasPrefix(prefix) { line.removeFirst(prefix.count) }
    if let dot = line.firstIndex(of: "."), Int(line[..<dot]) != nil { line = String(line[line.index(after: dot)...]) }
    line = line.trimmingCharacters(in: .whitespaces)
    guard !line.isEmpty, !isRule(line) else { return nil }

    if let open = line.firstIndex(of: "["), let close = line[open...].firstIndex(of: "]"),
       line.index(after: close) < line.endIndex, line[line.index(after: close)] == "(",
       let end = line[close...].firstIndex(of: ")") {
      let title = String(line[line.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
      let url = String(line[line.index(close, offsetBy: 2)..<end])
      return Citation(title: title.isEmpty ? url : title, url: url)
    }
    if let range = line.range(of: "https://") ?? line.range(of: "http://") {
      let url = String(line[range.lowerBound...].prefix { !$0.isWhitespace && $0 != ")" && $0 != ">" })
      var title = line.replacingOccurrences(of: url, with: "")
      title = title.trimmingCharacters(in: CharacterSet(charactersIn: " ()<>:-–—*_"))
      return Citation(title: title.isEmpty ? (URL(string: url)?.host ?? url) : title, url: url)
    }
    let title = line.trimmingCharacters(in: CharacterSet(charactersIn: " *_"))
    return title.isEmpty ? nil : Citation(title: title)
  }
}

public enum InviteCode {
  public static let length = 6
  public static let allowed = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

  public static func sanitize(_ raw: String) -> String {
    var out = ""
    for ch in raw.uppercased() where allowed.contains(ch) {
      out.append(ch)
      if out.count == length { break }
    }
    return out
  }
}

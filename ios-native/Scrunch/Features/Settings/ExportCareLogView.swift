import ScrunchCore
import SwiftUI
import UIKit

extension ConvexService {
  /// The current value of a query, without keeping the subscription open.
  func queryOnce<R: Decodable>(_ call: ConvexCall<R>) async throws -> R {
    for try await value in subscribe(call).values { return value }
    throw CancellationError()
  }
}

struct ExportCareLogView: View {
  enum Format: String, CaseIterable { case pdf = "PDF", csv = "CSV" }

  @Environment(ConvexService.self) private var convex
  @Environment(ActiveBabyStore.self) private var activeBaby
  @State private var babies = Live<[Baby]>()
  @State private var babyId: BabyID?
  @State private var format = Format.pdf
  @State private var file: ExportFile?
  @State private var written: URL?
  @State private var note: String?
  @State private var alert: FormAlert?

  private var selectedId: BabyID? {
    let list = babies.value ?? []
    if let babyId, list.contains(where: { $0.id == babyId }) { return babyId }
    return list.first(where: { $0.id == activeBaby.babyId })?.id ?? list.first?.id
  }

  var body: some View {
    SettingsSheetScaffold(title: "Export care log") {
      Subtitle("Make a copy of everything logged for your baby. A PDF is easy to show your health visitor or GP. A CSV opens in Numbers, Excel or Google Sheets.")

      if babies.isLoading {
        ProgressView().tint(C.teal).frame(maxWidth: .infinity, minHeight: 80)
      } else if (babies.value ?? []).isEmpty {
        Card { Text("Add a baby first. There's nothing to export yet.").font(.app(.body, 15)).foregroundStyle(C.ink) }
      } else {
        FieldLabel("Baby")
        FlowPills(items: babies.value ?? [], selected: selectedId) { babyId = $0 }
        FieldLabel("Format")
        HStack(spacing: 8) {
          ForEach(Format.allCases, id: \.self) { option in
            Pill(label: option.rawValue, selected: format == option) { format = option }
          }
        }
        PrimaryButton(label: "Create \(format.rawValue)", disabled: selectedId == nil) { await export() }
          .padding(.top, 8)
        if let note {
          Text(note).font(.app(.medium, 14)).foregroundStyle(C.muted).fixedSize(horizontal: false, vertical: true)
        }
      }

      Text("The file is made on your phone and removed when you close the share sheet. Only share it with people you trust.")
        .font(.app(.body, 13)).foregroundStyle(C.muted).lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
    .formAlert($alert)
    .task { await babies.bind(API.babies.list(), convex) }
    .sheet(item: $file, onDismiss: removeFile) { file in
      ActivityShareSheet(items: [file.url]).ignoresSafeArea()
    }
  }

  private func export() async {
    guard let selectedId else { return }
    note = nil
    do {
      let log = try await convex.queryOnce(API.careExport.babyCareLog(selectedId))
      let now = Date().epochMs
      let tz = TimeZone.current
      let ext = format == .pdf ? "pdf" : "csv"
      let data = format == .pdf
        ? CareLogPDF.render(log, timeZone: tz, now: now)
        : Data(CareExport.csv(log, timeZone: tz, now: now).utf8)
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let url = folder.appendingPathComponent(CareExport.fileName(babyName: log.baby.name, now: now, timeZone: tz, ext: ext))
      try data.write(to: url, options: [.atomic, .completeFileProtection])
      if log.truncated {
        note = "This file has the first 10,000 entries. Contact us if you need the rest."
      }
      written = url
      file = ExportFile(url: url)
    } catch {
      alert = FormAlert(title: "Couldn't export", message: UserMessage.from(error, fallback: "Check your connection and try again."))
    }
  }

  private func removeFile() {
    if let written { try? FileManager.default.removeItem(at: written) }
    written = nil
  }
}

private struct ExportFile: Identifiable {
  let url: URL
  var id: String { url.path }
}

private struct FlowPills: View {
  let items: [Baby]
  let selected: BabyID?
  let onSelect: (BabyID) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(items) { baby in
          Pill(label: baby.name, selected: baby.id == selected) { onSelect(baby.id) }
        }
      }
      .padding(.vertical, 4)
    }
  }
}

/// A plain A4 care log: header, then each day's entries, newest day first.
enum CareLogPDF {
  static func render(_ log: CareLog, timeZone: TimeZone, now: EpochMs) -> Data {
    let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
    let margin: CGFloat = 42
    let width = page.width - margin * 2
    let footerHeight: CGFloat = 28
    let format = UIGraphicsPDFRendererFormat()
    format.documentInfo = [
      kCGPDFContextTitle as String: "\(log.baby.name) care log",
      kCGPDFContextCreator as String: "Scrunch",
    ]

    let ink = UIColor(C.ink)
    let muted = UIColor(C.muted)
    let accent = UIColor(C.tealDark)
    func font(_ name: String, _ size: CGFloat, bold: Bool = false) -> UIFont {
      UIFont(name: name, size: size) ?? (bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size))
    }
    let title = font(AppFont.displayBold.name, 24, bold: true)
    let heading = font(AppFont.bold.name, 12, bold: true)
    let body = font(AppFont.body.name, 10)
    let bodyBold = font(AppFont.bold.name, 10, bold: true)

    return UIGraphicsPDFRenderer(bounds: page, format: format).pdfData { context in
      var y: CGFloat = 0
      var pageNumber = 0

      func attributed(_ text: String, _ font: UIFont, _ color: UIColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
      }
      func height(_ text: NSAttributedString, _ width: CGFloat) -> CGFloat {
        ceil(text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).height)
      }
      @discardableResult
      func draw(_ text: NSAttributedString, x: CGFloat, width: CGFloat) -> CGFloat {
        let h = height(text, width)
        text.draw(with: CGRect(x: x, y: y, width: width, height: h), options: [.usesLineFragmentOrigin], context: nil)
        return h
      }
      func newPage() {
        context.beginPage()
        pageNumber += 1
        y = page.height - margin
        let footer = attributed("\(CareExport.pdfFootnote)   Page \(pageNumber)", body, muted)
        draw(footer, x: margin, width: width)
        y = margin
      }
      func ensure(_ needed: CGFloat) {
        if y + needed > page.height - margin - footerHeight { newPage() }
      }

      newPage()
      y += draw(attributed("\(log.baby.name) — care log", title, ink), x: margin, width: width) + 4
      y += draw(attributed(CareExport.subtitle(log, timeZone: timeZone, now: now), body, muted), x: margin, width: width) + 18

      let days = CareExport.days(log, timeZone: timeZone, now: now)
      if days.isEmpty {
        draw(attributed("Nothing logged yet.", body, ink), x: margin, width: width)
      }
      let timeWidth: CGFloat = 40
      let typeWidth: CGFloat = 80
      let detailX = margin + timeWidth + typeWidth
      let detailWidth = width - timeWidth - typeWidth

      for day in days {
        ensure(40)
        y += draw(attributed(day.heading, heading, accent), x: margin, width: width) + 6
        for row in day.rows {
          let details = NSMutableAttributedString(attributedString: attributed(row.details, body, ink))
          if !row.note.isEmpty {
            details.append(attributed("\n\(row.note)", body, muted))
          }
          let rowHeight = max(height(details, detailWidth), 14)
          ensure(rowHeight + 4)
          draw(attributed(row.time, bodyBold, ink), x: margin, width: timeWidth)
          draw(attributed(row.type, body, ink), x: margin + timeWidth, width: typeWidth)
          draw(details, x: detailX, width: detailWidth)
          y += rowHeight + 4
        }
        y += 10
      }
    }
  }
}

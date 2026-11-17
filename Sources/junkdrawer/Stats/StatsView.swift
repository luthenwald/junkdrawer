import AppKit
import JunkdrawerCore
import SwiftUI
import UniformTypeIdentifiers
import os

/// The statistics: a punch card of uses per kind over time, the most used
/// items under it, and the export.
struct StatsView: View {
   let store: StatsStore
   @State private var span = Span.month

   private static let kinds: [Kind] = [.app, .bookmark, .file, .command, .setting, .latex, .unicode, .dictionary]
   private static let topLimit = 8
   private static let text = Color(nsColor: .text)
   private static let secondary = Color(nsColor: .secondary)
   private static let line = Color(nsColor: .line)

   var body: some View {
      let stats = store.stats
      VStack(alignment: .leading, spacing: 0) {
         Picker("Span", selection: $span) {
            ForEach(Span.allCases, id: \.self) { Text($0.rawValue) }
         }
         .pickerStyle(.segmented)
         .labelsHidden()
         .frame(width: 260)
         .frame(maxWidth: .infinity)
         .padding(.bottom, 22)

         PunchCard(stats: stats, columns: span.columns(first: stats.firstDay, today: Date()), kinds: Self.kinds)

         Rectangle().fill(Self.line).frame(height: 1).padding(.vertical, 18)

         Text("Most used, all time")
            .font(.system(size: 12))
            .foregroundStyle(Self.secondary)
            .padding(.bottom, 8)
         let top = stats.top(Self.topLimit)
         if top.isEmpty {
            Text("Nothing counted yet").foregroundStyle(Self.secondary).frame(height: 26)
         }
         ForEach(top, id: \.id) { entry in
            let kind = Kind(id: entry.id)
            HStack(spacing: 14) {
               Text(Stats.label(for: entry.id))
                  .font(.system(size: 13, design: kind == .latex ? .monospaced : .default))
                  .foregroundStyle(Self.text)
                  .lineLimit(1)
                  .truncationMode(.middle)
                  .frame(width: 210, alignment: .leading)
               Text(kind?.plural ?? "")
                  .font(.system(size: 12))
                  .foregroundStyle(Self.secondary)
                  .frame(width: 70, alignment: .leading)
               GeometryReader { area in
                  Rectangle()
                     .fill(Self.text)
                     .frame(width: max(1, area.size.width * CGFloat(entry.count) / CGFloat(max(top[0].count, 1))), height: 1)
                     .frame(maxHeight: .infinity, alignment: .center)
               }
               Text("\(entry.count)")
                  .font(.system(size: 13).monospacedDigit())
                  .foregroundStyle(Self.text)
                  .frame(width: 44, alignment: .trailing)
            }
            .frame(height: 26)
         }

         HStack {
            if let first = stats.firstDay.flatMap(Span.date) {
               Text("Counted since \(first.formatted(.dateTime.day().month(.wide).year()))")
                  .font(.system(size: 12))
                  .foregroundStyle(Self.secondary)
            }
            Spacer()
            Menu("Export…") {
               Button("JSON, everything…") { export("json", .json) { try StatsStore.encoded(stats) } }
               Button("CSV, the daily counts…") { export("csv", .commaSeparatedText) { Data(stats.csv.utf8) } }
            }
            .fixedSize()
         }
         .padding(.top, 20)
      }
      .padding(28)
      .frame(width: 660)
      .background(Color(nsColor: .background))
      // Grayscale, as the panel is.
      .tint(.gray)
   }

   private func export(_ ending: String, _ type: UTType, _ data: () throws -> Data) {
      let panel = NSSavePanel()
      panel.allowedContentTypes = [type]
      panel.nameFieldStringValue = "junkdrawer-stats.\(ending)"
      guard panel.runModal() == .OK, let file = panel.url else { return }
      do {
         try data().write(to: file, options: .atomic)
      } catch {
         Logger.app.error("exporting the statistics failed: \(error.localizedDescription, privacy: .public)")
      }
   }
}

/// How much time the punch card covers.
enum Span: String, CaseIterable {
   case month = "30 days"
   case quarter = "12 weeks"
   case all = "All"

   /// One column of the card: the days it sums and a label for the axis.
   struct Column {
      let days: [String]
      let label: String
   }

   private static let dayStyle = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()

   static func date(_ day: String) -> Date? {
      try? Date(day, strategy: dayStyle)
   }

   /// Oldest first, ending today. Everything is drawn by day while it is
   /// short, then by week, then by month.
   func columns(first: String?, today: Date, calendar: Calendar = .current) -> [Column] {
      let back = { (days: Int) in calendar.date(byAdding: .day, value: -days, to: today) ?? today }
      let daily = { (count: Int) in
         (0..<count).reversed().map { Column(days: [back($0).statsDay], label: back($0).formatted(.dateTime.day().month(.abbreviated))) }
      }
      let weekly = { (count: Int) in
         (0..<count).reversed().map { week in
            Column(
               days: (0..<7).map { back(week * 7 + 6 - $0).statsDay },
               label: back(week * 7 + 6).formatted(.dateTime.day().month(.abbreviated))
            )
         }
      }
      switch self {
      case .month: return daily(30)
      case .quarter: return weekly(12)
      case .all:
         let start = first.flatMap(Self.date) ?? today
         let length = (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: today)).day ?? 0) + 1
         if length <= 42 { return daily(max(length, 14)) }
         if length <= 364 { return weekly((length + 6) / 7) }
         let month = { (date: Date) in calendar.dateInterval(of: .month, for: date)?.start ?? date }
         let months = (calendar.dateComponents([.month], from: month(start), to: month(today)).month ?? 0) + 1
         return (0..<months).reversed().compactMap { ago in
            guard let month = calendar.date(byAdding: .month, value: -ago, to: today),
                  let interval = calendar.dateInterval(of: .month, for: month),
                  let count = calendar.range(of: .day, in: .month, for: month)?.count else { return nil }
            let days = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start)?.statsDay }
            return Column(days: days, label: interval.start.formatted(.dateTime.month(.abbreviated).year()))
         }
      }
   }
}

/// One line per kind, one dot per column, the dot's area following the
/// count. A column without uses keeps a faint point, so the grid reads as
/// time passing.
private struct PunchCard: View {
   let stats: Stats
   let columns: [Span.Column]
   let kinds: [Kind]

   private static let rowHeight: CGFloat = 36
   private static let axisHeight: CGFloat = 26
   private static let nameWidth: CGFloat = 86
   private static let totalWidth: CGFloat = 52
   private static let largest: CGFloat = 13

   var body: some View {
      let counts = kinds.map { kind in columns.map { stats.count(kind, over: $0.days) } }
      let peak = max(counts.joined().max() ?? 0, 1)
      Canvas { context, size in
         let text = Color(nsColor: .text), secondary = Color(nsColor: .secondary), line = Color(nsColor: .line)
         let step = (size.width - Self.nameWidth - Self.totalWidth) / CGFloat(max(columns.count, 1))
         let radius = min(Self.largest, step / 2 - 1)
         for (row, kind) in kinds.enumerated() {
            let y = (CGFloat(row) + 0.5) * Self.rowHeight
            if row > 0 {
               let rule = CGRect(x: 0, y: CGFloat(row) * Self.rowHeight, width: size.width, height: 1)
               context.fill(Path(rule), with: .color(line.opacity(0.6)))
            }
            context.draw(Text(kind.plural).font(.system(size: 13)).foregroundStyle(secondary), at: CGPoint(x: 0, y: y), anchor: .leading)
            let total = counts[row].reduce(0, +)
            context.draw(
               Text("\(total)").font(.system(size: 13).monospacedDigit()).foregroundStyle(total == 0 ? secondary : text),
               at: CGPoint(x: size.width, y: y), anchor: .trailing
            )
            for (column, count) in counts[row].enumerated() {
               let x = Self.nameWidth + (CGFloat(column) + 0.5) * step
               let r = count == 0 ? 1 : max(1.75, radius * (CGFloat(count) / CGFloat(peak)).squareRoot())
               context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(count == 0 ? line : text))
            }
         }
         // The first, the middle and the last column carry their dates.
         let y = CGFloat(kinds.count) * Self.rowHeight + Self.axisHeight / 2 + 4
         for column in Set([0, columns.count / 2, columns.count - 1]) where columns.indices.contains(column) {
            let x = Self.nameWidth + (CGFloat(column) + 0.5) * step
            let anchor: UnitPoint = column == 0 ? .leading : column == columns.count - 1 ? .trailing : .center
            let edge = column == 0 ? x - step / 2 + 2 : column == columns.count - 1 ? x + step / 2 - 2 : x
            context.draw(Text(columns[column].label).font(.system(size: 12)).foregroundStyle(secondary), at: CGPoint(x: edge, y: y), anchor: anchor)
         }
      }
      .frame(height: CGFloat(kinds.count) * Self.rowHeight + Self.axisHeight)
   }
}

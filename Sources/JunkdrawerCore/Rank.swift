import Foundation

/// Everything the list can search, as loaded by the shell.
public struct Index: Sendable {
   /// Apps, bookmarks and commands, for the plain mode.
   public var items: [Item]
   public var symbols: Symbols

   public init(items: [Item] = [], symbols: Symbols = Symbols()) {
      self.items = items
      self.symbols = symbols
   }
}

/// How many recent picks an empty query lists.
public let recentLimit = 12

/// The rows for a query, best first. An empty query lists recent picks;
/// the dictionary comes with a later milestone.
public func rows(for query: Query, in index: Index, usage: Usage, now: Date) -> [Row] {
   switch query.mode {
   case .plain where query.text.isEmpty:
      recentRows(in: index, usage: usage)
   case .plain:
      plainRows(query.text, in: index.items, usage: usage, now: now)
   case .latex where !query.text.isEmpty:
      latexRows(query.text, in: index.symbols, usage: usage, now: now)
   case .unicode where !query.text.isEmpty:
      unicodeRows(query.text, in: index.symbols, usage: usage, now: now)
   case .latex, .unicode, .dictionary:
      []
   }
}

/// The recent picks that are still in the index, the latest first.
private func recentRows(in index: Index, usage: Usage) -> [Row] {
   let byID = Dictionary(index.items.map { ($0.id, $0) }) { first, _ in first }
   return usage.recent(limit: recentLimit)
      .compactMap { byID[$0] ?? index.symbols.item(id: $0) }
      .map { Row(item: $0, matched: [], score: 0) }
}

/// The better of the title match and 0.6 times the keywords match, apps a
/// little ahead of bookmarks, plus the frecency bonus. Ties sort by title.
private func plainRows(_ text: String, in items: [Item], usage: Usage, now: Date) -> [Row] {
   items
      .compactMap { item -> Row? in
         let title = match(text, in: item.title)
         let keywords = item.keywords.isEmpty ? nil : match(text, in: item.keywords).map { 0.6 * $0.score }
         let best: (score: Double, indices: [Int])? = switch (title, keywords) {
         case let (title?, keywords?) where keywords > title.score: (keywords, [])
         case let (title?, _): (title.score, title.indices)
         case let (nil, keywords?): (keywords, [])
         case (nil, nil): nil
         }
         let extra = (item.kind == .app ? 5 : 0) + usage.bonus(for: item.id, now: now)
         return best.map { Row(item: item, matched: $0.indices, score: $0.score + extra) }
      }
      .sorted { a, b in
         a.score != b.score ? a.score > b.score : a.item.title.localizedStandardCompare(b.item.title) == .orderedAscending
      }
}

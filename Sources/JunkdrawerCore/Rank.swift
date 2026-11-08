import Foundation

/// Everything the list can search, as loaded by the shell.
public struct Index: Sendable {
   public var items: [Item]

   public init(items: [Item] = []) {
      self.items = items
   }
}

/// The rows for a query, best first. Only the plain mode searches so far;
/// the recent list, symbols and the dictionary come with later milestones.
public func rows(for query: Query, in index: Index) -> [Row] {
   switch query.mode {
   case .plain where !query.text.isEmpty:
      plainRows(query.text, in: index.items)
   case .plain, .latex, .unicode, .dictionary:
      []
   }
}

/// The better of the title match and 0.6 times the keywords match, and apps
/// a little ahead of bookmarks. Ties sort by title.
private func plainRows(_ text: String, in items: [Item]) -> [Row] {
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
         return best.map { Row(item: item, matched: $0.indices, score: $0.score + (item.kind == .app ? 5 : 0)) }
      }
      .sorted { a, b in
         a.score != b.score ? a.score > b.score : a.item.title.localizedStandardCompare(b.item.title) == .orderedAscending
      }
}

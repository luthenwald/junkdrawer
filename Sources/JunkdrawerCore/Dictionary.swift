import Foundation

/// A definition the shell found for a query, raw.
public struct Lookup: Hashable, Sendable {
   /// Where the word came from, which orders the rows.
   public enum Source: Hashable, Sendable {
      /// The query itself, as typed.
      case query
      /// A spell-checker completion of the query.
      case completion
      /// A spell-checker guess, when nothing else matched.
      case guess
   }

   public let word: String
   /// The text of `DCSCopyTextDefinition`.
   public let text: String
   public let source: Source

   public init(word: String, text: String, source: Source) {
      self.word = word
      self.text = text
      self.source = source
   }
}

/// The rows for `?query` from what the shell looked up, with each row's
/// definition by item id for the pane. The query's own entry comes first
/// when its headword is related to the query, then the completions'
/// entries in the spell checker's order, which puts common words first
/// (`eph` gives ephemeral before ephyra), then an unrelated own entry
/// (Dictionary Services matches loosely, so `th` finds "-eth"), then
/// guesses by edit distance. Each headword appears once, so "ephemerals"
/// adds nothing to "ephemeral".
public func dictionaryRows(_ query: String, _ lookups: [Lookup]) -> (rows: [Row], definitions: [String: Definition]) {
   let parsed = lookups.enumerated().map { position, lookup in
      let found = definition(from: lookup.text)
      return (position: position, source: lookup.source, definition: found.isParsed ? found : found.named(lookup.word))
   }
   let lowered = query.lowercased()
   let rank = { (entry: (position: Int, source: Lookup.Source, definition: Definition)) -> (Int, Int, Int) in
      switch entry.source {
      case .query where related(query, entry.definition.headword): (0, 0, entry.position)
      case .completion: (1, 0, entry.position)
      case .query: (2, 0, entry.position)
      case .guess: (3, editDistance(lowered, entry.definition.headword.lowercased()), entry.position)
      }
   }
   var seen = Set<String>()
   let entries = parsed
      .sorted { rank($0) < rank($1) }
      .filter { seen.insert($0.definition.headword.lowercased()).inserted }
   let rows = entries.map { entry in
      let found = entry.definition
      let item = Item(
         id: "dict:\(found.headword)",
         kind: .dictionary,
         title: found.headword,
         subtitle: entry.source == .guess ? "did you mean · \(found.summary)" : found.summary,
         trailing: "",
         primary: .openDefinition(found.headword),
         secondary: .copy(found.headword),
         tertiary: .copy(found.plainText)
      )
      let matched = found.headword.lowercased().hasPrefix(lowered) ? Array(0..<query.count) : []
      return Row(item: item, matched: matched, score: 0)
   }
   let definitions = Dictionary(entries.map { ("dict:\($0.definition.headword)", $0.definition) }) { first, _ in first }
   return (rows, definitions)
}

/// The last row of a plain query that is one word of three or more
/// letters: it switches to the dictionary mode for that word.
func defineRow(_ text: String) -> Row? {
   guard text.count >= 3, let first = text.first, first.isASCII, first.isLetter,
         text.allSatisfy({ $0.isASCII && ($0.isLetter || $0 == "-") })
   else { return nil }
   let lookUp = Action.setQuery("?" + text)
   let item = Item(
      id: "define:\(text)",
      kind: .dictionary,
      title: "Define “\(text)”",
      subtitle: "look up in the macOS dictionary",
      trailing: "?",
      primary: lookUp,
      secondary: lookUp
   )
   return Row(item: item, matched: [], score: 0)
}

/// True when one word's letters start the other's, ignoring case: "launched"
/// and "launch", "Bach" and "Bach, Johann Sebastian", "set off" and
/// "set-off".
private func related(_ query: String, _ headword: String) -> Bool {
   let letters = { (text: String) in text.lowercased().filter(\.isLetter) }
   let (a, b) = (letters(query), letters(headword))
   return !a.isEmpty && !b.isEmpty && (a.hasPrefix(b) || b.hasPrefix(a))
}

/// The Levenshtein distance between two words, by characters.
private func editDistance(_ a: String, _ b: String) -> Int {
   let a = Array(a), b = Array(b)
   var previous = Array(0...b.count)
   for i in a.indices {
      var current = [i + 1]
      for j in b.indices {
         current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (a[i] == b[j] ? 0 : 1)))
      }
      previous = current
   }
   return previous[b.count]
}

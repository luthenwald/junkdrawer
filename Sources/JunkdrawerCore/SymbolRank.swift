import Foundation

/// How many rows the symbol modes return at most. A short query matches
/// most of the table, and building rows nobody scrolls to costs the frame.
public let symbolRowLimit = 1000

/// Unicode mode: every word of the query must match. A word in the name
/// scores 50, or 80 at a word start, and so does a LaTeX command name equal
/// to it; an alias holding it, or a keyword or command starting with it,
/// scores 35. A query that is one character puts that character first.
func unicodeRows(_ text: String, in symbols: Symbols, usage: Usage, now: Date) -> [Row] {
   let words = queryWords(text)
   let pinned = text.count == 1 ? Set(symbols.byString[text] ?? []) : []
   let scored = symbols.unicodeKeys.indices.compactMap { index -> (index: Int, score: Double)? in
      let found = wordScore(words, symbols.unicodeKeys[index])
      guard pinned.contains(index) || found != nil else { return nil }
      return (index, (pinned.contains(index) ? 1000 : 0) + (found ?? 0))
   }
   return ranked(scored, items: symbols.unicode, order: { symbols.unicodeKeys[$0].order }, positions: symbols.unicodeIndex, usage: usage, now: now) {
      let key = symbols.unicodeKeys[$0]
      return characterOffsets(nameMarks(words, key), in: key)
   }
}

/// LaTeX mode, on the command without its backslash: exact 1000, exact
/// ignoring case 950, prefix 800 minus the extra length, prefix ignoring
/// case 750, then the fuzzy match, then half the Unicode score of the name.
/// Each character appears once, under its best-matching command, so
/// `\lambda` hides `\uplambda` and `\lambdaup` while `\to` still finds →.
func latexRows(_ text: String, in symbols: Symbols, usage: Usage, now: Date) -> [Row] {
   let typed = Array(text.utf8)
   let lowered = Array(text.lowercased().utf8)
   let needle = folded(text)
   let words = queryWords(text)
   let all = Array(1..<(1 + text.count))
   let scored = symbols.latexKeys.indices.compactMap { index -> (index: Int, score: Double, marks: [Int])? in
      let key = symbols.latexKeys[index]
      if key.command == typed { return (index, 1000, all) }
      if key.lowered == lowered { return (index, 950, all) }
      if key.command.starts(with: typed) { return (index, 800 - Double(key.command.count - typed.count), all) }
      if key.lowered.starts(with: lowered) { return (index, 750, all) }
      if let found = match(needle, in: key.folded) { return (index, found.score, found.indices.map { $0 + 1 }) }
      if let found = wordScore(words, symbols.unicodeKeys[key.symbol]) { return (index, found / 2, []) }
      return nil
   }
   let marks = Dictionary(scored.map { ($0.index, $0.marks) }) { a, _ in a }
   return ranked(scored.map { ($0.index, $0.score) }, items: symbols.latex, order: { symbols.latexKeys[$0].order }, positions: symbols.latexIndex, usage: usage, now: now, group: { symbols.latexKeys[$0].symbol }) {
      marks[$0] ?? []
   }
}

/// Adds the frecency bonus, sorts best first with ties in title order, and
/// builds the first `symbolRowLimit` rows. The bonus is looked up for the
/// picked ids only, since a short query matches most of the table. With a
/// `group`, only the best of each group stays, ties going to the lower
/// index, which for LaTeX is the more standard command.
private func ranked(
   _ scored: [(index: Int, score: Double)], items: [Item], order: (Int) -> Int,
   positions: [String: Int], usage: Usage, now: Date, group: ((Int) -> Int)? = nil, matched: (Int) -> [Int]
) -> [Row] {
   let bonus = Dictionary(usage.picks.keys.compactMap { id in positions[id].map { ($0, usage.bonus(for: id, now: now)) } }) { a, _ in a }
   let keyed: [Keyed] = scored.map { (index: $0.index, score: $0.score + (bonus[$0.index] ?? 0), order: order($0.index)) }
   let kept = group.map { bestOfEach(keyed, by: $0) } ?? keyed
   return kept
      .sorted { a, b in a.score != b.score ? a.score > b.score : a.order < b.order }
      .prefix(symbolRowLimit)
      .map { Row(item: items[$0.index], matched: matched($0.index), score: $0.score) }
}

private typealias Keyed = (index: Int, score: Double, order: Int)

private func bestOfEach(_ keyed: [Keyed], by group: (Int) -> Int) -> [Keyed] {
   let best = Dictionary(keyed.map { (group($0.index), $0) }) { (a: Keyed, b: Keyed) -> Keyed in
      if a.score != b.score { return a.score > b.score ? a : b }
      return a.index < b.index ? a : b
   }
   return Array(best.values)
}

private func queryWords(_ text: String) -> [[UInt8]] {
   text.lowercased().split(separator: " ").map { Array($0.utf8) }
}

/// The summed score of all words, or nil when a word matches nothing.
private func wordScore(_ words: [[UInt8]], _ key: UnicodeKey) -> Double? {
   guard !words.isEmpty else { return nil }
   var score: Double = 0
   for word in words {
      if let hit = find(word, in: key.name) {
         score += hit.atBoundary ? 80 : 50
      } else if key.commands.contains(word) {
         score += 80
      } else if find(word, in: key.aliases) != nil
         || key.keywords.contains(where: { $0.starts(with: word) })
         || key.commands.contains(where: { $0.starts(with: word) }) {
         score += 35
      } else {
         return nil
      }
   }
   return score
}

/// The byte ranges the words matched in the name, for the rows shown.
private func nameMarks(_ words: [[UInt8]], _ key: UnicodeKey) -> [Range<Int>] {
   words.compactMap { word in find(word, in: key.name).map { $0.offset..<$0.offset + word.count } }
}

/// Bytes after which a word starts: space, "-", "_", ".", "/", "{", "\",
/// ":", "(", "," and the "|" between aliases.
private let boundaryBytes: [Bool] = (0..<256).map { byte in
   " -_./{\\:(,|".utf8.contains(UInt8(byte))
}

/// The first occurrence at a word start, or else the first occurrence.
private func find(_ needle: [UInt8], in hay: [UInt8]) -> (offset: Int, atBoundary: Bool)? {
   guard !needle.isEmpty, needle.count <= hay.count else { return nil }
   return hay.withUnsafeBufferPointer { hay in
      needle.withUnsafeBufferPointer { needle in
         var first: Int?
         let lead = needle[0]
         for start in 0...(hay.count - needle.count) where hay[start] == lead {
            guard (1..<needle.count).allSatisfy({ hay[start + $0] == needle[$0] }) else { continue }
            if start == 0 || boundaryBytes[Int(hay[start - 1])] { return (start, true) }
            if first == nil { first = start }
         }
         return first.map { ($0, false) }
      }
   }
}

/// Byte ranges in the name as character offsets in the title.
private func characterOffsets(_ marks: [Range<Int>], in key: UnicodeKey) -> [Int] {
   guard !key.isASCII else { return marks.flatMap { Array($0) } }
   let offset = { (byte: Int) in String(decoding: key.name[..<byte], as: UTF8.self).count }
   return marks.flatMap { Array(offset($0.lowerBound)..<offset($0.upperBound)) }
}

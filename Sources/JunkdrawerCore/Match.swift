/// How well a query matches a text, and which characters of the text it
/// matched, as character offsets.
public struct Match: Hashable, Sendable {
   public let score: Double
   public let indices: [Int]
}

/// Matches `query` against `text`, ignoring case. A contiguous substring
/// beats a subsequence; a text that does not hold the query's characters in
/// order gives nil, and so does an empty query.
public func match(_ query: String, in text: String) -> Match? {
   match(folded(query), in: folded(text))
}

/// The same on texts folded by `folded(_:)`, for keys folded once.
func match(_ needle: [Character], in hay: [Character]) -> Match? {
   guard !needle.isEmpty else { return nil }
   return substring(needle, in: hay) ?? subsequence(needle.filter { $0 != " " }, in: hay)
}

/// Each character lowercased on its own, so offsets stay offsets in the
/// original text.
func folded(_ text: String) -> [Character] {
   text.map { $0.lowercased().first ?? $0 }
}

private let boundaries: Set<Character> = [" ", "-", "_", ".", "/", "{", "\\"]

private func isBoundary(_ text: [Character], at index: Int) -> Bool {
   index == 0 || boundaries.contains(text[index - 1])
}

/// 100 plus 10 per character, minus the start offset, with bonuses for the
/// start of the text, a word boundary and an exact match.
private func substring(_ needle: [Character], in hay: [Character]) -> Match? {
   guard needle.count <= hay.count,
         let start = (0...(hay.count - needle.count)).first(where: { hay[$0..<$0 + needle.count].elementsEqual(needle) })
   else { return nil }
   let position: Double = start == 0 ? 50 : isBoundary(hay, at: start) ? 30 : 0
   let exact: Double = hay.count == needle.count ? 40 : 0
   let score = 100 + 10 * Double(needle.count) - Double(start) + position + exact
   return Match(score: score, indices: Array(start..<start + needle.count))
}

/// 10 per character, plus 15 when it follows the previous match and 20 at
/// a word boundary, minus the gap before it (at most 10).
private func subsequence(_ needle: [Character], in hay: [Character]) -> Match? {
   guard !needle.isEmpty else { return nil }
   var indices: [Int] = []
   var score: Double = 0
   var from = 0
   for character in needle {
      guard let found = hay[from...].firstIndex(of: character) else { return nil }
      score += 10
      if found == (indices.last ?? -2) + 1 { score += 15 }
      if isBoundary(hay, at: found) { score += 20 }
      score -= Double(min(found - from, 10))
      indices.append(found)
      from = found + 1
   }
   return Match(score: score, indices: indices)
}

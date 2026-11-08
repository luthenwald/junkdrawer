import Foundation

/// A dictionary entry as the pane shows it: the headword, its
/// pronunciation, and per part of speech the numbered senses with their
/// first example. Sub-senses, phrases, derivatives and the origin stay in
/// Dictionary.app.
public struct Definition: Hashable, Sendable {
   public struct Sense: Hashable, Sendable {
      public let text: String
      public let example: String?
   }

   public struct Block: Hashable, Sendable {
      /// Nil for entries without one, such as names.
      public let partOfSpeech: String?
      public let senses: [Sense]
   }

   public let headword: String
   public let pronunciation: String?
   public let blocks: [Block]
   /// The text as Dictionary Services returned it.
   public let raw: String
   /// False when the text did not have the expected shape; the pane then
   /// shows the raw text.
   public let isParsed: Bool

   /// The first sense after its part of speech, for the row's subtitle.
   public var summary: String {
      let first = blocks.first
      let sense = first?.senses.first?.text ?? ""
      return first?.partOfSpeech.map { "\($0) · \(sense)" } ?? sense
   }

   /// What ⌘↵ copies: the headword and pronunciation, then each part of
   /// speech with its numbered senses and examples, one per line.
   public var plainText: String {
      guard isParsed else { return raw }
      let head = [headword] + (pronunciation.map { ["/\($0)/"] } ?? [])
      let blocks = blocks.map { block in
         let senses = block.senses.enumerated().map { number, sense in
            "\(number + 1). \(sense.text)" + (sense.example.map { "\n   \($0)" } ?? "")
         }
         return ((block.partOfSpeech.map { [$0] } ?? []) + senses).joined(separator: "\n")
      }
      return ([head.joined(separator: " ")] + blocks).joined(separator: "\n\n")
   }

   /// The same entry under another headword, for raw text that has none.
   func named(_ word: String) -> Definition {
      Definition(headword: word, pronunciation: pronunciation, blocks: blocks, raw: raw, isParsed: isParsed)
   }
}

/// Parses the plain text of `DCSCopyTextDefinition`, which reads like
/// `launch 1 | lɔːn(t)ʃ | verb [with object] 1 set (a boat) in motion …:
/// the town's lifeboat was launched … • send (a missile …) … 2 start or set
/// in motion … noun an act or instance of launching something … ORIGIN …`.
/// Text of another shape comes back unparsed, with no headword. It scans
/// the UTF-8 bytes once: an entry such as "run" has 21,000 characters, and
/// string searches took 17 ms on it.
public func definition(from text: String) -> Definition {
   let bytes = Array(text.utf8)
   let unparsed = Definition(headword: "", pronunciation: nil, blocks: [.init(partOfSpeech: nil, senses: [.init(text: text, example: nil)])], raw: text, isParsed: false)
   guard let first = find(bar, in: bytes, from: 0, to: bytes.count),
         let second = find(bar, in: bytes, from: first + bar.count, to: bytes.count)
   else { return unparsed }
   let (headword, named) = headword(string(bytes, 0..<first))
   let body = (second + bar.count)..<sectionStart(bytes, from: second + bar.count)
   let blocks = blockRanges(bytes, body, named: named).compactMap { pos, range in
      // A name's text is all definition; its colons are no examples.
      let senses = senseRanges(bytes, range).compactMap { range in
         sense(string(bytes, range.lowerBound..<(find(bullet, in: bytes, from: range.lowerBound, to: range.upperBound) ?? range.upperBound))[...], splitsExample: pos != nil)
      }
      return senses.isEmpty ? nil : Definition.Block(partOfSpeech: pos, senses: senses)
   }
   guard !headword.isEmpty, !blocks.isEmpty else { return unparsed }
   let pronunciation = string(bytes, (first + bar.count)..<second).trimmingCharacters(in: .whitespaces)
   return Definition(headword: headword, pronunciation: pronunciation.isEmpty ? nil : pronunciation, blocks: blocks, raw: text, isParsed: true)
}

private let bar = Array(" | ".utf8)
/// Starts a sub-sense, which the pane leaves out.
private let bullet = Array(" • ".utf8)
private let space = UInt8(ascii: " ")

/// The headword without a homograph number, as in "launch 1", and without
/// a part of speech, as in "rundown noun", which is returned beside it.
private func headword(_ text: String) -> (String, String?) {
   var text = text
   if let last = text.lastIndex(of: " "), text[text.index(after: last)...].allSatisfy(\.isNumber), text.index(after: last) < text.endIndex {
      text = String(text[..<last])
   }
   guard let named = partOfSpeechNames.first(where: { text.hasSuffix(" " + $0) }) else { return (text, nil) }
   return (String(text.dropLast(named.count + 1)), named)
}

/// The words that start a section after the senses, with their space.
private let sections = [
   "PHRASES", "PHRASAL VERBS", "DERIVATIVES", "ORIGIN", "USAGE", "WORD LINKS", "NOTE", "SYNONYMS",
   "ANTONYMS", "GRAMMAR", "PRONUNCIATION", "WORD TRIVIA",
].map { Array(" \($0)".utf8) }

/// Where the first section starts, or the end.
private func sectionStart(_ bytes: [UInt8], from: Int) -> Int {
   sections.compactMap { word in
      var search = from
      while let at = find(word, in: bytes, from: search, to: bytes.count) {
         if at + word.count == bytes.count || bytes[at + word.count] == space { return at }
         search = at + 1
      }
      return nil
   }.min() ?? bytes.count
}

/// Parts of speech, longest first so "plural noun" wins over "noun".
private let partOfSpeechNames = [
   "plural noun", "proper noun", "noun", "modal verb", "auxiliary verb", "phrasal verb", "verb",
   "adjective", "adverb", "pronoun", "preposition", "conjunction", "predeterminer", "determiner",
   "exclamation", "interjection", "abbreviation", "prefix", "suffix", "combining form", "symbol",
   "cardinal number", "ordinal number", "number", "contraction",
]
private let partOfSpeechBytes = partOfSpeechNames.map { Array($0.utf8) }

/// The body split at its parts of speech: one starts the body, or follows
/// the end of a sentence or a parenthesis, and is a whole word. Text before
/// the first is dropped, unless the headword named one; a body without any
/// is one block.
private func blockRanges(_ bytes: [UInt8], _ body: Range<Int>, named: String?) -> [(String?, Range<Int>)] {
   let name = { (at: Int) -> (String, Int)? in
      partOfSpeechBytes.indices.lazy.compactMap { index -> (String, Int)? in
         let word = partOfSpeechBytes[index], end = at + word.count
         guard end <= body.upperBound, bytes[at..<end].elementsEqual(word), end == body.upperBound || bytes[end] == space else { return nil }
         return (partOfSpeechNames[index], end)
      }.first
   }
   var marks: [(name: String, start: Int, end: Int)] = []
   if let (found, end) = name(body.lowerBound) {
      marks.append((found, body.lowerBound, end))
   } else if let (at, found, end) = afterLabel(bytes, body, name) {
      marks.append((found, at, end))
   }
   let dot = UInt8(ascii: "."), close = UInt8(ascii: ")")
   for at in body.lowerBound..<max(body.lowerBound, body.upperBound - 2) where (bytes[at] == dot || bytes[at] == close) && bytes[at + 1] == space {
      if let (found, end) = name(at + 2) { marks.append((found, at, end)) }
   }
   let lead: [(String?, Range<Int>)] = named.map { [($0, body.lowerBound..<(marks.first?.start ?? body.upperBound))] } ?? []
   guard !marks.isEmpty else { return lead.isEmpty ? [(nil, body)] : lead }
   return lead + marks.indices.map { index in
      (marks[index].name, marks[index].end..<(index + 1 < marks.count ? marks[index + 1].start : body.upperBound))
   }
}

/// A part of speech after a short label of letters at the body start, as
/// in "informal noun".
private func afterLabel(_ bytes: [UInt8], _ body: Range<Int>, _ name: (Int) -> (String, Int)?) -> (Int, String, Int)? {
   let limit = min(body.upperBound, body.lowerBound + 32)
   for at in body.lowerBound..<limit {
      let byte = bytes[at]
      if byte == space, let (found, end) = name(at + 1) { return (at, found, end) }
      guard byte == space || (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte) else { return nil }
   }
   return nil
}

/// The senses numbered 1, 2, … in a block, or the whole block when it has
/// no numbers. A number counts at the start, or after a full stop, colon,
/// bracket or parenthesis and a space, so "in 1843 by" is no sense; the
/// first may also follow a short label such as "North American English".
private func senseRanges(_ bytes: [UInt8], _ block: Range<Int>) -> [Range<Int>] {
   var markers: [(start: Int, text: Int)] = []
   var from = block.lowerBound
   while let at = senseMarker(markers.count + 1, bytes, block, from: from) {
      markers.append((at, at + "\(markers.count + 1) ".utf8.count))
      from = markers[markers.count - 1].text
   }
   guard !markers.isEmpty else { return [block] }
   return markers.indices.map { index in
      markers[index].text..<(index + 1 < markers.count ? markers[index + 1].start : block.upperBound)
   }
}

private func senseMarker(_ number: Int, _ bytes: [UInt8], _ block: Range<Int>, from: Int) -> Int? {
   let needle = Array("\(number) ".utf8)
   let marks = Array(".:])|".utf8)
   var search = from
   while let at = find(needle, in: bytes, from: search, to: block.upperBound) {
      let before = bytes[block.lowerBound..<at]
      if before.allSatisfy({ $0 == space }) { return at }
      if bytes[at - 1] == space {
         if at - 2 >= block.lowerBound, marks.contains(bytes[at - 2]) { return at }
         if number == 1, before.count <= 40, !before.contains(where: { (0x30...0x39).contains($0) }) { return at }
      }
      search = at + 1
   }
   return nil
}

/// The first occurrence of `needle` in `hay[from..<to]`.
private func find(_ needle: [UInt8], in hay: [UInt8], from: Int, to: Int) -> Int? {
   guard !needle.isEmpty, to - from >= needle.count else { return nil }
   let lead = needle[0]
   for start in from...(to - needle.count) where hay[start] == lead {
      if (1..<needle.count).allSatisfy({ hay[start + $0] == needle[$0] }) { return start }
   }
   return nil
}

private func string(_ bytes: [UInt8], _ range: Range<Int>) -> String {
   String(decoding: bytes[range], as: UTF8.self)
}

/// The sense up to its first sub-sense, without leading grammar labels such
/// as "[with object]" or inflections such as "(plural ephyrae | ˈɛfɪriː |)",
/// split into the definition and its first example.
private func sense(_ text: Substring, splitsExample: Bool) -> Definition.Sense? {
   var text = text.trimmingCharacters(in: .whitespaces)[...]
   while true {
      if text.hasPrefix("["), let close = text.firstIndex(of: "]") {
         text = text[text.index(after: close)...].drop(while: \.isWhitespace)
      } else if text.hasPrefix("("), let close = text.firstIndex(of: ")"), isInflection(text[..<close]) {
         text = text[text.index(after: close)...].drop(while: \.isWhitespace)
      } else {
         break
      }
   }
   let pieces = splitsExample ? text.split(separator: ": ", maxSplits: 1, omittingEmptySubsequences: false) : [text]
   let definition = trimmed(pieces[0])
   guard !definition.isEmpty else { return nil }
   let example = pieces.count > 1 ? trimmed(withoutLabels(pieces[1].components(separatedBy: " | ")[0][...])) : ""
   return Definition.Sense(text: definition, example: example.isEmpty ? nil : example)
}

/// An example without a leading label, as in "[with object] : she ran it".
private func withoutLabels(_ text: Substring) -> Substring {
   var text = text.drop(while: \.isWhitespace)
   while text.hasPrefix("["), let close = text.firstIndex(of: "]") {
      text = text[text.index(after: close)...].drop { $0 == " " || $0 == ":" }
   }
   return text
}

/// A parenthesis that gives forms of the word rather than a context.
private func isInflection(_ group: Substring) -> Bool {
   let inner = group.dropFirst()
   return inner.contains("|") || ["plural", "also", "US", "past", "comparative", "superlative", ",", "same", "as"].contains { inner.hasPrefix($0) }
}

private func trimmed(_ text: Substring) -> String {
   var text = text.trimmingCharacters(in: .whitespaces)
   while text.hasSuffix(".") || text.hasSuffix(":") { text.removeLast() }
   return text
}

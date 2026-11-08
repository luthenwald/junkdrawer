import Foundation

/// The symbol table behind the LaTeX and Unicode modes, with search keys
/// built once so a keystroke only scans bytes.
public struct Symbols: Sendable {
   /// One item per LaTeX command, such as `\alpha`.
   public let latex: [Item]
   /// One item per character or emoji sequence.
   public let unicode: [Item]

   let latexKeys: [LatexKey]
   let unicodeKeys: [UnicodeKey]
   /// Unicode items by their string, for a query that is one character.
   let byString: [String: [Int]]
   let byID: [String: Item]
   /// Positions by id, for the frecency bonus.
   let latexIndex: [String: Int]
   let unicodeIndex: [String: Int]

   public init() {
      self.init(latex: [], latexKeys: [], unicode: [], unicodeKeys: [])
   }

   init(latex: [Item], latexKeys: [LatexKey], unicode: [Item], unicodeKeys: [UnicodeKey]) {
      self.latex = latex
      self.latexKeys = latexKeys
      self.unicode = unicode
      self.unicodeKeys = unicodeKeys
      byString = Dictionary(grouping: unicode.indices) { unicode[$0].glyphSource }
      byID = Dictionary((latex + unicode).map { ($0.id, $0) }) { first, _ in first }
      latexIndex = Dictionary(latex.indices.map { (latex[$0].id, $0) }) { first, _ in first }
      unicodeIndex = Dictionary(unicode.indices.map { (unicode[$0].id, $0) }) { first, _ in first }
   }

   /// The item with this id, for the recent list.
   public func item(id: String) -> Item? { byID[id] }
}

/// What a Unicode query is matched against: the name, the aliases and the
/// keywords, all lowercased UTF-8.
struct UnicodeKey: Sendable {
   let name: [UInt8]
   /// The aliases joined by "|".
   let aliases: [UInt8]
   /// True when byte offsets in the name are also character offsets.
   let isASCII: Bool
   let keywords: [[UInt8]]
   /// LaTeX command names without the backslash, so `:lambda` finds λ,
   /// which Unicode spells "lamda".
   let commands: [[UInt8]]
   /// Position in title order, for ties.
   let order: Int
}

/// A LaTeX command without its backslash, as typed and lowercased, plus
/// the key of its character for the name search.
struct LatexKey: Sendable {
   let command: [UInt8]
   let lowered: [UInt8]
   /// The command lowercased per character, for the fuzzy match.
   let folded: [Character]
   let symbol: Int
   let order: Int
}

/// Parses the table that `gen` writes: string, name, aliases, keywords,
/// commands and cell, tab separated, lists split by "|".
public func symbols(from tsv: String) -> Symbols {
   let tab = UInt8(ascii: "\t"), bar = UInt8(ascii: "|"), newline = UInt8(ascii: "\n")
   let records = Array(tsv.utf8).split(separator: newline).compactMap { line -> [String]? in
      let fields = line.split(separator: tab, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
      return fields.count == 6 ? fields : nil
   }

   let unicode = records.map { fields in
      let (string, name, cell) = (fields[0], fields[1], fields[5])
      let commands = list(fields[4])
      let codes = string.unicodeScalars.map(\.value)
      return Item(
         id: "uni:" + codes.map(hex).joined(separator: "-"),
         kind: .unicode,
         title: name,
         subtitle: commands.first.map { String($0.split(separator: " ")[0]) } ?? "",
         glyph: cell.isEmpty ? string : cell,
         trailing: codes.count == 1 ? codePoints(codes) : "\(codes.count) code points",
         primary: .insert(string),
         secondary: .copy(codePoints(codes))
      )
   }
   let unicodeOrder = rankOrder(unicode.map(\.title))
   let unicodeKeys = records.indices.map { index in
      let fields = records[index]
      let name = Array(fields[1].lowercased().utf8)
      let aliases = list(fields[2]).map { Array($0.lowercased().utf8) }
      return UnicodeKey(
         name: name,
         aliases: Array(aliases.joined(separator: [bar])),
         isASCII: name.allSatisfy { $0 < 0x80 },
         keywords: list(fields[3]).map { Array($0.lowercased().utf8) },
         commands: list(fields[4]).map { Array(bareCommand($0).lowercased().utf8) },
         order: unicodeOrder[index]
      )
   }

   let commands = records.indices.flatMap { symbol in
      list(records[symbol][4]).map { (symbol, $0.split(separator: " ", maxSplits: 1).map(String.init)) }
   }
   let latex = commands.map { symbol, parts in
      let item = unicode[symbol]
      let string = records[symbol][0]
      let codes = string.unicodeScalars.map(\.value)
      let package = parts.count > 1 ? parts[1] + " · " : ""
      return Item(
         id: "tex:" + parts[0],
         kind: .latex,
         title: parts[0],
         subtitle: item.title,
         glyph: item.glyph,
         trailing: package + codePoints(codes),
         primary: .insert(string),
         secondary: .copy(parts[0])
      )
   }
   let latexOrder = rankOrder(latex.map(\.title))
   let latexKeys = commands.indices.map { index in
      let bare = String(latex[index].title.dropFirst())
      return LatexKey(
         command: Array(bare.utf8),
         lowered: Array(bare.lowercased().utf8),
         folded: folded(bare),
         symbol: commands[index].0,
         order: latexOrder[index]
      )
   }
   return Symbols(latex: latex, latexKeys: latexKeys, unicode: unicode, unicodeKeys: unicodeKeys)
}

/// `\mathbb{N} amssymb` as `mathbb{N}`.
private func bareCommand(_ entry: String) -> String {
   String(entry.split(separator: " ")[0].dropFirst())
}

private func list(_ field: String) -> [String] {
   field.isEmpty ? [] : field.split(separator: "|").map(String.init)
}

private func hex(_ code: UInt32) -> String {
   let digits = String(code, radix: 16, uppercase: true)
   return String(repeating: "0", count: max(0, 4 - digits.count)) + digits
}

private func codePoints(_ codes: [UInt32]) -> String {
   codes.map { "U+" + hex($0) }.joined(separator: " ")
}

/// Each title's position in tie order, shorter titles first, then
/// alphabetical, so ties need no string compares per keystroke and
/// `:arrow right` lists "rightwards arrow" before longer names.
private func rankOrder(_ titles: [String]) -> [Int] {
   let lengths = titles.map(\.count)
   let sorted = titles.indices.sorted {
      lengths[$0] != lengths[$1] ? lengths[$0] < lengths[$1] : titles[$0].localizedStandardCompare(titles[$1]) == .orderedAscending
   }
   return sorted.enumerated().reduce(into: Array(repeating: 0, count: titles.count)) { order, pair in
      order[pair.element] = pair.offset
   }
}

extension Item {
   /// The string an insert would type.
   var glyphSource: String {
      if case .insert(let string) = primary { string } else { glyph ?? title }
   }
}

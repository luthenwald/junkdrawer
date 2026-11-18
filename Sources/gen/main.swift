import Foundation

// Writes the symbol table from the files in the data folder (`el gen`).
// One line per entry, sorted by code points, tab separated:
//
//    string, name, aliases, keywords, commands, cell
//
// Lists inside a field are separated by "|". A command is "\cmd" or
// "\cmd package". The cell is what the left cell shows when the string
// itself would be invisible or a lone combining mark, and is empty
// otherwise.

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 2 else {
   FileHandle.standardError.write(Data("usage: gen <data folder> <output .tsv>\n".utf8))
   exit(2)
}
let folder = URL(fileURLWithPath: arguments[0])
let output = URL(fileURLWithPath: arguments[1])

func lines(_ name: String) -> [Substring] {
   do {
      return try String(contentsOf: folder.appending(path: name), encoding: .utf8)
         .split(separator: "\n", omittingEmptySubsequences: true)
   } catch {
      FileHandle.standardError.write(Data("gen: cannot read \(name): \(error.localizedDescription)\n".utf8))
      exit(1)
   }
}

/// Splits on a separator by Unicode scalars: a combining character right
/// after "^" would otherwise join it into one `Character`.
func fields(_ line: Substring, separator: Unicode.Scalar) -> [String] {
   line.unicodeScalars.split(separator: separator, omittingEmptySubsequences: false).map { String(String.UnicodeScalarView($0)) }
}

func scalars(_ hex: some StringProtocol) -> [UInt32] {
   hex.split(separator: " ").compactMap { UInt32($0, radix: 16) }
}

func characters(_ codes: [UInt32]) -> String {
   String(String.UnicodeScalarView(codes.compactMap(Unicode.Scalar.init)))
}

func hex(_ code: UInt32) -> String {
   String(code, radix: 16, uppercase: true).leftPadded(to: 4)
}

extension String {
   func leftPadded(to width: Int) -> String {
      String(repeating: "0", count: max(0, width - count)) + self
   }
}

let variationSelector: UInt32 = 0xFE0F
let skinTones: ClosedRange<UInt32> = 0x1F3FB...0x1F3FF

// MARK: - Entries

struct Entry {
   var codes: [UInt32]
   var name: String
   var aliases: [String] = []
   var keywords: [String] = []
   var commands: [(command: String, package: String)] = []
   var cell = ""

   var string: String { characters(codes) }

   var line: String {
      [
         string,
         name,
         aliases.uniqued(excluding: [name]).joined(separator: "|"),
         keywords.uniqued(excluding: []).joined(separator: "|"),
         commands.map { $0.package.isEmpty ? $0.command : "\($0.command) \($0.package)" }.joined(separator: "|"),
         cell,
      ].joined(separator: "\t")
   }
}

extension Array where Element == String {
   /// The non-empty elements in order, each once, leaving out `excluding`.
   func uniqued(excluding: Set<String>) -> [String] {
      var seen = excluding
      return filter { !$0.isEmpty && seen.insert($0).inserted }
   }
}

// MARK: - UnicodeData.txt and NameAliases.txt

/// Names that are made from the code point, such as
/// "CJK COMPATIBILITY IDEOGRAPH-F900", and Tangut components, which are
/// numbered the same way.
func isAlgorithmic(_ name: Substring, code: UInt32) -> Bool {
   name.hasSuffix("-" + hex(code)) || name.hasPrefix("TANGUT COMPONENT-")
}

let skippedCategories: Set<Substring> = ["Cc", "Cs", "Co", "Cn"]
let invisibleCategories: Set<Substring> = ["Zs", "Zl", "Zp", "Cf"]
let markCategories: Set<Substring> = ["Mn", "Mc", "Me"]

/// Aliases by code point, with abbreviations kept apart for the cell.
let nameAliases: (all: [UInt32: [String]], abbreviations: [UInt32: String]) = lines("NameAliases.txt")
   .filter { !$0.hasPrefix("#") }
   .map { $0.split(separator: ";", omittingEmptySubsequences: false) }
   .filter { $0.count >= 3 }
   .reduce(into: ([:], [:])) { result, fields in
      guard let code = UInt32(fields[0], radix: 16) else { return }
      result.all[code, default: []].append(fields[1].lowercased())
      if fields[2] == "abbreviation", result.abbreviations[code] == nil {
         result.abbreviations[code] = String(fields[1])
      }
   }

var entries: [[UInt32]: Entry] = lines("UnicodeData.txt")
   .map { $0.split(separator: ";", omittingEmptySubsequences: false) }
   .reduce(into: [:]) { entries, fields in
      guard fields.count > 2, let code = UInt32(fields[0], radix: 16) else { return }
      let (name, category) = (fields[1], fields[2])
      guard !skippedCategories.contains(category), !name.hasPrefix("<"), !isAlgorithmic(name, code: code) else { return }
      var entry = Entry(codes: [code], name: name.lowercased(), aliases: nameAliases.all[code] ?? [])
      if invisibleCategories.contains(category) || markCategories.contains(category) {
         entry.cell = nameAliases.abbreviations[code]
            ?? (markCategories.contains(category) ? "◌" + characters([code]) : hex(code))
      }
      entries[entry.codes] = entry
   }

// MARK: - CLDR annotations

func plain(_ codes: [UInt32]) -> [UInt32] {
   codes.filter { $0 != variationSelector }
}

/// Keywords and spoken names by code points with FE0F removed, from the CLDR
/// annotations and the derived ones (sequences such as flags and families).
let annotations: (keywords: [[UInt32]: [String]], tts: [[UInt32]: String]) = {
   let pattern = /<annotation cp="([^"]+)"( type="tts")?>([^<]*)<\/annotation>/
   let unescaped = { (text: Substring) in
      text.replacing("&lt;", with: "<").replacing("&gt;", with: ">").replacing("&quot;", with: "\"")
         .replacing("&apos;", with: "'").replacing("&amp;", with: "&")
   }
   return (lines("cldr-annotations-en.xml") + lines("cldr-annotations-derived-en.xml"))
      .compactMap { $0.firstMatch(of: pattern) }
      .reduce(into: ([:], [:])) { result, match in
         let key = plain(unescaped(match.1).unicodeScalars.map(\.value))
         let text = unescaped(match.3).lowercased()
         if match.2 == nil {
            result.keywords[key] = text.components(separatedBy: " | ")
         } else {
            result.tts[key] = text
         }
      }
}()


// MARK: - emoji-test.txt

/// Fully-qualified emoji without skin tones. A single character that needs
/// FE0F to draw as an emoji keeps its text form in the Symbols group (arrows,
/// ©, ™), where people mean the symbol, and gets an emoji entry of its own
/// in the other groups (❤️, ☀️), next to the plain character.
var emojiForms: Set<[UInt32]> = []
do {
   let pattern = /^([0-9A-F ]+?)\s*; fully-qualified\s*# \S+ E[0-9.]+ (.+)$/
   var group = ""
   for line in lines("emoji-test.txt") {
      if line.hasPrefix("# group: ") { group = String(line.dropFirst(9)) }
      guard let match = line.firstMatch(of: pattern) else { continue }
      let codes = scalars(match.1)
      guard !codes.contains(where: skinTones.contains) else { continue }
      let name = String(match.2)
      let key = plain(codes)
      let keywords = annotations.keywords[key] ?? []
      if key.count == 1, var entry = entries[key] {
         if codes.count == 1 || group == "Symbols" {
            // The character itself: the emoji name first, Unicode's as an alias.
            entry.aliases.insert(entry.name, at: 0)
            entry.name = name
            entry.keywords += keywords
            entries[key] = entry
            continue
         }
         emojiForms.insert(key)
      }
      entries[codes] = Entry(codes: codes, name: name, keywords: keywords)
   }
}

/// Spoken names and keywords for the remaining characters, such as "{".
/// A character with an emoji entry of its own leaves them to that entry.
for (key, var entry) in entries where entry.keywords.isEmpty && key.count == 1 && !emojiForms.contains(key) {
   entry.keywords = annotations.keywords[key] ?? []
   if let tts = annotations.tts[key] { entry.aliases.append(tts) }
   entries[key] = entry
}

// MARK: - LaTeX commands

/// A command people type: letters with an optional braced argument, such
/// as `\mathbb{N}`, or a backslash and one sign, such as `\#`.
let commandPattern = /^\\([A-Za-z]+(\{[A-Za-z0-9]*\})?|[^A-Za-z0-9\s])$/

/// Features in the requirements that are not packages.
let notPackages: Set<Substring> = ["literal", "slantedGreek", "uprightGreek"]
/// Features named after the command they provide.
let featurePackages: [Substring: String] = ["mathbb": "amssymb"]

func package(from requirements: Substring) -> String {
   requirements.split(separator: " ")
      .first { !$0.hasPrefix("-") && !notPackages.contains($0) }
      .map { featurePackages[$0] ?? String($0) } ?? ""
}

/// Commands in order of precedence: each command goes to the first
/// character that claims it, so `tex:<command>` stays unique.
var claims: [(key: [UInt32], command: String, package: String)] = []

let records = lines("unimathsymbols.txt")
   .filter { !$0.hasPrefix("#") }
   .map { fields($0, separator: "^").map { $0.trimmingCharacters(in: .whitespaces) } }
   .filter { $0.count == 8 }
   .compactMap { fields -> (key: [UInt32], fields: [String])? in
      UInt32(fields[0], radix: 16).map { ([$0], fields) }
   }

// The preferred LaTeX command, then unicode-math's name for it, then the
// aliases in the comments ("= \mathds{N} (dsfont)").
for record in records {
   claims.append((record.key, record.fields[2], package(from: Substring(record.fields[6]))))
}
for record in records where record.fields[3] != record.fields[2] {
   claims.append((record.key, record.fields[3], "unicode-math"))
}
let aliasPattern = /^= (\\\S+)(?: \(([^)]*)\))?$/
for record in records {
   for part in record.fields[7].components(separatedBy: ", ") {
      guard let match = part.firstMatch(of: aliasPattern) else { continue }
      claims.append((record.key, String(match.1), match.2.map { package(from: $0) } ?? ""))
   }
}
let mathPattern = /\\UnicodeMathSymbol\{"([0-9A-F]+)\}\{(\\\S+?)\s*\}/
for line in lines("unicode-math-table.tex") {
   guard let match = line.firstMatch(of: mathPattern), let code = UInt32(match.1, radix: 16) else { continue }
   claims.append(([code], String(match.2), "unicode-math"))
}

var claimed: Set<String> = []
for claim in claims where claim.command.wholeMatch(of: commandPattern) != nil && entries[claim.key] != nil {
   guard claimed.insert(claim.command).inserted else { continue }
   entries[claim.key]?.commands.append((claim.command, claim.package))
}

// MARK: - Output

let sorted = entries.values.sorted { $0.codes.lexicographicallyPrecedes($1.codes) }
let text = sorted.map(\.line).joined(separator: "\n") + "\n"
do {
   try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
   try text.write(to: output, atomically: true, encoding: .utf8)
} catch {
   FileHandle.standardError.write(Data("gen: cannot write \(output.path): \(error.localizedDescription)\n".utf8))
   exit(1)
}
let sequences = sorted.filter { $0.codes.count > 1 }.count
print("""
   gen: \(sorted.count) entries, \(sorted.filter { !$0.commands.isEmpty }.count) with LaTeX commands \
   (\(claimed.count) commands), \(sequences) sequences
   """)

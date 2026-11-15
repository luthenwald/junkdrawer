import Foundation

/// How often things were used: per local day and kind, and per item over
/// all time. Unlike `Usage` it forgets nothing and plays no part in the
/// ranking; it is there to be looked at and exported.
public struct Stats: Codable, Hashable, Sendable {
   /// Counts by day, written as `2026-11-15`, then by the kind's name.
   public private(set) var days: [String: [String: Int]]
   /// Counts by item id.
   public private(set) var items: [String: Int]

   public init(days: [String: [String: Int]] = [:], items: [String: Int] = [:]) {
      self.days = days
      self.items = items
   }

   /// The format of `stats.json` and of the JSON export. A file without a
   /// version is version 1; a file from a later format is not read.
   public static let version = 1

   private enum CodingKeys: String, CodingKey { case version, days, items }

   public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      try container.checkVersion(.version, atMost: Self.version)
      days = try container.decode([String: [String: Int]].self, forKey: .days)
      items = try container.decode([String: Int].self, forKey: .items)
   }

   public func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(Self.version, forKey: .version)
      try container.encode(days, forKey: .days)
      try container.encode(items, forKey: .items)
   }

   /// With one more use of `item` on `day`.
   public func recording(_ item: Item, day: String) -> Stats {
      recording(id: item.id, kind: item.kind, day: day)
   }

   private func recording(id: String, kind: Kind, day: String) -> Stats {
      var next = self
      next.days[day, default: [:]][kind.rawValue, default: 0] += 1
      next.items[id, default: 0] += 1
      return next
   }

   /// A start from the picks that `usage` still remembers, for a first run
   /// after the statistics arrived. `day` names a date's local day.
   public static func seeded(from usage: Usage, day: (Date) -> String) -> Stats {
      usage.picks.reduce(Stats()) { stats, pick in
         guard let kind = Kind(id: pick.key) else { return stats }
         return pick.value.reduce(stats) { $0.recording(id: pick.key, kind: kind, day: day($1)) }
      }
   }

   /// The uses of `kind` over `days`.
   public func count(_ kind: Kind, over days: some Sequence<String>) -> Int {
      days.reduce(0) { $0 + (self.days[$1]?[kind.rawValue] ?? 0) }
   }

   /// The earliest day with a count.
   public var firstDay: String? { days.keys.min() }

   /// The most used items, the most used first, ties by id.
   public func top(_ limit: Int) -> [(id: String, count: Int)] {
      items
         .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
         .prefix(limit)
         .map { (id: $0.key, count: $0.value) }
   }

   /// The daily counts as lines of `day,kind,count` under a header, sorted.
   public var csv: String {
      let lines = days.keys.sorted().flatMap { day in
         (days[day] ?? [:]).sorted { $0.key < $1.key }.map { "\(day),\($0.key),\($0.value)" }
      }
      return (["day,kind,count"] + lines).joined(separator: "\n") + "\n"
   }

   /// A name for an item id that needs no index: the app's name, the
   /// command's or pane's title, the LaTeX command, the character itself,
   /// the word, or a bookmark's address.
   public static func label(for id: String) -> String {
      guard let kind = Kind(id: id), let colon = id.firstIndex(of: ":") else { return id }
      let rest = String(id[id.index(after: colon)...])
      switch kind {
      case .app:
         let name = rest.split(separator: "/").last.map(String.init) ?? rest
         return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
      case .command:
         return Command(rawValue: rest)?.title ?? rest
      case .setting:
         return SystemSettings.items.first { $0.id == id }?.title ?? rest
      case .unicode:
         let scalars = rest.split(separator: "-").compactMap { UInt32($0, radix: 16).flatMap(Unicode.Scalar.init) }
         return scalars.isEmpty ? rest : String(String.UnicodeScalarView(scalars)) + "  U+" + rest.replacingOccurrences(of: "-", with: " U+")
      case .bookmark:
         return rest.replacing(/^https?:\/\//, with: "")
      case .latex, .dictionary:
         return rest
      }
   }
}

extension Kind {
   /// The kind an item id belongs to, from its prefix.
   public init?(id: String) {
      let prefixes: [(String, Kind)] = [
         ("app:", .app), ("mark:", .bookmark), ("cmd:", .command), ("set:", .setting),
         ("tex:", .latex), ("uni:", .unicode), ("dict:", .dictionary),
      ]
      guard let kind = prefixes.first(where: { id.hasPrefix($0.0) })?.1 else { return nil }
      self = kind
   }

   /// How the statistics name the kind, in the plural.
   public var plural: String {
      switch self {
      case .app: "apps"
      case .bookmark: "bookmarks"
      case .command: "commands"
      case .setting: "settings"
      case .latex: "latex"
      case .unicode: "unicode"
      case .dictionary: "look-ups"
      }
   }
}

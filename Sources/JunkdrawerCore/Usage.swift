import Foundation

extension KeyedDecodingContainer {
   /// Throws for a file written in a later format than `newest`, so it is
   /// set aside rather than read wrongly. A missing version counts as 1.
   func checkVersion(_ key: Key, atMost newest: Int) throws {
      let version = try decodeIfPresent(Int.self, forKey: key) ?? 1
      guard version <= newest else {
         throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "format \(version) is newer than \(newest)")
      }
   }
}

/// When each item was picked, by item id, for frecency and the recent list.
public struct Usage: Codable, Hashable, Sendable {
   /// Picks kept per item; older ones would add almost nothing.
   public static let kept = 20
   /// Days after which a pick counts half.
   public static let halfLife: Double = 14

   public private(set) var picks: [String: [Date]]

   public init(picks: [String: [Date]] = [:]) {
      self.picks = picks
   }

   /// The format of `usage.json`. A file without a version is version 1; a
   /// file from a later format is not read.
   public static let version = 1

   private enum CodingKeys: String, CodingKey { case version, picks }

   public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      try container.checkVersion(.version, atMost: Self.version)
      picks = try container.decode([String: [Date]].self, forKey: .picks)
   }

   public func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(Self.version, forKey: .version)
      try container.encode(picks, forKey: .picks)
   }

   /// With one more pick of `id` at `date`.
   public func recording(_ id: String, at date: Date) -> Usage {
      var next = self
      next.picks[id] = Array(((picks[id] ?? []) + [date]).suffix(Self.kept))
      return next
   }

   /// 12 times log2(1 + w), where each pick adds 0.5^(age in days / 14) to
   /// w, so a habit from a month ago fades to a quarter.
   public func bonus(for id: String, now: Date) -> Double {
      let weight = (picks[id] ?? []).reduce(0.0) { sum, date in
         sum + pow(0.5, max(0, now.timeIntervalSince(date)) / 86_400 / Self.halfLife)
      }
      return 12 * log2(1 + weight)
   }

   /// Item ids, the most recently picked first.
   public func recent(limit: Int) -> [String] {
      picks
         .compactMap { id, dates in dates.max().map { (id, $0) } }
         .sorted { $0.1 > $1.1 }
         .prefix(limit)
         .map(\.0)
   }
}

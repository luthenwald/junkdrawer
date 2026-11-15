import Foundation
import JunkdrawerCore
import Observation
import os

/// The counts behind the statistics window, kept in `stats.json`. A missing
/// file starts from the picks that `usage.json` remembers; a broken one is
/// logged and replaced on the next use.
@MainActor @Observable
final class StatsStore {
   nonisolated static let defaultFile = FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "Library/Application Support/Junkdrawer/stats.json")

   private(set) var stats: Stats
   @ObservationIgnored private let file: URL
   @ObservationIgnored private var write: Task<Void, Never>?

   init(file: URL = defaultFile, seed: Usage = Usage()) {
      self.file = file
      stats = Self.load(file) ?? .seeded(from: seed) { $0.statsDay }
   }

   func record(_ item: Item, at date: Date = Date()) {
      stats = stats.recording(item, day: date.statsDay)
      let (stats, file, previous) = (stats, file, write)
      // One write at a time, in order, so an older one never lands last.
      write = Task.detached {
         await previous?.value
         do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoded(stats).write(to: file, options: .atomic)
         } catch {
            Logger.app.error("writing stats.json failed: \(error.localizedDescription, privacy: .public)")
         }
      }
   }

   /// As the file holds them, for the file and for an export.
   nonisolated static func encoded(_ stats: Stats) throws -> Data {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
      return try encoder.encode(stats)
   }

   private static func load(_ file: URL) -> Stats? {
      guard let data = try? Data(contentsOf: file) else { return nil }
      do {
         return try JSONDecoder().decode(Stats.self, from: data)
      } catch {
         Logger.app.error("reading stats.json failed: \(error.localizedDescription, privacy: .public)")
         return Stats()
      }
   }
}

extension Date {
   /// The local day, as `2026-11-15`, which keys the statistics.
   var statsDay: String {
      formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
   }
}

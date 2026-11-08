import Foundation
import JunkdrawerCore
import os

/// The picks behind frecency and the recent list, kept in `usage.json`.
/// A missing file means no picks yet; a broken one is logged and replaced
/// on the next pick.
@MainActor
final class UsageStore {
   nonisolated static let defaultFile = FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "Library/Application Support/Junkdrawer/usage.json")

   private(set) var usage: Usage
   private let file: URL
   private var write: Task<Void, Never>?

   init(file: URL = defaultFile) {
      self.file = file
      usage = Self.load(file)
   }

   func record(_ item: Item, at date: Date = Date()) {
      usage = usage.recording(item.id, at: date)
      let (usage, file, previous) = (usage, file, write)
      // One write at a time, in order, so an older one never lands last.
      write = Task.detached {
         await previous?.value
         Self.save(usage, to: file)
      }
   }

   private static func load(_ file: URL) -> Usage {
      guard let data = try? Data(contentsOf: file) else { return Usage() }
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      do {
         return try decoder.decode(Usage.self, from: data)
      } catch {
         Logger.app.error("reading usage.json failed: \(error.localizedDescription, privacy: .public)")
         return Usage()
      }
   }

   nonisolated private static func save(_ usage: Usage, to file: URL) {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.sortedKeys]
      do {
         try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
         try encoder.encode(usage).write(to: file, options: .atomic)
      } catch {
         Logger.app.error("writing usage.json failed: \(error.localizedDescription, privacy: .public)")
      }
   }
}

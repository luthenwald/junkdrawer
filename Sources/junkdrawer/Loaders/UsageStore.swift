import Foundation
import JunkdrawerCore
import os

/// The picks behind frecency and the recent list, kept in `usage.json`.
/// A missing file means no picks yet, and so does a broken one, which is
/// kept as `usage.json.broken`.
@MainActor
final class UsageStore {
   nonisolated static let defaultFile = FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "Library/Application Support/Junkdrawer/usage.json")

   private(set) var usage: Usage
   private let file: URL
   private var write: Task<Void, Never>?

   init(file: URL = defaultFile) {
      self.file = file
      usage = StoreFile.load(file, dates: .iso8601) ?? Usage()
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

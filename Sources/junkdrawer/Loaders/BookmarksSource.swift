import Foundation
import JunkdrawerCore
import os

/// Keeps the bookmarks current: reads the file at launch and after changes
/// in its folder. A missing file means no bookmarks.
@MainActor
final class BookmarksSource {
   nonisolated static let defaultFile = FileManager.default.homeDirectoryForCurrentUser
      .appending(path: ".config/junkdrawer/bookmarks")

   let file: URL
   private let publish: ([Item]) -> Void
   private var read: Task<Void, Never>?
   private var watcher: FolderWatcher?
   private var watched: String?

   init(file: URL = defaultFile, publish: @escaping ([Item]) -> Void) {
      self.file = file
      self.publish = publish
      reload()
   }

   func reload() {
      read?.cancel()
      read = Task { [file] in
         let items = await Task.detached { Self.load(file) }.value
         guard !Task.isCancelled else { return }
         publish(items)
         // After an await, so a watcher is never replaced from inside its
         // own callback.
         watch()
      }
   }

   /// Stops reading and watching, before another file takes over.
   func stop() {
      read?.cancel()
      watcher = nil
   }

   /// The file's folder once it exists, its parent until then, so creating
   /// the folder is noticed too.
   private func watch() {
      let folder = file.deletingLastPathComponent()
      let target = [folder, folder.deletingLastPathComponent()]
         .map(\.path)
         .first { FileManager.default.fileExists(atPath: $0) }
      guard let target, target != watched else { return }
      watched = target
      watcher = FolderWatcher(paths: [target]) { [unowned self] in reload() }
   }

   nonisolated private static func load(_ file: URL) -> [Item] {
      guard FileManager.default.fileExists(atPath: file.path) else { return [] }
      do {
         return bookmarks(from: try String(contentsOf: file, encoding: .utf8))
      } catch {
         Logger.app.error("reading the bookmarks failed: \(error.localizedDescription, privacy: .public)")
         return []
      }
   }
}

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
   private var watched: [String] = []

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
   /// the folder is noticed too. A file that is a link, as one kept in a
   /// dotfiles folder, is watched where it really is as well.
   private func watch() {
      let folder = file.deletingLastPathComponent()
      let real = file.resolvingSymlinksInPath().deletingLastPathComponent()
      let exists = { (path: String) in FileManager.default.fileExists(atPath: path) }
      let own = [folder, folder.deletingLastPathComponent()].map(\.path).first(where: exists)
      let targets = [own, real.path == folder.path || !exists(real.path) ? nil : real.path].compactMap { $0 }
      guard !targets.isEmpty, targets != watched else { return }
      watched = targets
      watcher = FolderWatcher(paths: targets) { [unowned self] in reload() }
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

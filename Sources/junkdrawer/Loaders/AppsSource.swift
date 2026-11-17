import CoreGraphics
import JunkdrawerCore

/// Keeps the app list current: scans at launch and after changes in the app
/// folders, off the main thread, then renders the icons it does not have yet.
/// A folder that is not there, such as one on a drive not connected, gives
/// no apps.
@MainActor
final class AppsSource {
   private let publish: (_ items: [Item], _ icons: [String: CGImage]) -> Void
   private var icons: [String: CGImage] = [:]
   private var scan: Task<Void, Never>?
   private var watcher: FolderWatcher?

   /// Changing them watches and scans the new ones.
   var folders: [String] {
      didSet {
         guard folders != oldValue else { return }
         watch()
         reload()
      }
   }

   init(folders: [String], publish: @escaping (_ items: [Item], _ icons: [String: CGImage]) -> Void) {
      self.folders = folders
      self.publish = publish
      watch()
      reload()
   }

   private func watch() {
      watcher = FolderWatcher(paths: folders) { [unowned self] _ in reload() }
   }

   func reload() {
      scan?.cancel()
      scan = Task { [folders] in
         let items = await Task.detached { AppScanner.scan(folders) }.value
         guard !Task.isCancelled else { return }
         publish(items, icons)
         let missing = items.filter { icons[$0.id] == nil }
         guard !missing.isEmpty else { return }
         let fresh = await Task.detached { AppIcons.render(missing) }.value
         guard !Task.isCancelled else { return }
         icons.merge(fresh) { _, new in new }
         publish(items, icons)
      }
   }
}

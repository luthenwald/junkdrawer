import CoreGraphics
import JunkdrawerCore

/// Keeps the app list current: scans at launch and after changes in the app
/// folders, off the main thread, then renders the icons it does not have yet.
@MainActor
final class AppsSource {
   private let publish: (_ items: [Item], _ icons: [String: CGImage]) -> Void
   private var icons: [String: CGImage] = [:]
   private var scan: Task<Void, Never>?
   private var watcher: FolderWatcher?

   init(publish: @escaping (_ items: [Item], _ icons: [String: CGImage]) -> Void) {
      self.publish = publish
      watcher = FolderWatcher(paths: AppScanner.folders) { [unowned self] in reload() }
      reload()
   }

   func reload() {
      scan?.cancel()
      scan = Task {
         let items = await Task.detached { AppScanner.scan() }.value
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

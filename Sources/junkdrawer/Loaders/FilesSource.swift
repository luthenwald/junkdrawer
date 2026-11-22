import Foundation
import JunkdrawerCore

/// Keeps the files of the `/` mode current: scans the chosen folders at
/// launch, after they or the depth change, and after changes inside them,
/// off the main thread. Changes under skipped names, such as a build
/// writing into `.build`, cause no scan.
@MainActor
final class FilesSource {
   /// The folders and how deep to look into them.
   struct Scope: Equatable {
      var folders: [String]
      var depth: Int
   }

   private let publish: (Files) -> Void
   private var scan: Task<Void, Never>?
   private var watcher: FolderWatcher?

   var scope: Scope {
      didSet {
         guard scope != oldValue else { return }
         if scope.folders != oldValue.folders { watch() }
         reload()
      }
   }

   init(scope: Scope, publish: @escaping (Files) -> Void) {
      self.scope = scope
      self.publish = publish
      watch()
      reload()
   }

   private func watch() {
      let folders = scope.folders
      watcher = folders.isEmpty ? nil : FolderWatcher(paths: folders) { [unowned self] changed in
         guard !changed.allSatisfy({ FileScanner.isIgnored($0, roots: folders) }) else { return }
         reload()
      }
   }

   func reload() {
      scan?.cancel()
      scan = Task { [scope] in
         let home = FileManager.default.homeDirectoryForCurrentUser.path
         // A detached task is not cancelled with this one, so it is told.
         let work = Task.detached {
            Files(roots: scope.folders, entries: FileScanner.scan(scope.folders, depth: scope.depth), home: home)
         }
         let files = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
         guard !Task.isCancelled else { return }
         publish(files)
      }
   }
}

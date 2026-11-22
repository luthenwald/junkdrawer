import Foundation
import JunkdrawerCore
import os

/// The files and folders under the folders chosen for the `/` mode.
enum FileScanner {
   /// Skipped with everything under them, besides names starting with a dot.
   static let skipped: Set<String> = ["node_modules", "build", "DerivedData", "Pods", "target", "__pycache__", "venv"]
   /// Where a scan stops, so a folder chosen by mistake, such as the home
   /// folder, cannot grow the index without bound.
   static let limit = 200_000

   static func isSkipped(_ name: some StringProtocol) -> Bool {
      name.hasPrefix(".") || skipped.contains(String(name))
   }

   /// Whether a change at `path` can be left alone: it is not below any of
   /// the roots, or it lies under a skipped name, as a build's output does.
   static func isIgnored(_ path: String, roots: [String]) -> Bool {
      guard let root = roots.first(where: { path == $0 || path.hasPrefix($0 + "/") }) else { return true }
      return path.dropFirst(root.count).split(separator: "/").contains(where: isSkipped)
   }

   /// The path with every link followed, as FSEvents reports changes, or
   /// nil for a path that does not exist. `resolvingSymlinksInPath` would
   /// drop a leading `/private`, which FSEvents keeps.
   static func real(_ path: String) -> String? {
      guard let resolved = realpath(path, nil) else { return nil }
      defer { free(resolved) }
      return String(cString: resolved)
   }

   /// Everything under `roots` down to `depth`, each path once. A package
   /// such as an app is one entry and is not entered. A cancelled scan
   /// returns early with what it has, which the caller drops.
   static func scan(_ roots: [String], depth: Int) -> [FileEntry] {
      let start = ContinuousClock.now
      let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
      var seen = Set<String>()
      var found: [FileEntry] = []
      for root in roots {
         // Not `.skipsHiddenFiles`, which also skips entries with the hidden
         // flag; dot names are skipped below.
         guard let walk = FileManager.default.enumerator(
            at: URL(fileURLWithPath: root, isDirectory: true), includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants], errorHandler: { _, _ in true }
         ) else { continue }
         for case let url as URL in walk {
            if Task.isCancelled { return found }
            if isSkipped(url.lastPathComponent) {
               walk.skipDescendants()
               continue
            }
            if walk.level >= depth { walk.skipDescendants() }
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { continue }
            let values = try? url.resourceValues(forKeys: Set(keys))
            found.append(FileEntry(path: path, root: root, isFolder: values?.isDirectory == true && values?.isPackage != true))
            if found.count >= limit {
               Logger.app.notice("file scan stopped at \(limit, privacy: .public) entries")
               return found
            }
         }
      }
      Logger.app.debug("scanned \(found.count, privacy: .public) files in \(start.millisecondsAgo, format: .fixed(precision: 1), privacy: .public) ms")
      return found
   }
}

import Foundation
import JunkdrawerCore

/// The apps in the usual folders, as items.
enum AppScanner {
   private static let home = FileManager.default.homeDirectoryForCurrentUser.path

   /// Searched one level into plain folders, such as Setapp and Chrome
   /// Apps, as the folders added in Settings are.
   static let builtIn = [
      "/Applications",
      "/Applications/Utilities",
      "/System/Applications",
      "/System/Applications/Utilities",
      "\(home)/Applications",
   ]

   /// Apps outside those folders that belong in the list.
   private static let extras = ["/System/Library/CoreServices/Finder.app"]

   static func scan(_ folders: [String]) -> [Item] {
      let found = folders.flatMap { bundles(in: URL(fileURLWithPath: $0), depth: 1) }
         + extras.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
      var seen = Set<String>()
      return found
         .map(\.standardizedFileURL)
         .filter { seen.insert($0.path).inserted }
         .map(item)
   }

   private static func bundles(in folder: URL, depth: Int) -> [URL] {
      let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
      // Not `.skipsHiddenFiles`: it also skips entries with the hidden flag,
      // such as the Safari link into the system cryptex.
      let contents = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
      return contents.filter { !$0.lastPathComponent.hasPrefix(".") }.flatMap { url -> [URL] in
         if url.pathExtension == "app" { return [url] }
         guard depth > 0, let values = try? url.resourceValues(forKeys: Set(keys)),
               values.isDirectory == true, values.isPackage != true else { return [] }
         return bundles(in: url, depth: depth - 1)
      }
   }

   private static func item(_ url: URL) -> Item {
      let name = FileManager.default.displayName(atPath: url.path)
      let folder = url.deletingLastPathComponent().path
      return Item(
         id: "app:\(url.path)",
         kind: .app,
         title: name.hasSuffix(".app") ? String(name.dropLast(4)) : name,
         subtitle: folder.hasPrefix(home) ? "~" + folder.dropFirst(home.count) : folder,
         trailing: "application",
         primary: .openApp(url),
         secondary: .reveal(url)
      )
   }
}

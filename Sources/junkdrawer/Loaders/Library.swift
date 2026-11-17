import CoreGraphics
import Foundation
import JunkdrawerCore

/// Everything the panel can list: apps, bookmarks, the built-in commands,
/// the System Settings panes, the symbol table and the files, published
/// together whenever a source changes. The app folders, the bookmarks
/// file, the file folders and the hidden items follow the settings.
@MainActor
final class Library {
   private let settings: Settings
   private let publish: (_ index: Index, _ icons: [String: CGImage]) -> Void
   private var apps: [Item] = []
   private var bookmarks: [Item] = []
   private var symbols = Symbols()
   private var files = Files()
   private var icons: [String: CGImage] = [:]
   private var appsSource: AppsSource?
   private var bookmarksSource: BookmarksSource?
   private var symbolsSource: SymbolsSource?
   private var filesSource: FilesSource?

   init(
      settings: Settings, symbolsFile: URL? = SymbolsSource.defaultFile,
      publish: @escaping (_ index: Index, _ icons: [String: CGImage]) -> Void
   ) {
      self.settings = settings
      self.publish = publish
      symbolsSource = SymbolsSource(file: symbolsFile) { [unowned self] table in
         symbols = table
         push()
      }
      appsSource = AppsSource(folders: Self.appFolders(settings)) { [unowned self] items, icons in
         apps = items
         self.icons = icons
         push()
      }
      track { [unowned self] in appsSource?.folders = Self.appFolders(settings) }
      filesSource = FilesSource(scope: Self.fileScope(settings)) { [unowned self] found in
         files = found
         push()
      }
      track { [unowned self] in filesSource?.scope = Self.fileScope(settings) }
      track { [unowned self] in
         let file = settings.bookmarksURL
         guard file != bookmarksSource?.file else { return }
         bookmarksSource?.stop()
         bookmarksSource = BookmarksSource(file: file) { [unowned self] items in
            bookmarks = items
            push()
         }
      }
      track { [unowned self] in
         _ = settings.hidden
         push()
      }
   }

   var bookmarksFile: URL { settings.bookmarksURL }

   private static func appFolders(_ settings: Settings) -> [String] {
      AppScanner.builtIn + settings.appFolders.filter { !AppScanner.builtIn.contains($0) }
   }

   private static func fileScope(_ settings: Settings) -> FilesSource.Scope {
      FilesSource.Scope(folders: settings.fileFolders, depth: settings.fileDepth)
   }

   func reload() {
      appsSource?.reload()
      bookmarksSource?.reload()
      filesSource?.reload()
   }

   private func push() {
      let index = Index(items: apps + bookmarks + Command.items + SystemSettings.items, symbols: symbols, files: files)
      publish(index.hiding(Set(settings.hidden.keys)), icons)
   }
}

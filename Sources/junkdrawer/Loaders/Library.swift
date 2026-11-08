import CoreGraphics
import Foundation
import JunkdrawerCore

/// Everything the panel can list: apps, bookmarks, the built-in commands
/// and the symbol table, published together whenever a source changes.
/// The app folders and the bookmarks file follow the settings.
@MainActor
final class Library {
   private let settings: Settings
   private let publish: (_ index: Index, _ icons: [String: CGImage]) -> Void
   private var apps: [Item] = []
   private var bookmarks: [Item] = []
   private var symbols = Symbols()
   private var icons: [String: CGImage] = [:]
   private var appsSource: AppsSource?
   private var bookmarksSource: BookmarksSource?
   private var symbolsSource: SymbolsSource?

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
      track { [unowned self] in
         let file = settings.bookmarksURL
         guard file != bookmarksSource?.file else { return }
         bookmarksSource?.stop()
         bookmarksSource = BookmarksSource(file: file) { [unowned self] items in
            bookmarks = items
            push()
         }
      }
   }

   var bookmarksFile: URL { settings.bookmarksURL }

   private static func appFolders(_ settings: Settings) -> [String] {
      AppScanner.builtIn + settings.appFolders.filter { !AppScanner.builtIn.contains($0) }
   }

   func reload() {
      appsSource?.reload()
      bookmarksSource?.reload()
   }

   private func push() {
      publish(Index(items: apps + bookmarks + Command.items, symbols: symbols), icons)
   }
}

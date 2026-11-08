import CoreGraphics
import Foundation
import JunkdrawerCore

/// Everything the panel can list: apps, bookmarks, the built-in commands
/// and the symbol table, published together whenever a source changes.
@MainActor
final class Library {
   let bookmarksFile: URL
   private let publish: (_ index: Index, _ icons: [String: CGImage]) -> Void
   private var apps: [Item] = []
   private var bookmarks: [Item] = []
   private var symbols = Symbols()
   private var icons: [String: CGImage] = [:]
   private var appsSource: AppsSource?
   private var bookmarksSource: BookmarksSource?
   private var symbolsSource: SymbolsSource?

   init(
      bookmarksFile: URL = BookmarksSource.defaultFile, symbolsFile: URL? = SymbolsSource.defaultFile,
      publish: @escaping (_ index: Index, _ icons: [String: CGImage]) -> Void
   ) {
      self.bookmarksFile = bookmarksFile
      self.publish = publish
      symbolsSource = SymbolsSource(file: symbolsFile) { [unowned self] table in
         symbols = table
         push()
      }
      appsSource = AppsSource { [unowned self] items, icons in
         apps = items
         self.icons = icons
         push()
      }
      bookmarksSource = BookmarksSource(file: bookmarksFile) { [unowned self] items in
         bookmarks = items
         push()
      }
   }

   func reload() {
      appsSource?.reload()
      bookmarksSource?.reload()
   }

   private func push() {
      publish(Index(items: apps + bookmarks + Command.items, symbols: symbols), icons)
   }
}

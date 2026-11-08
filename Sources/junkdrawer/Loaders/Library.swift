import CoreGraphics
import Foundation
import JunkdrawerCore

/// Everything the panel can list: apps, bookmarks and the built-in
/// commands, published together whenever a source changes.
@MainActor
final class Library {
   let bookmarksFile: URL
   private let publish: (_ items: [Item], _ icons: [String: CGImage]) -> Void
   private var apps: [Item] = []
   private var bookmarks: [Item] = []
   private var icons: [String: CGImage] = [:]
   private var appsSource: AppsSource?
   private var bookmarksSource: BookmarksSource?

   init(bookmarksFile: URL = BookmarksSource.defaultFile, publish: @escaping (_ items: [Item], _ icons: [String: CGImage]) -> Void) {
      self.bookmarksFile = bookmarksFile
      self.publish = publish
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
      publish(apps + bookmarks + Command.items, icons)
   }
}

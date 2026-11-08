/// The commands built into the plain mode, so the app needs no menu bar.
public enum Command: String, Hashable, Sendable, CaseIterable {
   case reload
   case editBookmarks
   case showLogs
   case settings
   case quit

   public var title: String {
      switch self {
      case .reload: "Reload data"
      case .editBookmarks: "Edit bookmarks"
      case .showLogs: "Show logs"
      case .settings: "Settings"
      case .quit: "Quit junkdrawer"
      }
   }

   /// Other words that find the command.
   public var keywords: String {
      self == .settings ? "preferences" : ""
   }

   /// The command's row, matched like apps.
   public var item: Item {
      Item(
         id: "cmd:\(rawValue)", kind: .command, title: title, subtitle: "", keywords: keywords,
         trailing: "command", primary: .command(self), secondary: .command(self)
      )
   }

   public static let items: [Item] = allCases.map(\.item)
}

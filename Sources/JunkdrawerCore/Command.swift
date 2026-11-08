/// The commands built into the plain mode, so the app needs no menu bar.
public enum Command: String, Hashable, Sendable, CaseIterable {
   case reload
   case editBookmarks
   case showLogs
   case quit

   public var title: String {
      switch self {
      case .reload: "Reload data"
      case .editBookmarks: "Edit bookmarks"
      case .showLogs: "Show logs"
      case .quit: "Quit junkdrawer"
      }
   }

   /// One row per command, matched like apps.
   public static let items: [Item] = allCases.map { command in
      Item(
         id: "cmd:\(command.rawValue)", kind: .command, title: command.title, subtitle: "",
         trailing: "command", primary: .command(command), secondary: .command(command)
      )
   }
}

/// The commands built into the plain mode, so the app needs no menu bar.
public enum Command: String, Hashable, Sendable, CaseIterable {
   case reload
   case editBookmarks
   case showLogs
   case settings
   case statistics
   case sleep
   case sleepDisplays
   case lockScreen
   case logOut
   case restart
   case shutDown
   case emptyTrash
   case quit

   public var title: String {
      switch self {
      case .reload: "Reload data"
      case .editBookmarks: "Edit bookmarks"
      case .showLogs: "Show logs"
      case .settings: "Settings"
      case .statistics: "Statistics"
      case .sleep: "Sleep"
      case .sleepDisplays: "Sleep displays"
      case .lockScreen: "Lock screen"
      case .logOut: "Log out"
      case .restart: "Restart"
      case .shutDown: "Shut down"
      case .emptyTrash: "Empty Trash"
      case .quit: "Quit junkdrawer"
      }
   }

   /// Other words that find the command.
   public var keywords: String {
      switch self {
      case .settings: "preferences"
      case .statistics: "stats usage counts"
      case .sleepDisplays: "display screen off"
      case .lockScreen: "lock"
      case .logOut: "logout sign out"
      case .restart: "reboot"
      case .shutDown: "power off shutdown"
      case .emptyTrash: "bin"
      default: ""
      }
   }

   /// Whether running it counts as a pick. Those that end the session or
   /// cannot be undone never join the recent list, where ↵ on an empty
   /// query would run them.
   public var isPick: Bool {
      ![.quit, .logOut, .restart, .shutDown, .emptyTrash].contains(self)
   }

   /// Whether it opens a window of the app itself. The panel then hides
   /// without handing the focus back, since macOS would give it to some
   /// window of the previous app, and a window manager such as AeroSpace
   /// would follow that window to its workspace.
   public var opensWindow: Bool {
      self == .settings || self == .statistics
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

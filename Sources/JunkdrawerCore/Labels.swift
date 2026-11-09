extension Query {
   /// Shown at the left of the footer.
   public var label: String {
      switch mode {
      case .plain: text.isEmpty ? "recent" : "apps · bookmarks"
      case .latex: "latex"
      case .unicode: "unicode"
      case .dictionary: "dictionary"
      }
   }
}

extension Item {
   /// What ↵ does, after its key in the footer.
   public var primaryHint: String { hint(primary) }

   /// What ⌘↵ does, after its key in the footer.
   public var secondaryHint: String { hint(secondary) }

   private func hint(_ action: Action) -> String {
      switch (kind, action) {
      case (_, .openApp): "open"
      case (_, .reveal): "reveal in Finder"
      case (.setting, .openURL): "open in System Settings"
      case (_, .openURL): "open in default browser"
      case (_, .insert): "insert \(shown)"
      case (.bookmark, .copy): "copy url"
      case (.dictionary, .copy): "copy definition"
      case (_, .copy(let string)): "copy \(string)"
      case (_, .openDefinition): "open in Dictionary"
      case (_, .setQuery): "look up"
      case (_, .command): "run"
      }
   }

   /// The confirmation line after `action` ran, or nil when there is
   /// nothing to say, as after quitting.
   public func confirmation(for action: Action, outcome: Outcome = .done) -> String? {
      switch (action, outcome) {
      case (.insert, .copiedSecureInput): return "copied \(shown), since secure input is on"
      case (.insert, .copiedNoAccess): return "copied \(shown); allow junkdrawer in Privacy & Security, Accessibility to insert"
      case (_, .noAccess): return "allow junkdrawer in Privacy & Security, Accessibility to \(title.lowercased())"
      default: break
      }
      return switch action {
      case .openApp: "opened \(title)"
      case .reveal(let url): "revealed \(url.lastPathComponent) in Finder"
      case .openURL: kind == .setting ? "opened \(title) in System Settings" : "opened \(subtitle) in the default browser"
      case .insert: "inserted \(shown)"
      case .copy(let string): kind == .dictionary ? "copied the definition of “\(title)”" : "copied \(string)"
      case .openDefinition: "opened “\(title)” in Dictionary"
      case .setQuery: nil
      case .command(.reload): "reloaded apps and bookmarks"
      case .command(.editBookmarks): "opened the bookmarks file"
      case .command(.showLogs): "opened the log"
      case .command(.emptyTrash): "emptied the Trash"
      // The rest show for themselves.
      case .command: nil
      }
   }

   /// The symbol as the left cell shows it, so an invisible character reads
   /// as its abbreviation.
   private var shown: String { glyph ?? title }
}

/// How an action turned out, when it can differ from what was asked: an
/// insert copies instead while secure input is on or before Accessibility
/// access is granted, and locking the screen needs that access too.
public enum Outcome: Hashable, Sendable {
   case done
   case copiedSecureInput
   case copiedNoAccess
   case noAccess
}

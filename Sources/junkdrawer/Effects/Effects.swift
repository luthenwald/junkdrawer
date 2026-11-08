import AppKit
import JunkdrawerCore
import os

/// The one place that carries out an `Action`.
@MainActor
enum Effects {
   static func perform(_ action: Action) {
      switch action {
      case .openApp(let url):
         NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error { Logger.app.error("opening \(url.path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)") }
         }
      case .reveal(let url):
         NSWorkspace.shared.activateFileViewerSelecting([url])
      case .openURL, .insert, .copy, .openDefinition, .setQuery, .command:
         // Bookmarks, symbols, the dictionary and commands come in later milestones.
         Logger.app.notice("not handled yet: \(String(describing: action), privacy: .public)")
      }
   }
}

import AppKit
import JunkdrawerCore
import UniformTypeIdentifiers
import os

/// The one place that carries out an `Action`.
@MainActor
struct Effects {
   /// Reloads apps and bookmarks, for the Reload data command.
   let reload: () -> Void
   let openSettings: () -> Void
   /// The bookmarks file in use, which Settings can change.
   let bookmarksFile: () -> URL
   let inserter = Inserter()

   nonisolated static let logFile = FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "Library/Logs/Junkdrawer/junkdrawer.log")

   private static let bookmarksExample = """
   ; One bookmark per line: the URL, the title, then optional #tags.
   ; Lines starting with ; are comments.
   ; https://codeberg.org Codeberg #git #forge

   """

   /// What happened, which differs from what was asked when an insert
   /// had to copy instead.
   @discardableResult
   func perform(_ action: Action) -> Outcome {
      switch action {
      case .insert(let string):
         return inserter.insert(string)
      case .openApp(let url):
         NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error { Logger.app.error("opening \(url.path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)") }
         }
      case .reveal(let url):
         NSWorkspace.shared.activateFileViewerSelecting([url])
      case .openURL(let url):
         if !NSWorkspace.shared.open(url) { Logger.app.error("opening \(url.absoluteString, privacy: .public) failed") }
      case .copy(let string):
         NSPasteboard.general.clearContents()
         NSPasteboard.general.setString(string, forType: .string)
      case .command(.reload):
         reload()
      case .command(.editBookmarks):
         editBookmarks()
      case .command(.showLogs):
         showLogs()
      case .command(.settings):
         openSettings()
      case .command(.quit):
         NSApp.terminate(nil)
      case .command(let command):
         return System.perform(command)
      case .openDefinition(let word):
         guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let url = URL(string: "dict://" + encoded), NSWorkspace.shared.open(url)
         else {
            Logger.app.error("opening \(word, privacy: .public) in Dictionary failed")
            break
         }
      case .setQuery:
         // The panel sets its own query and stays open.
         Logger.app.error("setQuery reached the effects: \(String(describing: action), privacy: .public)")
      }
      return .done
   }

   /// Creates the file with a commented example when it is missing, then
   /// opens it in the default text editor; it has no extension to go by.
   private func editBookmarks() {
      let bookmarksFile = bookmarksFile()
      let manager = FileManager.default
      do {
         if !manager.fileExists(atPath: bookmarksFile.path) {
            try manager.createDirectory(at: bookmarksFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.bookmarksExample.write(to: bookmarksFile, atomically: true, encoding: .utf8)
         }
      } catch {
         Logger.app.error("creating the bookmarks file failed: \(error.localizedDescription, privacy: .public)")
         return
      }
      reload()
      guard let editor = NSWorkspace.shared.urlForApplication(toOpen: .plainText) else {
         NSWorkspace.shared.open(bookmarksFile)
         return
      }
      NSWorkspace.shared.open([bookmarksFile], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration())
   }

   /// The last hour of the app's log lines, written to a file and opened
   /// in the default app for logs, which is Console.
   private func showLogs() {
      let file = Self.logFile
      Task.detached {
         do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: file.path, contents: nil)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            process.arguments = ["show", "--last", "1h", "--predicate", "subsystem == \"junkdrawer.junkdrawer\"", "--style", "compact"]
            process.standardOutput = try FileHandle(forWritingTo: file)
            try process.run()
            process.waitUntilExit()
            await MainActor.run { _ = NSWorkspace.shared.open(file) }
         } catch {
            Logger.app.error("writing the log failed: \(error.localizedDescription, privacy: .public)")
         }
      }
   }
}

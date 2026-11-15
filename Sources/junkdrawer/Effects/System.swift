import AppKit
import Carbon.HIToolbox
import JunkdrawerCore
import os

/// The commands that act on the system: sleep, the session, the displays,
/// the lock and the Trash.
@MainActor
enum System {
   /// Time for focus to go back to the app in front after the panel hid,
   /// as the inserter waits.
   private static let delay = 0.05

   static func perform(_ command: Command) -> Outcome {
      switch command {
      case .sleep: tellLoginWindow(kAESleep)
      // The dialogs with their countdown, so the system asks first.
      case .restart: tellLoginWindow(kAEShowRestartDialog)
      case .shutDown: tellLoginWindow(kAEShowShutdownDialog)
      case .logOut: tellLoginWindow(kAELogOut)
      case .sleepDisplays: run("/usr/bin/pmset", ["displaysleepnow"])
      case .lockScreen: return lockScreen()
      case .emptyTrash: return emptyTrash()
      case .reload, .editBookmarks, .showLogs, .settings, .statistics, .quit:
         Logger.app.error("\(command.rawValue, privacy: .public) is not a system command")
      }
      return .done
   }

   private static func tellLoginWindow(_ id: AEEventID) {
      let event = NSAppleEventDescriptor(
         eventClass: AEEventClass(kCoreEventClass), eventID: id,
         targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.apple.loginwindow"),
         returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
      )
      do {
         try event.sendEvent(options: .noReply, timeout: TimeInterval(kAEDefaultTimeout))
      } catch {
         Logger.app.error("telling loginwindow failed with \((error as NSError).code, privacy: .public)")
      }
   }

   /// ⌃⌘Q, the system's own shortcut.
   private static func lockScreen() -> Outcome {
      guard Accessibility.isTrusted() else { return .noAccess }
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
         let source = CGEventSource(stateID: .hidSystemState)
         for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_Q), keyDown: down)
            event?.flags = [.maskControl, .maskCommand]
            event?.post(tap: .cghidEventTap)
         }
      }
      return .done
   }

   /// Says first whether junkdrawer may control Finder, without asking.
   /// Once refused, Privacy & Security opens at Automation instead. The
   /// event goes off the main thread, since the first time macOS asks and
   /// the send waits for the answer.
   private static func emptyTrash() -> Outcome {
      let finder = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
      let permission = finder.aeDesc.map { AEDeterminePermissionToAutomateTarget($0, typeWildCard, typeWildCard, false) } ?? noErr
      guard permission != errAEEventNotPermitted else {
         Logger.app.error("not allowed to control Finder")
         openAutomationSettings()
         return .noAutomation
      }
      Task.detached {
         let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kAEFinderSuite), eventID: AEEventID(kAEEmptyTrash),
            targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder"),
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
         )
         do {
            try event.sendEvent(options: .waitForReply, timeout: 60)
         } catch {
            Logger.app.error("emptying the Trash failed with \((error as NSError).code, privacy: .public)")
         }
      }
      return permission == noErr ? .done : .pending
   }

   private static func openAutomationSettings() {
      let pane = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
      if let url = URL(string: pane) { NSWorkspace.shared.open(url) }
   }

   private static func run(_ path: String, _ arguments: [String]) {
      Task.detached {
         let process = Process()
         process.executableURL = URL(fileURLWithPath: path)
         process.arguments = arguments
         do {
            try process.run()
         } catch {
            Logger.app.error("running \(path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
         }
      }
   }
}

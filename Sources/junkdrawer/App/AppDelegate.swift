import AppKit
import JunkdrawerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
   private let loginItem = LoginItem()
   private var hotKey: HotKey?

   func applicationDidFinishLaunching(_ notification: Notification) {
      // No Dock icon and no visible menu bar, also when run as a bare binary.
      NSApp.setActivationPolicy(.accessory)

      // Milestone 01/06: replace the log line with the panel's toggle, and add
      // the single-copy and SIGTERM handling from junknote's AppDelegate.
      let hotKey = HotKey { NSLog("Junkdrawer: hotkey pressed") }
      do {
         try hotKey.register(.toggle)
      } catch {
         NSLog("Junkdrawer: registering the global shortcut failed with status \(error.status)")
      }
      self.hotKey = hotKey
      loginItem.registerOnFirstLaunch()
   }

   /// Opening the app again while it runs will show the panel, in case the
   /// hotkey is taken or broken.
   func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
      NSLog("Junkdrawer: reopened")
      return false
   }
}

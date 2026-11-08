import AppKit
import JunkdrawerCore
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
   private let loginItem = LoginItem()
   private var panel: PanelController?
   private var hotKey: HotKey?
   private var termination: (any DispatchSourceSignal)?

   func applicationDidFinishLaunching(_ notification: Notification) {
      // Only one process can hold the hotkey. Reopening the copy that runs
      // shows its panel, as opening the app again always does.
      if let running = otherCopy()?.bundleURL {
         NSWorkspace.shared.openApplication(at: running, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
         }
         return
      }
      quitOnTermination()
      // No Dock icon and no visible menu bar, also when run as a bare binary.
      NSApp.setActivationPolicy(.accessory)

      let panel = PanelController()
      let hotKey = HotKey { panel.toggle() }
      do {
         try hotKey.register(.toggle)
      } catch {
         Logger.app.error("registering the global shortcut failed with status \(error.status, privacy: .public)")
      }
      self.panel = panel
      self.hotKey = hotKey
      loginItem.registerOnFirstLaunch()
   }

   /// Opening the app again while it runs shows the panel, in case the
   /// hotkey is taken or broken.
   func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
      panel?.show()
      return false
   }

   /// Another process of this app, wherever its bundle is, that launched
   /// before this one. Two copies starting together would otherwise each
   /// see the other and both quit.
   private func otherCopy() -> NSRunningApplication? {
      guard let id = Bundle.main.bundleIdentifier else { return nil }
      let launched = { (app: NSRunningApplication) in (app.launchDate ?? .distantPast, app.processIdentifier) }
      return NSRunningApplication.runningApplications(withBundleIdentifier: id).first { launched($0) < launched(.current) }
   }

   /// A `SIGTERM`, as `pkill` sends, quits like `⌘Q` rather than killing
   /// the process.
   private func quitOnTermination() {
      signal(SIGTERM, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
      source.setEventHandler {
         MainActor.assumeIsolated { NSApp.terminate(nil) }
      }
      source.resume()
      termination = source
   }
}

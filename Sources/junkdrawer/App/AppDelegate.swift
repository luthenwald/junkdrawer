import AppKit
import JunkdrawerCore
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
   private let loginItem = LoginItem()
   private let settings = Settings()
   private var settingsWindow: SettingsWindow?
   private var panel: PanelController?
   private var library: Library?
   private var shortcut: GlobalShortcut?
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
      // So Show logs always has the current run to show.
      Logger.app.notice("started \(Bundle.main.bundlePath, privacy: .public)")
      // No Dock icon and no visible menu bar, also when run as a bare binary.
      NSApp.setActivationPolicy(.accessory)

      let panel = PanelController(usage: UsageStore(), settings: settings)
      let library = Library(settings: settings) { index, icons in panel.update(index: index, icons: icons) }
      let shortcut = GlobalShortcut(settings: settings) { panel.toggle() }
      let settingsWindow = SettingsWindow(settings: settings, loginItem: loginItem, shortcut: shortcut)
      let effects = Effects(reload: { library.reload() }, openSettings: { settingsWindow.show() }, bookmarksFile: { library.bookmarksFile })
      let confirmation = Confirmation()
      panel.perform = { [unowned panel] item, action in
         let outcome = effects.perform(action)
         if let text = item.confirmation(for: action, outcome: outcome) { confirmation.show(text, on: panel.screen) }
      }
      panel.notify = { [unowned panel] text in confirmation.show(text, on: panel.screen) }
      self.library = library
      self.settingsWindow = settingsWindow
      track { [settings] in NSApp.appearance = settings.appearance.nsAppearance }
      self.panel = panel
      self.shortcut = shortcut
      loginItem.registerOnFirstLaunch()
      Logger.app.notice("login item \(self.loginItem.isEnabled ? "enabled" : "not enabled", privacy: .public)")
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

import Foundation

/// The first-order panes of System Settings, in the order of its sidebar
/// (`Sidebar124.plist` in the app's resources), with the titles the
/// sidebar shows, plus iCloud from the Apple Account pane. Panes that
/// appear only with some hardware or accounts, such as Headphones or
/// Classroom, are left out.
public enum SystemSettings {
   /// A pane's sidebar title, the identifier its URL opens, and other words
   /// that find it.
   struct Pane {
      let title: String
      let identifier: String
      var keywords: String = ""
   }

   static let panes: [Pane] = [
      Pane(title: "Apple Account", identifier: "com.apple.systempreferences.AppleIDSettings", keywords: "apple id"),
      Pane(title: "Wi‑Fi", identifier: "com.apple.wifi-settings-extension", keywords: "wifi wireless"),
      Pane(title: "Bluetooth", identifier: "com.apple.BluetoothSettings"),
      Pane(title: "Network", identifier: "com.apple.Network-Settings.extension", keywords: "ethernet firewall proxy"),
      Pane(title: "VPN", identifier: "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension"),
      Pane(title: "Battery", identifier: "com.apple.Battery-Settings.extension", keywords: "energy power"),
      Pane(title: "General", identifier: "com.apple.systempreferences.GeneralSettings", keywords: "about software update storage"),
      Pane(title: "Wallpaper", identifier: "com.apple.Wallpaper-Settings.extension", keywords: "background screen saver"),
      Pane(title: "Accessibility", identifier: "com.apple.Accessibility-Settings.extension", keywords: "zoom voiceover"),
      Pane(title: "Appearance", identifier: "com.apple.Appearance-Settings.extension", keywords: "dark light mode"),
      Pane(title: "Siri", identifier: "com.apple.Siri-Settings.extension", keywords: "apple intelligence ai assistant"),
      Pane(title: "Menu Bar", identifier: "com.apple.ControlCenter-Settings.extension", keywords: "control center"),
      Pane(title: "Desktop & Dock", identifier: "com.apple.Desktop-Settings.extension", keywords: "dock mission control hot corners stage manager widgets"),
      Pane(title: "Displays", identifier: "com.apple.Displays-Settings.extension", keywords: "monitor screen resolution night shift"),
      Pane(title: "Spotlight", identifier: "com.apple.Spotlight-Settings.extension", keywords: "search"),
      Pane(title: "Notifications", identifier: "com.apple.Notifications-Settings.extension"),
      Pane(title: "Sound", identifier: "com.apple.Sound-Settings.extension", keywords: "audio volume output input"),
      Pane(title: "Focus", identifier: "com.apple.Focus-Settings.extension", keywords: "do not disturb"),
      Pane(title: "Screen Time", identifier: "com.apple.Screen-Time-Settings.extension"),
      Pane(title: "Lock Screen", identifier: "com.apple.Lock-Screen-Settings.extension", keywords: "screen saver"),
      Pane(title: "Privacy & Security", identifier: "com.apple.settings.PrivacySecurity.extension", keywords: "permissions camera microphone full disk automation filevault"),
      Pane(title: "Touch ID & Password", identifier: "com.apple.Touch-ID-Settings.extension", keywords: "fingerprint"),
      Pane(title: "Users & Groups", identifier: "com.apple.Users-Groups-Settings.extension", keywords: "accounts"),
      Pane(title: "Internet Accounts", identifier: "com.apple.Internet-Accounts-Settings.extension", keywords: "mail"),
      Pane(title: "Game Center", identifier: "com.apple.Game-Center-Settings.extension"),
      Pane(title: "iCloud", identifier: "com.apple.systempreferences.AppleIDSettings:icloud", keywords: "storage drive"),
      Pane(title: "Wallet & Apple Pay", identifier: "com.apple.WalletSettingsExtension"),
      Pane(title: "Keyboard", identifier: "com.apple.Keyboard-Settings.extension", keywords: "shortcuts input sources dictation"),
      Pane(title: "Mouse", identifier: "com.apple.Mouse-Settings.extension"),
      Pane(title: "Trackpad", identifier: "com.apple.Trackpad-Settings.extension", keywords: "gestures"),
      Pane(title: "Printers & Scanners", identifier: "com.apple.Print-Scan-Settings.extension", keywords: "printer scanner"),
   ]

   /// The URL that opens a pane.
   static func url(_ identifier: String) -> URL {
      URL(string: "x-apple.systempreferences:" + identifier)!
   }

   /// One row per pane, matched like apps.
   public static let items: [Item] = panes.map { pane in
      Item(
         id: "set:\(pane.identifier)", kind: .setting, title: pane.title, subtitle: "",
         keywords: pane.keywords,
         trailing: "settings", primary: .openURL(url(pane.identifier)), secondary: .openURL(url(pane.identifier))
      )
   }
}

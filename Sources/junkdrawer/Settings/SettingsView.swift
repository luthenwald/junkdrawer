import SwiftUI

struct SettingsView: View {
   @Bindable var settings: Settings
   let loginItem: LoginItem
   let shortcut: GlobalShortcut

   var body: some View {
      VStack(spacing: 0) {
         Form {
            Section("General") {
               LabeledContent("Show or hide") {
                  ShortcutRecorder(current: shortcut.current, notice: shortcut.notice, hotKey: shortcut) { result in
                     guard case .recorded(let recorded) = result else { return nil }
                     return shortcut.change(to: recorded)
                  }
                  Restore(isShown: settings.shortcut != .toggle) { _ = shortcut.change(to: .toggle) }
               }
               Toggle("Launch at login", isOn: Binding(get: { loginItem.isEnabled }, set: loginItem.set))
            }
            Section("Appearance") {
               Picker("Appearance", selection: $settings.appearance) {
                  ForEach(Appearance.allCases, id: \.self) { Text($0.rawValue.capitalized) }
               }
               .pickerStyle(.segmented)
               .labelsHidden()
               .frame(maxWidth: .infinity)
            }
         }
         .formStyle(.grouped)
         .scrollDisabled(true)
         .fixedSize(horizontal: false, vertical: true)

         if let version {
            Text("Junkdrawer \(version)")
               .font(.caption)
               .foregroundStyle(.secondary)
               .padding(.bottom, 20)
         }
      }
      .frame(width: 420)
      // Grayscale, as the panel is.
      .tint(.gray)
   }

   /// Brings back ⌘Space. Hidden rather than removed when the shortcut is
   /// the default, so the recorder stays where it is.
   private struct Restore: View {
      let isShown: Bool
      let action: () -> Void

      var body: some View {
         Button(action: action) { Image(systemName: "arrow.counterclockwise") }
            .buttonStyle(.borderless)
            .help("Restore \(Shortcut.toggle.description)")
            .opacity(isShown ? 1 : 0)
            .disabled(!isShown)
      }
   }

   /// From the bundle, so a bare binary from `swift build` shows none.
   private var version: String? {
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
   }
}

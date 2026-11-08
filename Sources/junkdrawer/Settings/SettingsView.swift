import SwiftUI

struct SettingsView: View {
   @Bindable var settings: Settings
   let loginItem: LoginItem

   var body: some View {
      VStack(spacing: 0) {
         Form {
            Section("General") {
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

   /// From the bundle, so a bare binary from `swift build` shows none.
   private var version: String? {
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
   }
}

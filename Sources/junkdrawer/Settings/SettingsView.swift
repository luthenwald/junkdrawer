import AppKit
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
               LabeledContent("Keep the query") {
                  Text(settings.keepSeconds == 0 ? "Off" : "\(settings.keepSeconds) s")
                     .monospacedDigit()
                  Stepper("Keep the query", value: $settings.keepSeconds, in: 0...60)
                     .labelsHidden()
               }
               .help("How long a hidden panel remembers its query, so a look-up is still there when you come back")
               LabeledContent("Panel position") {
                  Button("Reset") { settings.positions = [:] }
                     .disabled(settings.positions.isEmpty)
                     .help("Show the panel centred near the top again")
               }
            }
            Section {
               ForEach(settings.appFolders, id: \.self) { folder in
                  HStack {
                     PathText(folder)
                     Spacer()
                     Button { settings.appFolders.removeAll { $0 == folder } } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                        .help("Remove")
                  }
               }
               Button("Add Folder…", action: addFolder)
            } header: {
               Text("App folders")
            } footer: {
               Text("Searched one level deep, besides the Applications folders.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
            }
            Section("Bookmarks file") {
               HStack {
                  PathText(settings.bookmarksURL.path)
                  Spacer()
                  if settings.bookmarksFile != nil { Button("Use Default") { settings.bookmarksFile = nil } }
                  Button("Change…", action: chooseBookmarks)
               }
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

   private func addFolder() {
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = true
      panel.message = "Choose folders to search for apps."
      panel.prompt = "Add"
      guard panel.runModal() == .OK else { return }
      let chosen = panel.urls.map(\.standardizedFileURL.path)
      settings.appFolders += chosen.filter { !settings.appFolders.contains($0) }
   }

   private func chooseBookmarks() {
      let panel = NSOpenPanel()
      panel.canChooseFiles = true
      panel.canChooseDirectories = false
      panel.message = "Choose a bookmarks file: one URL per line, then the title and optional #tags."
      panel.prompt = "Choose"
      panel.directoryURL = settings.bookmarksURL.deletingLastPathComponent()
      guard panel.runModal() == .OK, let file = panel.url else { return }
      settings.bookmarksFile = file.standardizedFileURL.path == BookmarksSource.defaultFile.path ? nil : file.standardizedFileURL.path
   }

   /// A path with `~` for the home folder, cut in the middle when long.
   private struct PathText: View {
      private static let home = FileManager.default.homeDirectoryForCurrentUser.path
      let path: String

      init(_ path: String) {
         self.path = path.hasPrefix(Self.home) ? "~" + path.dropFirst(Self.home.count) : path
      }

      var body: some View {
         Text(path)
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(.secondary)
            .help(path)
      }
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

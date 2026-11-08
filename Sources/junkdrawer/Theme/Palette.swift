import AppKit

/// The grayscale tokens of the spec. Each resolves light or dark from the
/// appearance it is drawn in, which follows the system.
extension NSColor {
   static let background = gray(light: 0xFA, dark: 0x16)
   /// The query, titles and glyphs.
   static let text = gray(light: 0x2E, dark: 0xDA)
   /// Subtitles, right labels, the footer and the placeholder.
   static let secondary = gray(light: 0x6A, dark: 0x8A)
   /// The selected row.
   static let row = gray(light: 0xED, dark: 0x21)
   /// Hairlines, the panel border and selected text.
   static let line = gray(light: 0xDD, dark: 0x2C)

   private static func gray(light: UInt8, dark: UInt8) -> NSColor {
      NSColor(name: nil) { appearance in
         let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
         return NSColor(white: CGFloat(isDark ? dark : light) / 255, alpha: 1)
      }
   }
}

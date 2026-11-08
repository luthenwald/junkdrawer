import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import JunkdrawerCore

/// App icons without colour, as the grayscale design asks.
enum AppIcons {
   /// Pixels per side: the 28 point cell at 2x.
   private static let side = 56
   private static let context = CIContext()

   /// Gray icons for the apps among `items`, by item id.
   static func render(_ items: [Item]) -> [String: CGImage] {
      Dictionary(uniqueKeysWithValues: items.compactMap { item in
         guard case .openApp(let url) = item.primary, let image = gray(url) else { return nil }
         return (item.id, image)
      })
   }

   private static func gray(_ url: URL) -> CGImage? {
      // Through the link, or the icon carries the alias arrow (Safari).
      guard let icon = drawn(NSWorkspace.shared.icon(forFile: url.resolvingSymlinksInPath().path)) else { return nil }
      let filter = CIFilter.colorControls()
      filter.inputImage = CIImage(cgImage: icon)
      filter.saturation = 0
      guard let output = filter.outputImage else { return nil }
      return context.createCGImage(output, from: output.extent)
   }

   /// The icon drawn at `side` pixels; asking for a representation alone
   /// returns the nearest larger one.
   private static func drawn(_ image: NSImage) -> CGImage? {
      guard let bitmap = CGContext(
         data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else { return nil }
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
      image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
      NSGraphicsContext.restoreGraphicsState()
      return bitmap.makeImage()
   }
}

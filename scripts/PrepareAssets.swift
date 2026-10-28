// Make only the tvOS assets that require opacity fully opaque before actool runs.
// Foreground and middle parallax layers retain their transparency.
import Foundation
import CoreGraphics
import ImageIO

@main
struct PrepareAssets {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(domain: "PrepareAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supply the Assets.xcassets directory."])
        }
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw NSError(domain: "PrepareAssets", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot enumerate asset directory."])
        }
        var count = 0
        for case let file as URL in enumerator {
            guard file.pathExtension.lowercased() == "png" else { continue }
            let components = file.pathComponents
            let requiresOpacity = components.contains("Back.imagestacklayer") || components.contains(where: {
                $0.hasPrefix("Top Shelf Image") && $0.hasSuffix(".imageset")
            })
            guard requiresOpacity else { continue }
            guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: nil, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
                throw NSError(domain: "PrepareAssets", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot decode \(file.path)."])
            }
            let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(bounds)
            context.draw(image, in: bounds)
            let data = NSMutableData()
            guard let opaque = context.makeImage(),
                  let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
                throw NSError(domain: "PrepareAssets", code: 4)
            }
            CGImageDestinationAddImage(destination, opaque, nil)
            guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "PrepareAssets", code: 5) }
            // Verify the encoded file has no alpha channel and the dimensions did not change.
            guard let checkSource = CGImageSourceCreateWithData(data, nil),
                  let check = CGImageSourceCreateImageAtIndex(checkSource, 0, nil),
                  [.none, .noneSkipFirst, .noneSkipLast].contains(check.alphaInfo),
                  check.width == image.width, check.height == image.height else {
                throw NSError(domain: "PrepareAssets", code: 6, userInfo: [NSLocalizedDescriptionKey: "Opacity verification failed for \(file.path)."])
            }
            try (data as Data).write(to: file, options: .atomic)
            count += 1
            print("Prepared opaque asset: \(file.path)")
        }
        guard count > 0 else { throw NSError(domain: "PrepareAssets", code: 7, userInfo: [NSLocalizedDescriptionKey: "No required background/shelf assets were found."]) }
        print("Verified \(count) opaque tvOS background/shelf assets.")
    }
}

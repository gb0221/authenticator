import Foundation
import Vision
import AppKit

enum QRImageScanner {
    /// Returns every QR string found in an image file at `url`.
    static func scan(url: URL) -> [String] {
        guard let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return [] }
        return scan(cgImage: cg)
    }

    static func scan(cgImage: CGImage) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        let results = request.results ?? []
        return results.compactMap { $0.payloadStringValue }
    }
}

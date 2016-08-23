// The MIT License (MIT)
//
// Copyright (c) 2016 Alexander Grebenyuk (github.com/kean).

import UIKit
import FLAnimatedImage
import Nuke
import ImageIO

public class AnimatedImage: UIImage {
    public let data: Data! // it's nonnull

    public init(data: Data, poster: CGImage) {
        self.data = data
        super.init(cgImage: poster, scale: 1, orientation: .up)
    }

    public required init?(coder decoder: NSCoder) {
        self.data = nil // makes me sad
        super.init(coder: decoder)
    }

    public required convenience init(imageLiteralResourceName name: String) {
        fatalError("init(imageLiteral:) has not been implemented")
    }
}

/// Composes multiple image decoders.
public class DataDecoderComposition: DataDecoding {
    /// Image decoders that the receiver was initialized with.
    public let decoders: [DataDecoding]

    /// Composes multiple image decoders.
    public init(decoders: [DataDecoding]) {
        self.decoders = decoders
    }

    /// Decoders are applied in an order in which they are present in the decoders array. The decoding stops when one of the decoders produces an image.
    public func decode(data: Data, response: URLResponse) -> Image? {
        for decoder in decoders {
            if let image = decoder.decode(data: data, response: response) {
                return image
            }
        }
        return nil
    }
}

/** Creates instances of `AnimatedImage` class from the given data. Checks if the image data is in a GIF image format, otherwise returns nil.
 */
public class AnimatedImageDecoder: Nuke.DataDecoding {
    public init() {}

    public func decode(data: Data, response: URLResponse) -> Nuke.Image? {
        guard self.isAnimatedGIFData(data) else {
            return nil
        }
        guard let poster = self.posterImage(for: data) else {
            return nil
        }
        return AnimatedImage(data: data, poster: poster)
    }

    public func isAnimatedGIFData(_ data: Data) -> Bool {
        let sigLength = 3
        if data.count < sigLength {
            return false
        }
        var sig = [UInt8](repeating: 0, count: sigLength)
        (data as NSData).getBytes(&sig, length:sigLength)
        return sig[0] == 0x47 && sig[1] == 0x49 && sig[2] == 0x46
    }

    private func posterImage(for data: Data) -> CGImage? {
        if let source = CGImageSourceCreateWithData(data as CFData, nil) {
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        return nil
    }
}

public struct AnimatedImageProcessor: Nuke.Processing {
    fileprivate let processor: Nuke.AnyProcessor

    public init(processor: Nuke.AnyProcessor) {
        self.processor = processor
    }

    public func process(_ image: Image) -> Image? {
        if image is AnimatedImage {
            return image
        }
        return self.processor.process(image)
    }
}

/// Returns true if both decompressors have the same `targetSize` and `contentMode`.
public func ==(lhs: AnimatedImageProcessor, rhs: AnimatedImageProcessor) -> Bool {
    return lhs.processor == lhs.processor
}

/** Extension that adds image loading capabilities to the FLAnimatedImageView.
 */
public extension FLAnimatedImageView {
    /// Displays a given image. Starts animation if image is an instance of AnimatedImage.
    public func nk_display(_ image: Image?) {
        guard image != nil else {
            self.animatedImage = nil
            self.image = nil
            return
        }
        if let image = image as? AnimatedImage {
            // Display poster image immediately
            self.image = image

            // Start playback after we prefare FLAnimatedImage for rendering
            DispatchQueue.global().async {
                let animatedImage = FLAnimatedImage(animatedGIFData: image.data)
                DispatchQueue.main.async {
                    if self.image === image { // Still displaying the same poster image
                        self.animatedImage = animatedImage
                    }
                }
            }
        } else {
            self.image = image
        }
    }
}

public extension Nuke.Cache {
    /// Updates Cache cost block by adding special handling of `AnimatedImages`.
    public func preparedForAnimatedImages() -> Self {
        let cost = self.cost
        self.cost = {
            var val = cost($0)
            if let animatedImage = $0 as? AnimatedImage {
                val += animatedImage.data.count
            }
            return val
        }
        return self
    }
}

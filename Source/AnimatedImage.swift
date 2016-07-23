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

/** Creates instances of `AnimatedImage` class from the given data. Checks if the image data is in a GIF image format, otherwise returns nil.
 */
public class AnimatedImageDecoder: Nuke.DataDecoding {
    public init() {}

    public func decode(data: Data, response: URLResponse) -> Image? {
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
        if let source = CGImageSourceCreateWithData(data, nil) {
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        return nil
    }
    
}

/** Extension that adds image loading capabilities to the FLAnimatedImageView.
 */
public extension FLAnimatedImageView {
    /// Displays a given image. Starts animation if image is an instance of AnimatedImage.
    public override func nk_display(_ image: Image?) {
        guard image != nil else {
            self.animatedImage = nil
            self.image = nil
            return
        }
        if let image = image as? AnimatedImage {
            // Display poster image immediately
            self.image = image

            // Start playback after we prefare FLAnimatedImage for rendering
            DispatchQueue.global(attributes: DispatchQueue.GlobalAttributes.qosDefault).async {
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

/** Memory cache that is aware of animated images. Can be used for both single-frame and animated images.
 */
public class AnimatedImageCache: Nuke.ImageCache {

    /** Can be used to disable storing animated images. Default value is true (storage is allowed).
     */
    public var allowsAnimatedImagesStorage = true

    public override func setImage(_ image: Image, for request: ImageRequest) {
        if !self.allowsAnimatedImagesStorage && image is AnimatedImage {
            return
        }
        super.setImage(image, for: request)
    }

    public override func cost(for image: Image) -> Int {
        if let animatedImage = image as? AnimatedImage {
            return animatedImage.data.count + super.cost(for: image)
        }
        return super.cost(for: image)
    }
}

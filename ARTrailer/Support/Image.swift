//
//  Image.swift
//  ARTrailer
//
//  Created by Wai Ting Cheung on 10/8/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import Accelerate

/// - Tag: PreprocessImage
func preprocessImage(image: UIImage) -> UIImage {
    var resultImage = image.fixOrientation().g8_grayScale()?.g8_blackAndWhite()
    resultImage = resultImage?.resizeVI(size: CGSize(width: image.size.width * 3, height: image.size.height * 3))!
    return resultImage!
}

/// - Tag: RunOCRonImage
func runOCRonImage(imageRect: CGRect, ciImage: CIImage, tesseract: G8Tesseract) -> String {
    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(ciImage, from: imageRect) else {
        return ""
    }
    let uiImage = preprocessImage(image: UIImage(cgImage: cgImage))
    tesseract.image = uiImage
    tesseract.recognize()
    guard let text = tesseract.recognizedText else {
        return ""
    }
    return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
}

// Convert device orientation to image orientation for use by Vision analysis.
extension CGImagePropertyOrientation {
    init(_ deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portraitUpsideDown: self = .left
        case .landscapeLeft: self = .up
        case .landscapeRight: self = .down
        default: self = .right
        }
    }
}

extension UIImage {
    /// - Tag: UIImageExtension
    func toGrayScale() -> UIImage {
        let context = CIContext(options: nil)
        let currentFilter = CIFilter(name: "CIPhotoEffectNoir")
        currentFilter!.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        let output = currentFilter!.outputImage
        let cgimg = context.createCGImage(output!,from: output!.extent)
        return UIImage(cgImage: cgimg!)
    }
    
    func binarise() -> UIImage {
        let glContext = EAGLContext(api: .openGLES2)!
        let ciContext = CIContext(eaglContext: glContext, options: [kCIContextOutputColorSpace : NSNull()])
        let filter = CIFilter(name: "CIPhotoEffectMono")
        filter!.setValue(CIImage(image: self), forKey: "inputImage")
        let outputImage = filter!.outputImage
        let cgimg = ciContext.createCGImage(outputImage!, from: (outputImage?.extent)!)
        
        return UIImage(cgImage: cgimg!)
    }
    
    func scaleImage() -> UIImage {
        let maxDimension: CGFloat = 640
        var scaledSize = CGSize(width: maxDimension, height: maxDimension)
        var scaleFactor: CGFloat
        
        if self.size.width > self.size.height {
            scaleFactor = self.size.height / self.size.width
            scaledSize.width = maxDimension
            scaledSize.height = scaledSize.width * scaleFactor
        } else {
            scaleFactor = self.size.width / self.size.height
            scaledSize.height = maxDimension
            scaledSize.width = scaledSize.height * scaleFactor
        }
        
        UIGraphicsBeginImageContext(scaledSize)
        self.draw(in: CGRect(x: 0, y: 0, width: scaledSize.width, height: scaledSize.height))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage!
    }
    
    func orientate(img: UIImage) -> UIImage {
        if (img.imageOrientation == UIImageOrientation.up) {
            return img;
        }
        
        UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
        let rect = CGRect(x: 0, y: 0, width: img.size.width, height: img.size.height)
        img.draw(in: rect)
        
        let normalizedImage : UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
    
    func resizeVI(size:CGSize) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        var format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: nil, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue), version: 0, decode: nil, renderingIntent: .defaultIntent)
        
        var sourceBuffer = vImage_Buffer()
        defer {
            free(sourceBuffer.data)
        }
        
        var error = vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, cgImage, numericCast(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        
        // create a destination buffer
        let scale = self.scale
        let destWidth = Int(size.width)
        let destHeight = Int(size.height)
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let destBytesPerRow = destWidth * bytesPerPixel
        
        let destData = UnsafeMutablePointer<UInt8>.allocate(capacity: destHeight * destBytesPerRow)
        defer {
            destData.deallocate()
        }
        var destBuffer = vImage_Buffer(data: destData, height: vImagePixelCount(destHeight), width: vImagePixelCount(destWidth), rowBytes: destBytesPerRow)
        
        // scale the image
        error = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, numericCast(kvImageHighQualityResampling))
        guard error == kvImageNoError else { return nil }
        
        // create a CGImage from vImage_Buffer
        var destCGImage = vImageCreateCGImageFromBuffer(&destBuffer, &format, nil, nil, numericCast(kvImageNoFlags), &error)?.takeRetainedValue()
        guard error == kvImageNoError else { return nil }
        
        // create a UIImage
        let resizedImage = destCGImage.flatMap {
            UIImage(cgImage: $0, scale: 0.0, orientation: self.imageOrientation)
        }
        
        destCGImage = nil
        return resizedImage
    }
    
    func invertColor() -> UIImage {
        let context = CIContext(options: nil)
        let currentFilter = CIFilter(name: "CIColorInvert")
        currentFilter!.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        let output = currentFilter!.outputImage
        let cgimg = context.createCGImage(output!,from: output!.extent)
        return UIImage(cgImage: cgimg!)
    }
}

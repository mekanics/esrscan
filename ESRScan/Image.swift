//
//  Various image utilities
//
//  Copyright © 2015 Michael Weibel. All rights reserved.
//  License: MIT
//

import UIKit
import GPUImage



func getWhiteRectangle(image: UIImage) -> CGRect {
    let img = image.CGImage
    let width = CGImageGetWidth(img)
    let height = CGImageGetHeight(img)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8
    let rawData = UnsafeMutablePointer<UInt8>.alloc(height * width * 4)
    rawData.initialize(0)

    let context = CGBitmapContextCreate(rawData, width, height, bitsPerComponent, bytesPerRow, colorSpace, CGImageAlphaInfo.PremultipliedLast.rawValue | CGBitmapInfo.ByteOrder32Big.rawValue)
    CGContextDrawImage(context, CGRectMake(0, 0, CGFloat(width), CGFloat(height)), img)

    var y1 = 0
    let y2 = height-1
    var x1 = 0
    let x2 = width-1

    // it anyway needs some space, skip testing unneeded colors
    // TODO: probably starts too late, but the results are somehow better with a bigger image still.
    // might need to improve on deskewing the image before/after cropping.
    let startY = y2 - (height / 3)
    let startX = width / 3

    for y in startY.stride(to: 0, by: -5) {
        let colors = getColors(rawData, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel, x: x2, y: y)
        let hsv = colors.ToHSV()
        if hsv.isOrange() {
            y1 = y - 10
            break
        }
    }

    for x in startX.stride(to: 0, by: -5) {
        let colors = getColors(rawData, bytesPerRow: bytesPerRow, bytesPerPixel: bytesPerPixel, x: x, y: y2)
        let hsv = colors.ToHSV()
        if hsv.isOrange() {
            x1 = x - 10
            break
        }
    }

    rawData.destroy()

    let rect = CGRectMake(CGFloat(x1), CGFloat(y1), CGFloat(x2 - x1), CGFloat(y2 - y1))
    return rect
}

func drawRect(image: UIImage, rect: CGRect) -> UIImage {
    UIGraphicsBeginImageContext(image.size)
    image.drawAtPoint(CGPointZero)
    let ctx = UIGraphicsGetCurrentContext()
    UIColor.redColor().setStroke()

    CGContextStrokeRect(ctx, rect)
    let retImage = UIGraphicsGetImageFromCurrentImageContext()

    UIGraphicsEndImageContext()

    return retImage
}

struct HSVColors {
    var hue: Double
    var sat: Double
    var val: Double

    func isOrange() -> Bool {
        return self.hue >= 0 && self.hue <= 35 && self.val >= 150 && self.sat >= 0.25
    }
}

struct Colors{
    var red : UInt16
    var green: UInt16
    var blue: UInt16

    // TODO: Improve algo or actually make it correct.
    func ToHSV() -> HSVColors {
        var hsv = HSVColors(hue: 0, sat: 0, val: 0)

        let red = Double(self.red)
        let green = Double(self.green)
        let blue = Double(self.blue)

        let rgbMin = min(red, min(green, blue))
        let rgbMax = max(red, max(green, blue))

        let diff = rgbMax - rgbMin

        if (rgbMax == rgbMin) {
            hsv.hue = 0;
        } else if (rgbMax == red) {
            let hue = 60.0 * ((green - blue) / diff)
            hsv.hue = hue % 360.0;
        } else if (rgbMax == green) {
            hsv.hue = 60.0 * ((blue - red) / diff) + 120.0
        } else if (rgbMax == blue) {
            hsv.hue = 60.0 * ((red - green) / diff) + 240.0
        }
        // FIXME: negative shouldn't happen, algo is not good enough.
        hsv.hue = abs(hsv.hue)
        hsv.val = rgbMax;
        if (rgbMax == 0) {
            hsv.sat = 0;
        } else {
            hsv.sat = diff / hsv.val;
        }
        return hsv
    }
}
func getColors(rawData : UnsafeMutablePointer<UInt8>, bytesPerRow : Int, bytesPerPixel : Int, x: Int, y: Int) -> Colors {
    let byteIndex = (bytesPerRow * y) + x * bytesPerPixel;
    let red = UInt16(rawData[byteIndex])
    let green = UInt16(rawData[byteIndex + 1])
    let blue = UInt16(rawData[byteIndex + 2])
    return Colors(red: red, green: green, blue: blue)
}
func crop(image: UIImage, cropRect: CGRect) -> UIImage {
    let imageRef = CGImageCreateWithImageInRect(image.CGImage, cropRect);
    return UIImage.init(CGImage: imageRef!)
}

func invert(image: UIImage) -> UIImage {
    let filter = GPUImageColorInvertFilter.init()
    return filter.imageByFilteringImage(image)
}

func adaptiveThreshold(image: UIImage) -> UIImage {
    let threshold = GPUImageAdaptiveThresholdFilter.init()
    threshold.blurRadiusInPixels = 4.0
    return threshold.imageByFilteringImage(image)
}

func preprocessImage(image: UIImage, autoCrop: Bool = true) -> UIImage {
    let rImage = rotate(image)
    if !autoCrop {
        return rImage
    }
    let coords = getWhiteRectangle(rImage)
    if coords.origin.x > 0 || coords.origin.y > 0 {
        return crop(rImage, cropRect: coords)
    }
    return rImage
}

func rotate(src : UIImage) -> UIImage {
    if src.size.height > src.size.width {
        return src.imageRotatedByDegrees(-90, flip: false)
    }

    return src
}

func radians (degrees : Double) -> CGFloat {
    return CGFloat(degrees * M_PI/180);
}

func scaleImage(image: UIImage, maxDimension: CGFloat) -> UIImage {
    var scaledSize = CGSize(width: maxDimension, height: maxDimension)
    var scaleFactor: CGFloat

    if image.size.width > image.size.height {
        scaleFactor = image.size.height / image.size.width
        scaledSize.width = maxDimension
        scaledSize.height = scaledSize.width * scaleFactor
    } else {
        scaleFactor = image.size.width / image.size.height
        scaledSize.height = maxDimension
        scaledSize.width = scaledSize.height * scaleFactor
    }

    UIGraphicsBeginImageContext(scaledSize)
    image.drawInRect(CGRectMake(0, 0, scaledSize.width, scaledSize.height))
    let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return scaledImage
}
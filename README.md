# ARTrailer

Identify the movie title from a poster, and use SceneKit to display the movie trailer in AR.

## Overview

This app runs an [ARKit][0] world-tracking session with content displayed in a SceneKit view. The app uses the [Vision][1] framework to find regions of visible texts on camera images, and pass the detected regions to the [Tesseract][2] framework for OCR. After text recognition, the app displays a movie trailer in AR world space.

[0]:https://developer.apple.com/documentation/arkit
[1]:https://developer.apple.com/documentation/vision
[2]:https://github.com/gali8/Tesseract-OCR-iOS

## Demo

![](https://user-images.githubusercontent.com/2617118/44137401-e566504a-a0a2-11e8-8ace-c6191e8ea720.gif)

## Getting Started

ARKit requires iOS 11.0 and a device with an A9 (or later) processor. ARKit is not available in iOS Simulator. Building the sample code requires Xcode 10.0 or later.

## Installation

1. Run `pod install` and open `ARTrailer.xcworkspace`.
2. This app uses the [YouTube Data API](https://developers.google.com/youtube/v3/getting-started) to search for movie trailers. Add the API key to [Keys.plist](ARTrailer/Resources/Keys.plist).

Note: You need [quota](https://developers.google.com/youtube/v3/getting-started#quota) for the YouTube Data API to send a query request. To test it without quota, you may hard code the video id in the YouTube url.

```xml
<plist version="1.0">
<dict>
    <key>YouTubeDataAPI</key>
    <string></string>
</dict>
</plist>
```

## Run the AR Session and Process Camera Images

The `ViewController` class manages the AR session and displays AR overlay content in a SceneKit view. ARKit captures video frames from the camera and provides them to the view controller in the [`session(_:didUpdate:)`](https://github.com/waitingcheung/ARTrailer/blob/a65aab4ef72cc6abe0567e3af926703a8a0fd133/ARTrailer/ViewController.swift#L143) method, which then calls the `processCurrentImage()` method to perform text recognition.

```swift
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    // Do not enqueue other buffers for processing while another Vision task is still running.
    // The camera stream has only a finite amount of buffers available; holding too many buffers for analysis would starve the camera.
    guard currentBuffer == nil, case .normal = frame.camera.trackingState else {
        return
    }

    // Retain the image buffer for Vision processing.
    self.currentBuffer = frame.capturedImage
    processCurrentImage()
}
```

## Serialize Image Processing for Real-Time Performance

The [`processCurrentImage()`](https://github.com/waitingcheung/ARTrailer/blob/a65aab4ef72cc6abe0567e3af926703a8a0fd133/ARTrailer/ViewController.swift#L163) method uses the view controlle's `currentBuffer` property to track whether Vision is currently processing an image before starting another Vision task.

```swift
// Most computer vision tasks are not rotation agnostic so it is important to pass in the orientation of the image with respect to device.
let orientation = CGImagePropertyOrientation(UIDevice.current.orientation)

let requestHandler = VNImageRequestHandler(cvPixelBuffer: currentBuffer!, orientation: orientation)

visionQueue.async {
    do {
    // Release the pixel buffer when done, allowing the next buffer to be processed.
        defer { self.currentBuffer = nil }
        try requestHandler.perform([self.rectangleRequest, self.textRequest])
        self.recognizeTexts(cvPixelBuffer: self.currentBuffer!)
    } catch {
        print("Error: Vision request failed with error \"\(error)\"")
    }
}
```

## Implement the Text Detector

The code's [`textDetectionHandler()`](https://github.com/waitingcheung/ARTrailer/blob/a65aab4ef72cc6abe0567e3af926703a8a0fd133/ARTrailer/ViewController.swift#L97) method and [`rectangleDetectionHandler()`](https://github.com/waitingcheung/ARTrailer/blob/a65aab4ef72cc6abe0567e3af926703a8a0fd133/ARTrailer/ViewController.swift#L118) method detect regions of the movie poster and detect regions of visible texts on the poster.

```swift
func textDetectionHandler(request: VNRequest, error: Error?) {
    guard let observations = request.results else {print("no result"); return}

    let result = observations.map({$0 as? VNTextObservation})
    if result.isEmpty {
        return
    }

    textObservations = result as! [VNTextObservation]
}
```

## Perform Text Recognition

The code's [`recognizeTexts()`](https://github.com/waitingcheung/ARTrailer/blob/a65aab4ef72cc6abe0567e3af926703a8a0fd133/ARTrailer/ViewController.swift#L184) method performs text recognition on the detected text regions.

```swift
func recognizeTexts(cvPixelBuffer: CVPixelBuffer) {
    var ciImage = CIImage(cvPixelBuffer: self.currentBuffer!)
    let transform = ciImage.orientationTransform(for: CGImagePropertyOrientation(rawValue: 6)!)
    ciImage = ciImage.transformed(by: transform)
    let size = ciImage.extent.size
    
    var keywords = ""
    for textObservation in self.textObservations {
        guard let rects = textObservation.characterBoxes else {
        continue
        }
        let (imageRect, xMin, xMax, yMin, yMax) = createImageRect(rects: rects, size: size)
        
        var text = runOCRonImage(imageRect: imageRect, ciImage: ciImage, tesseract: tesseract)
        keywords += " \(text)"
    }
    
    createVideoAnchor()
    textObservations.removeAll()
}
```

The [`runOCROnImage()`](https://github.com/waitingcheung/ARTrailer/blob/a65aab4ef72cc6abe0567e3af926703a8a0fd133/ARTrailer/Support/Image.swift#L20) method uses the Tesseract framework to perform OCR on the preprocessed image. 

```swift
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
    return text.trimmingCharacters(in: CharacterSet.newlines)
}
```

The code's [`preprocessImage()`](https://github.com/waitingcheung/ARTrailer/blob/a65aab4ef72cc6abe0567e3af926703a8a0fd133/ARTrailer/Support/Image.swift#L13) method applis image processing to optimize the camera images of the text regions for OCR.

```swift
func preprocessImage(image: UIImage) -> UIImage {
    var resultImage = image.fixOrientation().g8_grayScale()?.g8_blackAndWhite()
    resultImage = resultImage?.resizeVI(size: CGSize(width: image.size.width * 3, height: image.size.height * 3))!
    return resultImage!
}
```

- Note: The accuracy of text recognition depends on the input image. Refer to the Tesseract [documentation][3] for different techniques in preprocessing images. To implement other image processing methods, add them to the [UIImage](https://github.com/waitingcheung/ARTrailer/blob/a65aab4ef72cc6abe0567e3af926703a8a0fd133/ARTrailer/Support/Image.swift#L46) extension.

[3]:https://github.com/tesseract-ocr/tesseract/wiki/ImproveQuality

## Add a Video in AR

The [`createVideoAnchor()`](https://github.com/waitingcheung/ARTrailer/blob/a65aab4ef72cc6abe0567e3af926703a8a0fd133/ARTrailer/ViewController.swift#L319) methods adds an anchor to the AR session.

```swift
// Create anchor using the camera's current position
if let currentFrame = sceneView.session.currentFrame {
    self.cinemaFrame = currentFrame
    
    var translation = matrix_identity_float4x4
    translation.columns.3.z = -1.5
    let transform = matrix_multiply((cinemaFrame?.camera.transform)!, translation)

    let anchor = ARAnchor(transform: transform)
    sceneView.session.add(anchor: anchor)
}
```

Next, after ARKit automatically creates a SceneKit node for the newly added anchor, the [`renderer(_:didAdd:for:)`](https://github.com/waitingcheung/ARTrailer/blob/a65aab4ef72cc6abe0567e3af926703a8a0fd133/ARTrailer/ViewController.swift#L335) delegate method provides content for that node. In this case, the [`addVideoToSCNNode()`](https://github.com/waitingcheung/ARTrailer/blob/a65aab4ef72cc6abe0567e3af926703a8a0fd133/ARTrailer/Support/Scene.swift#L14) method creates a SpriteKit node for the newly added anchor and plays a video at the anchor.

```swift
func addVideoToSCNNode(url: String, node: SCNNode) {
    let videoNode = SKVideoNode(url: URL(string: url)!)

    let skScene = SKScene(size: CGSize(width: 1280, height: 720))
    skScene.addChild(videoNode)

    videoNode.position = CGPoint(x: skScene.size.width/2, y: skScene.size.height/2)
    videoNode.size = skScene.size

    let tvPlane = SCNPlane(width: 1.0, height: 0.5625)
    tvPlane.firstMaterial?.diffuse.contents = skScene
    tvPlane.firstMaterial?.isDoubleSided = true

    let tvPlaneNode = SCNNode(geometry: tvPlane)
    tvPlaneNode.eulerAngles = SCNVector3(0,GLKMathDegreesToRadians(180),GLKMathDegreesToRadians(-90))
    tvPlaneNode.opacity = 0.9

    videoNode.play()

    node.addChildNode(tvPlaneNode)
}
```

[4]:https://developers.google.com/youtube/v3/getting-started

## References

- [Scene Text Recognition in iOS 11](https://devcrew.io/2017/09/11/scene-text-recognition-ios-11/)
- [Vision in iOS: Text detection and Tesseract recognition](https://medium.com/flawless-app-stories/vision-in-ios-text-detection-and-tesseract-recognition-26bbcd735d8f)
- [Improving the Efficiency of Tesseract OCR through Super Resolution](https://edu.authorcafe.com/academies/7609/improving-the-efficiency-of-tesseract-ocr-through-superresolution)
- [Improving OCR accuracy](https://stb-tester.com/blog/2014/04/14/improving-ocr-accuracy)
- [Playing Videos in Augmented Reality Using ARKit](https://hackernoon.com/playing-videos-in-augmented-reality-using-arkit-7df3db3795b7)

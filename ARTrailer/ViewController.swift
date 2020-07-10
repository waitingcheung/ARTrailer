/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Main view controller for the ARKitVision sample.
 */

import UIKit
import SpriteKit
import SceneKit
import ARKit
import Vision
import YoutubeDirectLinkExtractor
import Alamofire
import SwiftyJSON

class ViewController: UIViewController, ARSessionDelegate, G8TesseractDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    
    // The view controller that displays the status and "restart experience" UI.
    private lazy var statusViewController: StatusViewController = {
        return childViewControllers.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    private lazy var rectangleRequest: VNDetectRectanglesRequest = {
        return VNDetectRectanglesRequest(completionHandler: self.rectangleDetectionHandler)
    }()
    
    private lazy var textRequest: VNDetectTextRectanglesRequest = {
        let request = VNDetectTextRectanglesRequest(completionHandler: self.textDetectionHandler)
        request.reportCharacterBoxes = true
        return request
    }()
    
    private var textObservations = [VNTextObservation]()
    private var rectangleObservations = [VNRectangleObservation]()
    private var tesseract:G8Tesseract = G8Tesseract(language: "eng")
    private var cinemaFrame: ARFrame?
    private var videoLoaded = false
    private var movieTitle = ""
    
    // MARK: - View controller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure and present the SpriteKit scene that draws overlay content.
        let overlayScene = SKScene(size: view.bounds.size)
        sceneView.overlaySKScene = overlayScene
        sceneView.delegate = self
        sceneView.session.delegate = self
        // sceneView.showsStatistics = true
        
        // Hook up status view controller callback.
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartSession()
        }
        
        setupTesseract()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func shouldCancelImageRecognitionForTesseract(tesseract: G8Tesseract!) -> Bool {
        return false // return true if you need to interrupt tesseract before it finishes
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - Tesseract Setup
    func setupTesseract() {
        tesseract.delegate = self
        tesseract.engineMode = .tesseractCubeCombined
        tesseract.charWhitelist = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890()-+*!/?.,@#$%&"
        tesseract.pageSegmentationMode = G8PageSegmentationMode.singleLine
    }
    
    /// - Tag: TextDetectionHandler
    func textDetectionHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results else {print("no result"); return}
        
        let result = observations.map({$0 as? VNTextObservation})
        if result.isEmpty {
            return
        }
        
        textObservations = result as! [VNTextObservation]
        /*
        DispatchQueue.main.async() {
            self.sceneView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            for region in result {
                guard let rg = region else {continue}
                drawRegionBox(box: rg, sceneView: self.sceneView)
            }
        }
        */
    }
    
    /// - Tag: RectangleDetectionHandler
    func rectangleDetectionHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results else {print("no result"); return}
        
        let result = observations.map({$0 as? VNRectangleObservation})
        if result.isEmpty {
            return
        }
        
        rectangleObservations = result as! [VNRectangleObservation]
        /*
        DispatchQueue.main.async() {
            self.sceneView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            for region in result {
                guard let rg = region else { continue }
                self.drawRegionBox(box: rg)
                break
            }
        }
        */
    }
    
    // MARK: - ARSessionDelegate
    
    // Pass camera frames received from ARKit to Vision (when not already processing one)
    /// - Tag: ConsumeARFrames
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
    
    // The pixel buffer being held for analysis; used to serialize Vision requests.
    private var currentBuffer: CVPixelBuffer?
    
    // Queue for dispatching vision classification requests
    private let visionQueue = DispatchQueue(label: "com.example.apple-samplecode.ARKitVision.serialVisionQueue")
    
    // Run Vision on the current image buffer.
    /// - Tag: ProcessCurrentImage
    private func processCurrentImage() {
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
    }
    
    private var font = CTFontCreateWithName("Helvetica" as CFString, 18, nil)
    
    /// - Tag: RecognizeTexts
    private func recognizeTexts(cvPixelBuffer: CVPixelBuffer) {
        var ciImage = CIImage(cvPixelBuffer: self.currentBuffer!)
        let transform = ciImage.orientationTransform(for: CGImagePropertyOrientation(rawValue: 6)!)
        ciImage = ciImage.transformed(by: transform)
        let size = ciImage.extent.size
        var recognizedTextPositionTuples = [(rect: CGRect, text: String)]()
        
        textObservations = textObservations.filter{
            (textObservation: VNTextObservation) -> Bool in
            return isTextInsideRectangles(text: textObservation, rects: rectangleObservations, size: size)
        }
        textObservations.sort(by: >)
        
        var keywords = ""
        for textObservation in self.textObservations {
            guard let rects = textObservation.characterBoxes else {
                continue
            }
            let (imageRect, xMin, xMax, yMin, yMax) = createImageRect(rects: rects, size: size)
            
            var text = runOCRonImage(imageRect: imageRect, ciImage: ciImage, tesseract: tesseract)
            text = correctText(text: text)
            
            if text.count > 1 && text.containsNoun() {
                let x = xMin
                let y = 1 - yMax
                let width = xMax - xMin
                let height = yMax - yMin
                let textRect = CGRect(x: x, y: y, width: width, height: height)
                recognizedTextPositionTuples.append((rect: textRect, text: text))
                keywords += " \(text)"
                
                if (recognizedTextPositionTuples.count >= 3) {
                    break
                }
            }
        }
        
        if (!videoLoaded && !keywords.isEmpty) {
            // print("Keywords: " + keywords)
            movieTitle = keywords
            createVideoAnchor()
            videoLoaded = true
        }
        
        textObservations.removeAll()
        /*
        DispatchQueue.main.async {
            addTextsToView(view: self.view, recognizedTextPositionTuples: recognizedTextPositionTuples, font: self.font)
        }
        */
    }
    
    // MARK: - AR Session Handling
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        statusViewController.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        
        switch camera.trackingState {
        case .notAvailable, .limited:
            statusViewController.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
        case .normal:
            statusViewController.cancelScheduledMessage(for: .trackingStateEscalation)
            // Unhide content after successful relocalization.
            setOverlaysHidden(false)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Filter out optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        setOverlaysHidden(true)
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        /*
         Allow the session to attempt to resume after an interruption.
         This process may not succeed, so the app must be prepared
         to reset the session if the relocalizing status continues
         for a long time -- see `escalateFeedback` in `StatusViewController`.
         */
        return true
    }
    
    private func setOverlaysHidden(_ shouldHide: Bool) {
        sceneView.scene.rootNode.childNodes.forEach { node in
            if shouldHide {
                // Hide overlay content immediately during relocalization.
                // node.alpha = 0
                node.isHidden = true
            } else {
                // Fade overlay content in after relocalization succeeds.
                // node.run(.fadeIn(withDuration: 0.5))
                node.isHidden = false
            }
        }
    }
    
    private func restartSession() {
        statusViewController.cancelAllScheduledMessages()
        statusViewController.showMessage("RESTARTING SESSION")
        
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // MARK: - Error handling
    
    private func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.restartSession()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
    
    /// - Tag: CreateVideoAnchor
    private func createVideoAnchor() {
        // Create anchor using the camera's current position
        if let currentFrame = sceneView.session.currentFrame {
            if (!videoLoaded){
                self.cinemaFrame = currentFrame
            }
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -1.5
            let transform = matrix_multiply((cinemaFrame?.camera.transform)!, translation)
            
            let anchor = ARAnchor(transform: transform)
            sceneView.session.add(anchor: anchor)
        }
    }
}

extension ViewController: ARSCNViewDelegate {
    /// - Tag: ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {        
        let key = readKey(key: "YouTubeDataAPI")
        let query = movieTitle + " trailer"
        let youtubeAPI = ("https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=" + query + "&key=" + key).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        AF.request(youtubeAPI!).responseJSON { response in
            // print("Request: \(String(describing: response.request))")   // original url request
            // print("Response: \(String(describing: response.response))") // http url response
            // print("Result: \(response.result)")                         // response serialization result
            
            switch response.result {
            case .success(let value):
                let jsonObject = JSON(value)
                let videoId = jsonObject["items"][0]["id"]["videoId"].stringValue
                let url = "https://www.youtube.com/watch?v=" + videoId
                // print("URL: " + url)
                
                let y = YoutubeDirectLinkExtractor()
                y.extractInfo(for: .urlString(url), success: { info in
                    if (info.highestQualityPlayableLink != nil) {
                        addVideoToSCNNode(url: info.highestQualityPlayableLink!, node: node)
                    } else {
                        self.videoLoaded = false
                    }
                }) { error in
                    print(error)
                    self.videoLoaded = false
                }
            case .failure(let error):
                print(error)
                self.videoLoaded = false
            }
            
            /*
             if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
             print("Data: \(utf8Text)") // original server data as UTF8 string
             }
             */
        }
        
    }
}

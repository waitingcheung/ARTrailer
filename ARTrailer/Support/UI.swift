//
//  UI.swift
//  ARTrailer
//
//  Created by Wai Ting Cheung on 10/8/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import Vision
import ARKit

// Create an image rectangle based on text observations.
func createImageRect(rects: [VNRectangleObservation], size: CGSize) -> (CGRect, CGFloat, CGFloat, CGFloat, CGFloat) {
    var xMin = CGFloat.greatestFiniteMagnitude
    var xMax: CGFloat = 0
    var yMin = CGFloat.greatestFiniteMagnitude
    var yMax: CGFloat = 0
    for rect in rects {
        xMin = min(xMin, rect.bottomLeft.x)
        xMax = max(xMax, rect.bottomRight.x)
        yMin = min(yMin, rect.bottomRight.y)
        yMax = max(yMax, rect.topRight.y)
    }
    let imageRect = CGRect(x: xMin * size.width, y: yMin * size.height, width: (xMax - xMin) * size.width, height: (yMax - yMin) * size.height)
    return (imageRect, xMin, xMax, yMin, yMax)
}

func addTextsToView(view: UIView, recognizedTextPositionTuples: [(rect: CGRect, text: String)], font: CTFont) {
    let viewWidth = view.frame.size.width
    let viewHeight = view.frame.size.height
    guard let sublayers = view.layer.sublayers else {
        return
    }
    for layer in sublayers[1...] {
        if let _ = layer as? CATextLayer {
            layer.removeFromSuperlayer()
        }
    }
    
    for tuple in recognizedTextPositionTuples {
        let textLayer = CATextLayer()
        textLayer.backgroundColor = UIColor.clear.cgColor
        textLayer.font = font
        var rect = tuple.rect
        
        rect.origin.x *= viewWidth
        rect.size.width *= viewWidth
        rect.origin.y *= viewHeight
        rect.size.height *= viewHeight
        
        // Increase the size of text layer to show text of large lengths
        rect.size.width += 100
        rect.size.height += 100
        
        textLayer.frame = rect
        textLayer.string = tuple.text
        textLayer.foregroundColor = UIColor.blue.cgColor
        view.layer.addSublayer(textLayer)
    }
}

func createRectFromVNText(text: VNTextObservation, size: CGSize) -> CGRect {
    let boxes = text.characterBoxes
    
    var xMin: CGFloat = CGFloat.greatestFiniteMagnitude
    var xMax: CGFloat = 0.0
    var yMin: CGFloat = CGFloat.greatestFiniteMagnitude
    var yMax: CGFloat = 0.0
    
    for box in boxes! {
        xMin = min(xMin, box.bottomLeft.x)
        xMax = max(xMax, box.bottomRight.x)
        yMin = min(yMin, box.bottomRight.y)
        yMax = max(yMax, box.topRight.y)
    }
    
    let xCoord = xMin * size.width
    let yCoord = (1 - yMax) * size.height
    let width = (xMax - xMin) * size.width
    let height = (yMax - yMin) * size.height
    
    return CGRect(x: xCoord, y: yCoord, width: width, height: height)
}

func createRectFromVNRect(rect: VNRectangleObservation, size: CGSize) -> CGRect {
    let xMin = min(rect.bottomLeft.x, rect.topLeft.x)
    let xMax = max(rect.bottomRight.x, rect.topRight.x)
    let yMin = min(rect.bottomRight.y, rect.bottomRight.y)
    let yMax = max(rect.topRight.y, rect.topLeft.y)
    
    let xCoord = xMin * size.width
    let yCoord = (1 - yMax) * size.height
    let width = (xMax - xMin) * size.width
    let height = (yMax - yMin) * size.height
    
    return CGRect(x: xCoord, y: yCoord, width: width, height: height)
}

// MARK: - Draw
func drawRegionBox(box: VNTextObservation, sceneView: ARSCNView) {
    guard box.characterBoxes != nil else { return }
    
    let layer = CALayer()
    layer.frame = createRectFromVNText(text: box, size: sceneView.frame.size)
    layer.borderWidth = 2.0
    layer.borderColor = UIColor.green.cgColor
    
    sceneView.layer.addSublayer(layer)
}

// MARK: - Draw
func drawRegionBox(box: VNRectangleObservation, sceneView: ARSCNView) {
    let layer = CALayer()
    layer.frame = transformRect(fromRect: box.boundingBox, toViewRect: sceneView)
    layer.backgroundColor = UIColor.yellow.cgColor
    layer.opacity = 0.5
    sceneView.layer.addSublayer(layer)
}

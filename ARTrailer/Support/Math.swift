//
//  Math.swift
//  ARTrailer
//
//  Created by Wai Ting Cheung on 10/8/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import Vision

func > (o1: VNTextObservation, o2: VNTextObservation) -> Bool {
    if (o1.characterBoxes != nil && o2.characterBoxes != nil) {
        return area(rects: o1.characterBoxes!) > area(rects: o2.characterBoxes!)
    } else {
        return false
    }
}

private func area(rects: [VNRectangleObservation]) -> CGFloat {
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
    return (xMax - xMin) * (yMax - yMin)
}

private func area(rect: VNRectangleObservation) -> CGFloat {
    return (rect.topRight.x - rect.topLeft.x) * (rect.topLeft.y - rect.bottomLeft.y)
}

func levenshtein(w1: String, w2: String) -> Int {
    let (t, s) = (w1, w2)
    
    let empty = Array<Int>(repeating:0, count: s.count)
    var last = [Int](0...s.count)
    
    for (i, tLett) in t.enumerated() {
        var cur = [i + 1] + empty
        for (j, sLett) in s.enumerated() {
            cur[j + 1] = tLett == sLett ? last[j] : min(last[j], last[j + 1], cur[j])+1
        }
        last = cur
    }
    return last.last!
}

func VNRectangleComparator (a: VNRectangleObservation?, b: VNRectangleObservation?) -> Bool {
    if (a == nil || b == nil) { return false }
    return area(rect: a!) > area(rect: b!)
}

func isTextInsideRectangles(text: VNTextObservation, rects: [VNRectangleObservation], size: CGSize) -> Bool {
    for rect in rects {
        let textRect = createRectFromVNText(text: text, size: size)
        let detectedRect = createRectFromVNRect(rect: rect, size: size)
        if (detectedRect.contains(textRect)) {
            return true
        }
    }
    return false
}

// Convert Vision Frame to UIKit Frame
func transformRect(fromRect: CGRect , toViewRect :UIView) -> CGRect {
    var toRect = CGRect()
    
    toRect.size.width = fromRect.size.width * toViewRect.frame.size.width
    toRect.size.height = fromRect.size.height * toViewRect.frame.size.height
    toRect.origin.y =  (toViewRect.frame.height) - (toViewRect.frame.height * fromRect.origin.y )
    toRect.origin.y  = toRect.origin.y -  toRect.size.height
    toRect.origin.x =  fromRect.origin.x * toViewRect.frame.size.width
    
    return toRect
}

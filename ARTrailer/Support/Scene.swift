//
//  Scene.swift
//  ARTrailer
//
//  Created by Wai Ting Cheung on 14/8/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import SceneKit
import SpriteKit

/// - Tag: AddVideoToSCNNode
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
    tvPlaneNode.opacity = 0.95
    
    videoNode.play()
    
    node.addChildNode(tvPlaneNode)
}

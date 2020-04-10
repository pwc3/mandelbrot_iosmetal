//
//  Mandelbrot.swift
//  mandelbrot_metal
//
//  Created by Marcio Cabral on 6/26/15.
//  Copyright (c) 2015 Marcio Cabral. All rights reserved.
//

import Foundation
import UIKit

class Mandelbrot {
    let resolution: CGSize
    let translationScale: CGSize

    var origin: CGPoint
    var zoom: CGFloat
    var delta: CGPoint

    init() {
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.nativeScale
        resolution = CGSize(width: screenSize.width * scale, height: screenSize.height * scale)
        translationScale = CGSize(width: screenSize.width / 2, height: screenSize.height / 2)

        origin = CGPoint(x: -0.5, y: 0)

        let h: CGFloat = 2.5
        delta = CGPoint(x: h * resolution.width / resolution.height, y: h)
        zoom = 1
    }

    func moveOrigin(dx: CGFloat, dy: CGFloat) {
        let deltaX = (-dx / translationScale.width) / zoom
        let deltaY = (dy / translationScale.height) / zoom

        origin.x += deltaX
        origin.y += deltaY
    }
    
    func getOrigin() -> CGPoint {
        return CGPoint(x: origin.x - ( (delta.x / zoom) / 2.0 ),
                       y: origin.y - ( (delta.y / zoom) / 2.0) )
    }
    
    func setZoom(z: CGFloat) {
        zoom = zoom + (z - 1.0) * zoom
    }

    func getDelta() -> CGPoint {
        return CGPoint(x: delta.x / zoom, y: delta.y / zoom)
    }
}

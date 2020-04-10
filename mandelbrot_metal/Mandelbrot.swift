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
    var origin: CGPoint
    var zoom: CGFloat

    var delta  = CGPoint(x: 3.5, y: 2.0)

    init() {
        resolution = UIScreen.main.bounds.size
        origin = CGPoint(x: -0.5, y: 0)
        zoom = 1
    }

    func moveOrigin(dx: CGFloat, dy: CGFloat) {
        let deltaX = (-dx / resolution.width) / zoom
        let deltaY = (dy / resolution.height) / zoom

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

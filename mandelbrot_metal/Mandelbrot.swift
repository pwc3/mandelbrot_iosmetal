//
//  Mandelbrot.swift
//  mandelbrot_metal
//
//  Created by Marcio Cabral on 6/26/15.
//  Copyright (c) 2015 Marcio Cabral. All rights reserved.
//

import Foundation
import UIKit

struct Point2D {
    
    var x:Float = 0.0;
    var y:Float = 0.0;
    
}

class Mandelbrot {
    
    var origin     = Point2D(x: -2.5, y: -1.0)
    var delta      = Point2D(x:  3.5, y:  2.0)
    var zoom:Float = 1.0
    
    let resolution:CGPoint = CGPoint(x: 320, y: 480)
    
    func setOrigin(dx: Float, dy: Float) {
        var deltax: Float = -dx/Float(resolution.x)
        var deltay: Float =  dy/Float(resolution.y)
        
        origin.x = origin.x + deltax / zoom
        origin.y = origin.y + deltay / zoom
    }
    
    func getOrigin() -> Point2D {
        return Point2D(x: origin.x - ( (delta.x / zoom) / 2.0 ), y: origin.y - ( (delta.y / zoom) / 2.0) )
    }
    
    func setZoom(z:Float) {
        zoom = zoom + (z - 1.0) * zoom
    }

    
    func getDelta() -> Point2D {
        return Point2D(x: delta.x / zoom, y: delta.y / zoom)
    }
        
}

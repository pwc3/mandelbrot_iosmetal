//
//  GameViewController.swift
//  mandelbrot_metal
//
//  Created by Marcio Cabral on 6/24/15.
//  Copyright (c) 2015 Marcio Cabral. All rights reserved.
//

import UIKit
import Metal
import QuartzCore
import GLKit.GLKMath

let ConstantBufferSize = 1024*1024
var lastPoint: CGPoint = CGPoint(x: 0,y: 0)

var mandel = Mandelbrot()

let vertexData:[Float] =
[
    -1.0, -1.0, 0.0, 1.0,
    -1.0,  1.0, 0.0, 1.0,
    1.0, -1.0, 0.0, 1.0,
    
    1.0, -1.0, 0.0, 1.0,
    -1.0,  1.0, 0.0, 1.0,
    1.0,  1.0, 0.0, 1.0
]

let vertexTextureData:[Float] =
[
    0.0, 0.0,
    0.0, 1.0,
    1.0, 0.0,
    1.0, 0.0,
    0.0, 1.0,
    1.0, 1.0
]


class GameViewController: UIViewController {
    
    let device = { MTLCreateSystemDefaultDevice() }()
    let metalLayer = { CAMetalLayer() }()
    
    var commandQueue: MTLCommandQueue! = nil
    var timer: CADisplayLink! = nil
    var pipelineState: MTLRenderPipelineState! = nil
    var vertexBuffer: MTLBuffer! = nil
    var vertexTextureBuffer: MTLBuffer! = nil
    
    var fragmentBuffer: MTLBuffer! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm
        metalLayer.framebufferOnly = true
        
        self.resize()
        
        view.layer.addSublayer(metalLayer)
        view.opaque = true
        view.backgroundColor = nil
        
        commandQueue = device.newCommandQueue()
        commandQueue.label = "main command queue"
        
        let defaultLibrary = device.newDefaultLibrary()
        let fragmentProgram = defaultLibrary?.newFunctionWithName("passThroughFragment")
        let vertexProgram = defaultLibrary?.newFunctionWithName("passThroughVertex")
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
        
        var pipelineError : NSError?
        pipelineState = device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor, error: &pipelineError)
        if (pipelineState == nil) {
            println("Failed to create pipeline state, error \(pipelineError)")
        }
        
        vertexBuffer = device.newBufferWithLength(ConstantBufferSize, options: nil)
        vertexBuffer.label = "vertices"
        
        let vertexTextureSize = vertexData.count * sizeofValue(vertexTextureData[0])
        vertexTextureBuffer = device.newBufferWithBytes(vertexTextureData, length: vertexTextureSize, options: nil)
        vertexTextureBuffer.label = "textureCoord"

        // scale, origin.x, origin.y, delta.x, delta.y
        let fragmentBufferSize = sizeof(Float) * 5
        fragmentBuffer = device.newBufferWithLength(fragmentBufferSize, options: nil)
        fragmentBuffer.label = "mandelbrotData"
        
        timer = CADisplayLink(target: self, selector: Selector("renderLoop"))
        timer.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }
    
    override func viewDidLayoutSubviews() {
        self.resize()
    }
    
    @IBAction func handlePinch(recognizer : UIPinchGestureRecognizer) {

        mandel.setZoom(Float(recognizer.scale))
        recognizer.scale = 1
        
    }
    
    @IBAction func didPan(sender: UIPanGestureRecognizer) {

        let currentPoint = sender.translationInView(self.view)
        mandel.setOrigin(Float(currentPoint.x - lastPoint.x), dy: Float(currentPoint.y - lastPoint.y))
        lastPoint = currentPoint
        
        if (sender.state == UIGestureRecognizerState.Ended) {
            lastPoint = CGPoint(x: 0, y: 0)
        }

    }
    
    
    func resize() {
        if (view.window == nil) {
            return
        }
        
        let window = view.window!
        let nativeScale = window.screen.nativeScale
        view.contentScaleFactor = nativeScale
        metalLayer.frame = view.layer.frame
        
        var drawableSize = view.bounds.size
        drawableSize.width = drawableSize.width * CGFloat(view.contentScaleFactor)
        drawableSize.height = drawableSize.height * CGFloat(view.contentScaleFactor)
        
        metalLayer.drawableSize = drawableSize
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
   
    deinit {
        timer.invalidate()
    }
    
    func renderLoop() {
        autoreleasepool {
            self.render()
        }
    }
    
    func render() {
        
        self.update()
        
        
        // vData is pointer to the MTLBuffer's Float data contents
        let pData = vertexBuffer.contents()
        let vData = UnsafeMutablePointer<Float>(pData)
        
        // reset the vertices to default before adding animated offsets
        vData.initializeFrom(vertexData)
        
        
        let commandBuffer = commandQueue.commandBuffer()
        commandBuffer.label = "Frame command buffer"
        
        let drawable = metalLayer.nextDrawable()
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .Store
        
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)!
        renderEncoder.label = "render encoder"
        
        renderEncoder.pushDebugGroup("draw triangles to cover screen")
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)
        renderEncoder.setVertexBuffer(vertexTextureBuffer, offset: 0, atIndex: 1)
        
        var fragData:[Float] = [ mandel.zoom, mandel.getDelta().x, mandel.getDelta().y, mandel.getOrigin().x, mandel.getOrigin().y ]
        memcpy(fragmentBuffer.contents(), &fragData, sizeof(Float) * 5)
        renderEncoder.setFragmentBuffer(fragmentBuffer, offset: 0, atIndex: 0)
        
        renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        commandBuffer.presentDrawable(drawable)
        commandBuffer.commit()
    }
    
    func update() {

//
    }
}
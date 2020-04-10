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
    
    let device: MTLDevice! = { MTLCreateSystemDefaultDevice() }()
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
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        
        self.resize()
        
        view.layer.addSublayer(metalLayer)
        view.isOpaque = true
        view.backgroundColor = nil
        
        commandQueue = device.makeCommandQueue()
        commandQueue.label = "main command queue"
        
        let defaultLibrary = device.makeDefaultLibrary()
        let fragmentProgram = defaultLibrary?.makeFunction(name: "passThroughFragment")
        let vertexProgram = defaultLibrary?.makeFunction(name: "passThroughVertex")
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        }
        catch {
            print("Failed to create pipeline state: \(error)")
            return
        }

        vertexBuffer = device.makeBuffer(length: ConstantBufferSize, options: [])
        vertexBuffer.label = "vertices"
        
        let vertexTextureSize = vertexData.count * MemoryLayout.size(ofValue: vertexTextureData[0])
        vertexTextureBuffer = device.makeBuffer(bytes: vertexTextureData, length: vertexTextureSize, options: [])
        vertexTextureBuffer.label = "textureCoord"

        // scale, origin.x, origin.y, delta.x, delta.y
        let fragmentBufferSize = MemoryLayout<Float>.size * 5
        fragmentBuffer = device.makeBuffer(length: fragmentBufferSize, options: [])
        fragmentBuffer.label = "mandelbrotData"
        
        timer = CADisplayLink(target: self, selector: #selector(renderLoop))
        timer.add(to: .main, forMode: .default)
    }
    
    override func viewDidLayoutSubviews() {
        self.resize()
    }
    
    @IBAction func handlePinch(recognizer : UIPinchGestureRecognizer) {
        mandel.setZoom(z: Float(recognizer.scale))
        recognizer.scale = 1
    }
    
    @IBAction func didPan(sender: UIPanGestureRecognizer) {
        let currentPoint = sender.translation(in: self.view)
        mandel.setOrigin(dx: Float(currentPoint.x - lastPoint.x), dy: Float(currentPoint.y - lastPoint.y))
        lastPoint = currentPoint
        
        if (sender.state == .ended) {
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

    override var prefersStatusBarHidden: Bool {
        return true
    }
   
    deinit {
        timer.invalidate()
    }

    @objc func renderLoop() {
        autoreleasepool {
            self.render()
        }
    }
    
    func render() {
        self.update()

        // vData is pointer to the MTLBuffer's Float data contents
        let pData = vertexBuffer.contents()
        let vData = pData.bindMemory(to: Float.self, capacity: vertexData.count)

        // reset the vertices to default before adding animated offsets
        vData.initialize(from: vertexData, count: vertexData.count)

        let commandBuffer: MTLCommandBuffer! = commandQueue.makeCommandBuffer()
        commandBuffer.label = "Frame command buffer"
        
        let drawable: CAMetalDrawable! = metalLayer.nextDrawable()
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let renderEncoder: MTLRenderCommandEncoder! = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderEncoder.label = "render encoder"
        
        renderEncoder.pushDebugGroup("draw triangles to cover screen")
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(vertexTextureBuffer, offset: 0, index: 1)
        
        var fragData:[Float] = [ mandel.zoom, mandel.getDelta().x, mandel.getDelta().y, mandel.getOrigin().x, mandel.getOrigin().y ]
        memcpy(fragmentBuffer.contents(), &fragData, MemoryLayout<Float>.size * 5)
        renderEncoder.setFragmentBuffer(fragmentBuffer, offset: 0, index: 0)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 1)
        
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func update() { }
}

//
//  MetalCIImageView.swift
//  HumanSegmentation
//
//  Created by Naoki Odajima on 2022/04/02.
//

import MetalKit

@MainActor
final class MetalCIImageView: MTKView {
    var renderImage: CIImage?
    
    private var commandQueue: MTLCommandQueue?
    private var ciContext: CIContext?
    
    func setup() {
        guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
            NSLog("failed to create MTLDevice.")
            return
        }
        self.commandQueue = mtlDevice.makeCommandQueue()
        self.ciContext = CIContext(mtlDevice: mtlDevice)
        self.device = mtlDevice
        self.framebufferOnly = false
        self.delegate = self
    }
}

// MARK: - MTKViewDelegate

extension MetalCIImageView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let renderImage = self.renderImage,
              let ciContext = self.ciContext,
              let commandBuffer = self.commandQueue?.makeCommandBuffer(),
              let currentDrawable = view.currentDrawable else {
            return
        }
        let fitTransform = CGAffineTransform(
            scaleX: view.drawableSize.width / renderImage.extent.width,
            y: view.drawableSize.height / renderImage.extent.height
        )
        let newImage = renderImage.transformed(by: fitTransform)
        ciContext.render(
            newImage,
            to: currentDrawable.texture,
            commandBuffer: commandBuffer,
            bounds: newImage.extent,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}

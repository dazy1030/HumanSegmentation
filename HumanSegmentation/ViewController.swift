//
//  ViewController.swift
//  HumanSegmentation
//
//  Created by Naoki Odajima on 2022/03/30.
//

import CoreImage.CIFilterBuiltins
import MetalKit
import UIKit

@MainActor
final class ViewController: UIViewController {
    @IBOutlet private weak var mtkView: MTKView! {
        didSet {
            self.setupMetal()
        }
    }
    private var commandQueue: MTLCommandQueue?
    private var ciContext: CIContext?
    private var originCaptureImage: CIImage?
    private var maskImage: CIImage?
    private let videoCapture = VideoCapture()
    private let humanSegmentation = HumanSegmentation()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            try self.videoCapture.start()
        } catch {
            self.showError(error)
        }
    }
    
    private func setupMetal() {
        guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
            NSLog("failed to create MTLDevice.")
            return
        }
        self.commandQueue = mtlDevice.makeCommandQueue()
        self.ciContext = CIContext(mtlDevice: mtlDevice)
        self.mtkView.device = mtlDevice
        self.mtkView.framebufferOnly = false
        self.mtkView.delegate = self
        Task {
            for await sampleBuffer in self.videoCapture.sampleBufferStream {
                guard let imageBuffer = sampleBuffer.imageBuffer else {
                    return
                }
                self.originCaptureImage = CIImage(cvImageBuffer: imageBuffer)
                do {
                    guard let maskImageBuffer = try self.humanSegmentation.makeMaskPixelBuffer(of: imageBuffer) else {
                        return
                    }
                    self.maskImage = CIImage(cvImageBuffer: maskImageBuffer)
                } catch {
                    NSLog(error.localizedDescription)
                }
                self.mtkView.draw()
            }
        }
    }
    
    private func showError(_ error: Error) {
        let alertController = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(alertAction)
        self.present(alertController, animated: true)
    }
    
    private func mask(to originImage: CIImage, with maskImage: CIImage) -> CIImage? {
        let fixedMaskImage: CIImage
        if originImage.extent.size != maskImage.extent.size {
            let fixTransform = CGAffineTransform(
                scaleX: originImage.extent.width / maskImage.extent.width,
                y: originImage.extent.height / maskImage.extent.height
            )
            fixedMaskImage = maskImage.transformed(by: fixTransform)
        } else {
            fixedMaskImage = maskImage
        }
        let filter = CIFilter.blendWithMask()
        filter.backgroundImage = fixedMaskImage
        filter.inputImage = originImage
        filter.maskImage = fixedMaskImage
        return filter.outputImage
    }
}

// MARK: - MTKViewDelegate

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard var renderImage = self.originCaptureImage,
              let ciContext = self.ciContext,
              let commandBuffer = self.commandQueue?.makeCommandBuffer(),
              let currentDrawable = view.currentDrawable else {
            return
        }
        if let maskImage = self.maskImage, let maskedImage = self.mask(to: renderImage, with: maskImage) {
            renderImage = maskedImage
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

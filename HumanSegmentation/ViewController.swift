//
//  ViewController.swift
//  HumanSegmentation
//
//  Created by Naoki Odajima on 2022/03/30.
//

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
    private var currentCIImage: CIImage?
    private let videoCapture = VideoCapture()
    
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
                self.currentCIImage = CIImage(cvImageBuffer: imageBuffer)
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
}

// MARK: - MTKViewDelegate

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let ciImage = self.currentCIImage,
              let ciContext = self.ciContext,
              let commandBuffer = self.commandQueue?.makeCommandBuffer(),
              let currentDrawable = view.currentDrawable else {
            return
        }
        let fitTransform = CGAffineTransform(
            scaleX: view.drawableSize.width / ciImage.extent.width,
            y: view.drawableSize.height / ciImage.extent.height
        )
        let newImage = ciImage.transformed(by: fitTransform)
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

//
//  ViewController.swift
//  HumanSegmentation
//
//  Created by Naoki Odajima on 2022/03/30.
//

import CoreImage.CIFilterBuiltins
import UIKit

@MainActor
final class ViewController: UIViewController {
    @IBOutlet private weak var mtlImageView: MetalCIImageView! {
        didSet {
            self.mtlImageView.setup()
        }
    }
    private let captureSession = CaptureSession()
    private let humanSegmentation = HumanSegmentation()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            try self.captureSession.start()
            self.startRenderTask()
        } catch {
            self.showError(error)
        }
    }
    
    private func startRenderTask() {
        Task {
            for await sampleBuffer in self.captureSession.sampleBufferStream {
                guard let imageBuffer = sampleBuffer.imageBuffer else {
                    return
                }
                let originImage = CIImage(cvImageBuffer: imageBuffer)
                var maskedImage: CIImage?
                do {
                    if let maskImageBuffer = try self.humanSegmentation.makeMaskPixelBuffer(of: imageBuffer) {
                        let maskImage = CIImage(cvImageBuffer: maskImageBuffer)
                        maskedImage = self.mask(to: originImage, with: maskImage)
                    }
                } catch {
                    NSLog(error.localizedDescription)
                }
                self.mtlImageView.renderImage = maskedImage ?? originImage
                self.mtlImageView.draw()
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

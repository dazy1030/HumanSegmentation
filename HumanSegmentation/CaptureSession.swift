//
//  CaptureSession.swift
//  HumanSegmentation
//
//  Created by Naoki Odajima on 2022/03/30.
//

import AVFoundation
import Combine

final class CaptureSession: NSObject {
    private var captureSession: AVCaptureSession?
    private let sampleBufferPipe = PassthroughSubject<CMSampleBuffer, Never>()
    
    var sampleBufferStream: AsyncPublisher<AnyPublisher<CMSampleBuffer, Never>> {
        self.sampleBufferPipe.eraseToAnyPublisher().values
    }

    func start() throws {
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw Error.noCaptureDevice
        }
        let captureDeviceInput: AVCaptureDeviceInput
        do {
            captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
        } catch {
            throw Error.makeInputError(error)
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.captureSession = AVCaptureSession()
            self.captureSession?.addInput(captureDeviceInput)
            let captureOutput = AVCaptureVideoDataOutput()
            captureOutput.setSampleBufferDelegate(self, queue: .main)
            captureOutput.alwaysDiscardsLateVideoFrames = true
            self.captureSession?.addOutput(captureOutput)
            self.captureSession?.sessionPreset = .high
            captureOutput.connection(with: .video)?.videoOrientation = .portrait
            captureOutput.connection(with: .video)?.isVideoMirrored = true
            self.captureSession?.startRunning()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        self.sampleBufferPipe.send(sampleBuffer)
    }
}

// MARK: - CaptureSession.Error

extension CaptureSession {
    enum Error: LocalizedError {
        case noCaptureDevice
        case makeInputError(Swift.Error)
        
        var errorDescription: String? {
            switch self {
            case .noCaptureDevice:
                return "No capture device."
            case let .makeInputError(error):
                let nsError = error as NSError
                return nsError.localizedFailureReason
            }
        }
    }
}

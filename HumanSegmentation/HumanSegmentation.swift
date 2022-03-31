//
//  HumanSegmentation.swift
//  HumanSegmentation
//
//  Created by Naoki Odajima on 2022/03/31.
//

import Vision

final class HumanSegmentation {
    private let request: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
        /*
        accurate: 結果（のマスク画像）のエッジがかなり鮮明。30fpsの維持は試した限り不可能
        balanced: 結果（のマスク画像）のエッジがぼやける。30fpsの維持が可能
        fast: 結果（のマスク画像）解像度がとても荒くなり精度も低い。30fpsの維持が容易
         */
        request.qualityLevel = .balanced
        return request
    }()
    private let requestHandler = VNSequenceRequestHandler()
    
    func makeMaskPixelBuffer(of pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer? {
        try self.requestHandler.perform([self.request], on: pixelBuffer)
        return self.request.results?.first?.pixelBuffer
    }
}

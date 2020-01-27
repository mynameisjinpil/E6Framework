//
//  DeviceOutput.swift
//  E6Framework
//
//  Created by yujinpil on 01/09/2019.
//  Copyright © 2019 portrayer. All rights reserved.
//

import AVFoundation

public protocol DeviceVideoDataOutputDelegate: class {
  func sendPreviewImage(_ image: UIImage)
  func sendFilmImage(_ image: UIImage)
}

public class DeviceVideoDataOutput: NSObject {
  public var delegate: DeviceVideoDataOutputDelegate?
  
  private let videoOutput = AVCaptureVideoDataOutput()
  private var previewLayer: AVCaptureVideoPreviewLayer!
  
  var ratio: PreviewRatio = .rectangle
  
  override init() {
    super.init()
  }
  
  func configureCaptureOutput(_ session: AVCaptureSession, _ previewLayer: AVCaptureVideoPreviewLayer, sessionQueue: DispatchQueue) {
    self.previewLayer = previewLayer
    
    if session.canAddOutput(self.videoOutput) {
      session.addOutput(self.videoOutput)
      self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
      self.videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
    }
    else {
      print("비디오 아웃풋을 연결할수 없습니다")
      return
    }
    videoOutput.connection(with: .video)?.videoOrientation = .portrait
  }
  
  func makeOrientationToPortrait() {
    videoOutput.connection(with: .video)?.videoOrientation = .portrait
  }
  
  func makeMirrored() {
    self.videoOutput.connection(with: .video)?.isVideoMirrored = true
  }
}

extension DeviceVideoDataOutput: AVCaptureVideoDataOutputSampleBufferDelegate {
  public func captureOutput(_ output: AVCaptureOutput,
                            didOutput sampleBuffer: CMSampleBuffer,
                            from connection: AVCaptureConnection) {
    guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
      let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        return
    }
    
    let originImage = CIImage(cvImageBuffer: imageBuffer)
    let origin = UIImage(ciImage: originImage)
    
    self.delegate?.sendFilmImage(origin)
    
    var filteredPixelBuffer: CVImageBuffer!
    
    let filter = E6Filters.sharedForVideo
    filter.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
    
    guard let filterdBuffer = filter.render(pixelBuffer: imageBuffer) else {
      print("Unable to filter video buffer")
      return
    }
    
    filteredPixelBuffer = filterdBuffer
    
    let generatedImage = CIImage(cvImageBuffer: filteredPixelBuffer)
    let uiImage = UIImage(ciImage: generatedImage)
    
    if self.ratio == .rectangle {
      self.delegate?.sendPreviewImage(uiImage)
    }
    else if self.ratio == .square {
      let gap = (uiImage.size.height - uiImage.size.width)
      let croppedImage = generatedImage.cropped(to: CGRect(x: 0,
                                                           y: gap / 2,
                                                           width: uiImage.size.width,
                                                           height: uiImage.size.width + gap / 2))
      let sendableImage = UIImage(ciImage: croppedImage)
      self.delegate?.sendPreviewImage(sendableImage)
    }
  }
}

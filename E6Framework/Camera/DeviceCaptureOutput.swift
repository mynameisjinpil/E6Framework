//
//  DeviceCaptureOutput.swift
//  E6Framework
//
//  Created by yujinpil on 02/09/2019.
//  Copyright © 2019 portrayer. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos

private let photoSessionQueueIdentifier = "com.e6Framework.photosession"

public enum CaptureDelay {
  case zero
  case three
  case six
  case ten
  
  public func rawValue() -> Int {
    switch self {
    case .zero: return 0
    case .three: return 3
    case .six: return 6
    case .ten: return 10
    }
  }
}

public class DeviceCaptureOutput: NSObject {
  // MARK:- Variables
  
  var camera: E6Camera!
  
  var photoQueue: DispatchQueue = DispatchQueue(label: photoSessionQueueIdentifier)

  // MARK: Output
  let photoOutput = AVCapturePhotoOutput()
  
  // This three state is controlled by UI
  private var _silence: Bool = false
  public var silence: Bool {
    get {
      return _silence
    }
    set {
      _silence = newValue
    }
  }
  
  private var _flash: AVCaptureDevice.FlashMode = .off
  public var flash: AVCaptureDevice.FlashMode! {
    get {
      return _flash
    }
    set {
      _flash = newValue
      print(newValue.rawValue)
    }
  }
  
  private var _isSquare: Bool = false
  public var isSquare: Bool {
    get {
      return _isSquare
    }
    set {
      _isSquare = newValue
    }
  }
  
  // MAKR:- Init
  
  override init() {
    super.init()
  }
  
  // MARK:- Custom function
  
  func configureCaptureOutput(_ session: AVCaptureSession) {
    if session.canAddOutput(photoOutput) {
      session.addOutput(photoOutput)
    } else {
      fatalError("[E6Framework] Error, can't add input")
    }
    photoOutput.connection(with: .video)?.videoOrientation = .portrait
  }
  
  func makeOrientationToPortrait() {
    photoOutput.connection(with: .video)?.videoOrientation = .portrait
  }
  
  func makeMirrored() {
    self.photoOutput.connection(with: .video)?.isVideoMirrored = true
  }
  
  public func capturePhoto() {
    let photoSettings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
    photoSettings.flashMode = _flash
    self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
  }
}

extension DeviceCaptureOutput: AVCapturePhotoCaptureDelegate {
  public func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
    if silence {
      AudioServicesDisposeSystemSoundID(1108)
    }
  }
  
  public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    photoQueue.async {
      
      guard error == nil else { print("Error capturing photo: \(error!)"); return }
      
      guard let photoPixelBuffer = photo.pixelBuffer else {
        print("Error occurred while capturing photo: Missing pixel buffer")
        return
      }
      
      var photoFormatDescription: CMFormatDescription!
      CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                   imageBuffer: photoPixelBuffer,
                                                   formatDescriptionOut: &photoFormatDescription)
      
      var finalPixelBuffer = photoPixelBuffer
      
      let filter = E6Filters.sharedForPhoto
      filter.prepare(with: photoFormatDescription, outputRetainedBufferCountHint: 2)
      
      guard let filterdBuffer = filter.render(pixelBuffer: photoPixelBuffer) else {
        print("Unable to filter video buffer")
        return
      }
      
      finalPixelBuffer = filterdBuffer
      
      let metadataAttachments: CFDictionary = photo.metadata as CFDictionary
      guard let jpegData = DeviceCaptureOutput.jpegData(withPixelBuffer: finalPixelBuffer,
                                                        attachments: metadataAttachments,
                                                        isSquare: self._isSquare) else {
        print("Unable to create JPEG photo")
        return
      }
            
      PHPhotoLibrary.requestAuthorization { status in
        guard status == .authorized else { return }
        
        PHPhotoLibrary.shared().performChanges({
          // Add the captured photo's file data as the main resource for the Photos asset.
          let creationRequest = PHAssetCreationRequest.forAsset()
          creationRequest.addResource(with: .photo, data: jpegData, options: nil)
        }, completionHandler: { _, error in
          if let error = error {
            print("Error occurred while saving photo to photo library: \(error)")
          }
        })
      }
    }
  }
  
  private class func jpegData(withPixelBuffer pixelBuffer: CVPixelBuffer, attachments: CFDictionary?, isSquare: Bool) -> Data? {
    let ciContext = CIContext()
    let renderedCIImage = CIImage(cvImageBuffer: pixelBuffer)
    let ciImageSize = renderedCIImage.extent.size
    let squareSize = CGSize(width: ciImageSize.height, height: ciImageSize.height)
    let gap = (ciImageSize.width - ciImageSize.height) / 2
    let squareSizeExtent = CGRect(origin: CGPoint(x: gap, y: 0.0), size: squareSize)
    
    let photoRect: CGRect!
    
    if isSquare {
      photoRect = squareSizeExtent
    }
    else {
      photoRect = renderedCIImage.extent
    }
    
    guard let renderedCGImage = ciContext.createCGImage(renderedCIImage, from: photoRect) else {
      print("Failed to create CGImage")
      return nil
    }
    
    guard let data = CFDataCreateMutable(kCFAllocatorDefault, 0) else {
      print("Create CFData error!")
      return nil
    }
    
    guard let cgImageDestination = CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, nil) else {
      print("Create CGImageDestination error!")
      return nil
    }
    
    CGImageDestinationAddImage(cgImageDestination, renderedCGImage, attachments)
    if CGImageDestinationFinalize(cgImageDestination) {
      return data as Data
    }
    print("Finalizing CGImageDestination error!")
    return nil
  }
}

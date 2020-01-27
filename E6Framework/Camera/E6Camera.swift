//
//  Camera.swift
//  E6Framework
//
//  Created by yujinpil on 01/09/2019.
//  Copyright © 2019 portrayer. All rights reserved.
//

import AVFoundation


private let cameraSessionQueueIdentifier = "com.e6Framework.capturesession"
private let videoSessionQueueIdentifier = "com.e6Framework.videosession"


public enum PreviewRatio {
  case rectangle
  case square
}

open class E6Camera {

  // MARK:- Variables
  
  // MARK: Camera Session
  
  public let session: AVCaptureSession = AVCaptureSession()
  
  // MARK: Device State
  
  let photoSettings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])

  private var _position: AVCaptureDevice.Position = .back
  public var position: AVCaptureDevice.Position! {
    get {
      return _position
    }
    set {
      _position = newValue
      flipCamera()
    }
  }
    
  private var _focus: AVCaptureDevice.FocusMode = .continuousAutoFocus
  public var focus: AVCaptureDevice.FocusMode! {
    get {
      return _focus
    }
    set {
      _focus = newValue
    }
  }
  
  private var _flash: AVCaptureDevice.FlashMode = .off
  public var flash: AVCaptureDevice.FlashMode! {
    get {
      return _flash
    }
    set {
      _flash = newValue
    }
  }
  
  private var _ratio: PreviewRatio = .rectangle
  public var ratio: PreviewRatio! {
    get {
      return _ratio
    }
    set {
      _ratio = newValue
    }
  }
  
  private var _preset: AVCaptureSession.Preset = .photo
  public var preset: AVCaptureSession.Preset! {
    get {
      return _preset
    }
    set {
      _preset = newValue
    }
  }
  
  // MARK: Input
  
  // Device have properties flash, position CameraDevice() will return front, back device.
  private var deviceManager: CameraDevice = CameraDevice()
  private var captureDeviceInput = DeviceInput()
  
  // MARK: Output
  // Output var consist of video data(preview), capture data, meta data (location, time)
  public let photoOutput = DeviceCaptureOutput()
  public let videoOutput = DeviceVideoDataOutput()
  
  // MARK: Preview Layer
  // This class will return this layer, result of communication with view controller
  public lazy var previewLayer: AVCaptureVideoPreviewLayer! = {
    let layer = AVCaptureVideoPreviewLayer(session: self.session)
    layer.videoGravity = AVLayerVideoGravity.resizeAspect
    return layer
  } ()
  
  // MARK: Queue
  // Queue help async task, but occur dead lock problem. So, use carefully.
  var sessionQueue: DispatchQueue = DispatchQueue(label: cameraSessionQueueIdentifier)
  var videoQueue: DispatchQueue = DispatchQueue(label: videoSessionQueueIdentifier)

  
  public init() {
    self.configureSession()
  }

  deinit {
    stopSession()
  }
  
  // MARK:- Custom Function
  private func configureSession() {
      self.session.sessionPreset = self._preset
      self.configureInputDevice()
      self.configureOutput()
  }
  
  private func configureInputDevice() {
    guard let currentDevice = self.deviceManager.getCurrentCamera(self._position) else {
      fatalError("[E6Framework] Error, can't initilize device.")
    }
    
    do {
      try captureDeviceInput.configureInputCamera(self.session, device: currentDevice)
    } catch DeviceInputErrorType.unableToAddCamera{
      fatalError("[E6Framework] Error, can't add camera device input")
    } catch {
      fatalError("[E6Framework] Error, can't add input")
    }
  }
  private func configureOutput() {
    photoOutput.configureCaptureOutput(self.session)
    videoOutput.configureCaptureOutput(session, previewLayer,sessionQueue: sessionQueue)
  }
  
  public func flipCamera() {
    sessionQueue.async {
      switch self._position {
      case .back: self._position = .front
      case .front: self._position = .back
      case .unspecified: print("how can do that?")
      }
      
      self.session.beginConfiguration()

      self.session.removeInput(self.captureDeviceInput.cameraDeviceInput!)
      
      self.configureInputDevice()
      
      self.videoOutput.makeOrientationToPortrait()

      if self.position == .front {
        self.videoOutput.makeMirrored()
        self.photoOutput.makeMirrored()
      }
      
      self.session.commitConfiguration()
    }
  }
  
  public func changeRatio() {
    switch self._ratio {
    case .rectangle:
      self._ratio = .square
      self.photoOutput.isSquare = true
    case .square:
      self._ratio = .rectangle
      self.photoOutput.isSquare = false
    }
    
    self.videoOutput.ratio = self.ratio
  }
  
  // MARK: Session Control Function
  public func startSession() {
    session.startRunning()
  }
  
  public func stopSession() {
    session.stopRunning()
  }
  
  public func focus(with focusMode: AVCaptureDevice.FocusMode,
                     exposureMode: AVCaptureDevice.ExposureMode,
                     at devicePoint: CGPoint,
                     monitorSubjectAreaChange: Bool) {
    guard let videoDevice = self.captureDeviceInput.cameraDeviceInput?.device else {
      return
    }
    
    do {
      try videoDevice.lockForConfiguration()
      if videoDevice.isFocusPointOfInterestSupported && videoDevice.isFocusModeSupported(focusMode) {
        videoDevice.focusPointOfInterest = devicePoint
        videoDevice.focusMode = focusMode
      }
      
      if videoDevice.isExposurePointOfInterestSupported && videoDevice.isExposureModeSupported(exposureMode) {
        videoDevice.exposurePointOfInterest = devicePoint
        videoDevice.exposureMode = exposureMode
      }
      
      videoDevice.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
      
      videoDevice.unlockForConfiguration()
    } catch {
      print("Could not lock device for configuration: \(error)")
    }
  }
}

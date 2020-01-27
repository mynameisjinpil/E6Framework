//
//  CameraDevice.swift
//  E6Framework
//
//  Created by yujinpil on 01/09/2019.
//  Copyright © 2019 portrayer. All rights reserved.
//

import UIKit
import AVFoundation

class CameraDevice {
  private var backCameraDevice: AVCaptureDevice!
  private var frontCameraDevice: AVCaptureDevice!
  
  private var currentDevice: AVCaptureDevice!
  private var currentPosition: AVCaptureDevice.Position = .unspecified
  
  private func configureDeviceCamera() {    
    self.backCameraDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInDualCamera, AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
    
    self.frontCameraDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInDualCamera, AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: .video, position: .front).devices.first
  }
  
  func getCurrentCamera(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    switch position {
    case .front: return frontCameraDevice
    case .back: return backCameraDevice
    case .unspecified: return nil
    }
  }
  
  init() {
    self.configureDeviceCamera()
  }
}

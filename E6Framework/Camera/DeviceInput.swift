//
//  DeviceInput.swift
//  E6Framework
//
//  Created by yujinpil on 01/09/2019.
//  Copyright © 2019 portrayer. All rights reserved.
//

import AVFoundation

public enum DeviceInputErrorType: Error {
  case unableToAddCamera
}

class DeviceInput {
  public var cameraDeviceInput: AVCaptureDeviceInput?
  
  func configureInputCamera(_ session: AVCaptureSession, device: AVCaptureDevice) throws {
    do {
      cameraDeviceInput = try AVCaptureDeviceInput(device: device)
    } catch {
      throw DeviceInputErrorType.unableToAddCamera
    }
    
    guard session.canAddInput(cameraDeviceInput!) else {
      throw DeviceInputErrorType.unableToAddCamera
    }
    session.addInput(cameraDeviceInput!)
  }
}

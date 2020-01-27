//
//  E6Filters.swift
//  E6Framework
//
//  Created by yujinpil on 25/09/2019.
//  Copyright © 2019 portrayer. All rights reserved.
//

import CoreImage
import CoreMedia

open class E6Filters {
  // MARK:- Varialbes
  
  static public let sharedForVideo = E6Filters()
  
  static public let sharedForPhoto = E6Filters()
  
  private var _parameter: [String: Float] =  ["brightnessS": 0.0, "brightnessH": 0.0,
                                            "contrast": 0.0, "highlights": 0.5,
                                            "shadows": 0.75, "level": 1.0,
                                            "saturation": 1.0, "red": 0.0,
                                            "green": 0.0, "blue": 0.0,
                                            "sharpen": 0.4, "blur": 0.4]
  public var parameter: [String:Float]! {
    get {
      return _parameter
    }
    set {
      _parameter = newValue
    }
  }

  // MARK: Rendering
  
  private var context: CIContext?
  
  private var outputColorSpace: CGColorSpace?
  
  private var outputPixelBufferPool: CVPixelBufferPool?
  
  private(set) var outputFormatDescription: CMFormatDescription?
  
  private(set) var inputFormatDescription: CMFormatDescription?
  
  // MARK: Filters
  
  private var sharpenFilter: CIFilter? // Sharpen
  
  private var highlightFilter: CIFilter? // Highlight
  
  private var blsFilter: CIFilter? // Brightness, level, saturation
  
  private var rgbcFilter: CIFilter? // r, g, b, contrast
  
  private var shadowFilter: CIFilter? // Shadow
  
  func prepare(with formatDescription: CMFormatDescription,
               outputRetainedBufferCountHint: Int) {
    self.reset()
    
    (outputPixelBufferPool,
     outputColorSpace,
     outputFormatDescription) = allocateOutputBufferPool(with: formatDescription,
                                                         outputRetainedBufferCountHint: outputRetainedBufferCountHint)
    
    if outputPixelBufferPool == nil {
      return
    }
    
    inputFormatDescription = formatDescription
    
    context = CIContext()
    
    highlightFilter = CIFilter(name: "CIExposureAdjust")
    blsFilter = CIFilter(name: "CIColorControls")
    rgbcFilter = CIFilter(name: "CIColorPolynomial")
    shadowFilter = CIFilter(name: "CIGammaAdjust")
    sharpenFilter = CIFilter(name: "CISharpenLuminance")
  }
  
  func reset() {
    context = nil
    sharpenFilter = nil
    highlightFilter = nil
    blsFilter = nil
    rgbcFilter = nil
    shadowFilter = nil
    outputColorSpace = nil
    outputPixelBufferPool = nil
    outputFormatDescription = nil
    inputFormatDescription = nil
  }
  
  func allocateOutputBufferPool(with inputFormatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) ->(
    outputBufferPool: CVPixelBufferPool?,
    outputColorSpace: CGColorSpace?,
    outputFormatDescription: CMFormatDescription?) {
      
      let inputMediaSubType = CMFormatDescriptionGetMediaSubType(inputFormatDescription)
      if inputMediaSubType != kCVPixelFormatType_32BGRA {
       assertionFailure("Invalid input pixel buffer type \(inputMediaSubType)")
       return (nil, nil, nil)
      }
      
      let inputDimensions = CMVideoFormatDescriptionGetDimensions(inputFormatDescription)
      var pixelBufferAttributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: UInt(inputMediaSubType),
        kCVPixelBufferWidthKey as String: Int(inputDimensions.width),
        kCVPixelBufferHeightKey as String: Int(inputDimensions.height),
        kCVPixelBufferIOSurfacePropertiesKey as String: [:]
      ]
      
      // Get pixel buffer attributes and color space from the input format description.
      var cgColorSpace = CGColorSpaceCreateDeviceRGB()
      if let inputFormatDescriptionExtension = CMFormatDescriptionGetExtensions(inputFormatDescription) as Dictionary? {
        let colorPrimaries = inputFormatDescriptionExtension[kCVImageBufferColorPrimariesKey]
        
        if let colorPrimaries = colorPrimaries {
          var colorSpaceProperties: [String: AnyObject] = [kCVImageBufferColorPrimariesKey as String: colorPrimaries]
          
          if let yCbCrMatrix = inputFormatDescriptionExtension[kCVImageBufferYCbCrMatrixKey] {
            colorSpaceProperties[kCVImageBufferYCbCrMatrixKey as String] = yCbCrMatrix
          }
          
          if let transferFunction = inputFormatDescriptionExtension[kCVImageBufferTransferFunctionKey] {
            colorSpaceProperties[kCVImageBufferTransferFunctionKey as String] = transferFunction
          }
          
          pixelBufferAttributes[kCVBufferPropagatedAttachmentsKey as String] = colorSpaceProperties
        }
        
        if let cvColorspace = inputFormatDescriptionExtension[kCVImageBufferCGColorSpaceKey] {
          cgColorSpace = cvColorspace as! CGColorSpace
        } else if (colorPrimaries as? String) == (kCVImageBufferColorPrimaries_P3_D65 as String) {
          cgColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
        }
      }
      
      // Create a pixel buffer pool with the same pixel attributes as the input format description.
      let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey as String: outputRetainedBufferCountHint]
      var cvPixelBufferPool: CVPixelBufferPool?
      CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes as NSDictionary?, pixelBufferAttributes as NSDictionary?, &cvPixelBufferPool)
      guard let pixelBufferPool = cvPixelBufferPool else {
        assertionFailure("Allocation failure: Could not allocate pixel buffer pool.")
        return (nil, nil, nil)
      }
      
      preallocateBuffers(pool: pixelBufferPool, allocationThreshold: outputRetainedBufferCountHint)
      
      // Get the output format description.
      var pixelBuffer: CVPixelBuffer?
      var outputFormatDescription: CMFormatDescription?
      let auxAttributes = [kCVPixelBufferPoolAllocationThresholdKey as String: outputRetainedBufferCountHint] as NSDictionary
      CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pixelBufferPool, auxAttributes, &pixelBuffer)
      if let pixelBuffer = pixelBuffer {
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                     imageBuffer: pixelBuffer,
                                                     formatDescriptionOut: &outputFormatDescription)
      }
      pixelBuffer = nil
      
      return (pixelBufferPool, cgColorSpace, outputFormatDescription)
  }
  
  private func preallocateBuffers(pool: CVPixelBufferPool, allocationThreshold: Int) {
    var pixelBuffers = [CVPixelBuffer]()
    var error: CVReturn = kCVReturnSuccess
    let auxAttributes = [kCVPixelBufferPoolAllocationThresholdKey as String: allocationThreshold] as NSDictionary
    var pixelBuffer: CVPixelBuffer?
    while error == kCVReturnSuccess {
      error = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, auxAttributes, &pixelBuffer)
      if let pixelBuffer = pixelBuffer {
        pixelBuffers.append(pixelBuffer)
      }
      pixelBuffer = nil
    }
    pixelBuffers.removeAll()
  }
  
  func render(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
    guard
      let blsFilter = self.blsFilter,
      let highlightFilter = self.highlightFilter,
      let shadowFilter = self.shadowFilter,
      let rgbcFilter = self.rgbcFilter,
      let sharpenFilter = self.sharpenFilter,
      let context = self.context
      else {
        assertionFailure("Invaild state: Not prepared")
        return nil
    }
    
    blsFilter.setValue(_parameter["saturation"], forKey: "inputSaturation")
    blsFilter.setValue(_parameter["contrast"], forKey: "inputBrightness")
    blsFilter.setValue(_parameter["level"], forKey: "inputContrast")
    
    highlightFilter.setValue(_parameter["highlights"]! + _parameter["brightnessH"]!, forKey: kCIInputEVKey)
    
    shadowFilter.setValue(_parameter["shadows"]! + (_parameter["brightnessS"]!), forKey: "inputPower")
    
    rgbcFilter.setValue(CIVector(x: 0, y: 1, z: CGFloat(_parameter["red"]!), w: 0),
                        forKey: "inputRedCoefficients")
    rgbcFilter.setValue(CIVector(x: 0, y: 1, z: CGFloat(_parameter["green"]!), w: 0),
                        forKey: "inputGreenCoefficients")
    rgbcFilter.setValue(CIVector(x: 0, y: 1, z: CGFloat(_parameter["blue"]!), w: 0),
                        forKey: "inputBlueCoefficients")
    
    sharpenFilter.setValue(_parameter["sharpeness"], forKey: "inputSharpness")
    
    let sourceImage = CIImage(cvImageBuffer: pixelBuffer)
    
    blsFilter.setValue(sourceImage, forKey: kCIInputImageKey)
    guard let firstFilteredImage = blsFilter.outputImage else {
      print("bright level saturation filter not working.")
      return nil
    }
    
    highlightFilter.setValue(firstFilteredImage, forKey: kCIInputImageKey)
    guard let secondFilteredImage = highlightFilter.outputImage else {
      print("highlight filter not working.")
      return nil
    }
    
    shadowFilter.setValue(secondFilteredImage, forKey: kCIInputImageKey)
    guard let thirdFilteredImage = shadowFilter.outputImage else {
      print("shadow filter not working.")
      return nil
    }
    
    rgbcFilter.setValue(thirdFilteredImage, forKey: kCIInputImageKey)
    guard let fourthFilteredImage = rgbcFilter.outputImage else {
      print("red green blue contrast filter not working.")
      return nil
    }
    
    sharpenFilter.setValue(fourthFilteredImage, forKey: kCIInputImageKey)
    
    guard let finalFilteredImage = sharpenFilter.outputImage else {
      print("sharpen filter not working.")
      return nil
    }
    
    var pbuf: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, outputPixelBufferPool!, &pbuf)
    
    guard let outputPixelBuffer = pbuf else {
      print("Pixel buffer pool allocation failure.")
      return nil
    }
    
    context.render(finalFilteredImage, to: outputPixelBuffer, bounds: finalFilteredImage.extent, colorSpace: outputColorSpace)
       
    return outputPixelBuffer
  }

  
}

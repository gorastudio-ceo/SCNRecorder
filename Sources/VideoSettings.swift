//
//  VideoSettings.swift
//  SCNRecorder
//
//  Created by Vladislav Grigoryev on 26.04.2020.
//  Copyright © 2020 GORA Studio. https://gora.studio
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import AVFoundation

public struct VideoSettings {

  /// The type of the output video file.
  public var fileType: FileType = .mov

  /// The codec used to encode the output video.
  public var codec: Codec = .h264()

  /// The size of the output video.
  ///
  /// If `nil` the size of the video source will be used.
  /// Look at `ScalingMode` for possible scaling modes.
  public var size: CGSize?

  public var scalingMode: ScalingMode = .resizeAspectFill

  /// The transform applied to video frames
  ///
  /// If `nil` an appropriate transform will be applied.
  /// Be carefull, the value is not always obvious.
  public var transform: CGAffineTransform?

    
  /// The metadata of the video
  public var metadata : [AVMetadataItem]?
  
  var videoColorProperties: [String: String]?

  public init(
    fileType: FileType = .mov,
    codec: Codec = .h264(),
    size: CGSize? = nil,
    scalingMode: ScalingMode = .resizeAspectFill,
    transform: CGAffineTransform? = nil,
    metadata: [AVMetadataItem]? = nil
  ) {
    self.fileType = fileType
    self.codec = codec
    self.size = size
    self.scalingMode = scalingMode
    self.transform = transform
    self.metadata = metadata
  }
}

extension VideoSettings {

  var outputSettings: [String: Any] {
    return ([
      AVVideoWidthKey: size?.width,
      AVVideoHeightKey: size?.height,
      AVVideoCodecKey: codec.avCodec,
      AVVideoScalingModeKey: scalingMode.avScalingMode,
      AVVideoColorPropertiesKey: videoColorProperties,
      AVVideoCompressionPropertiesKey: codec.compressionProperties
    ] as [String: Any?]).compactMapValues({ $0 })
  }
}

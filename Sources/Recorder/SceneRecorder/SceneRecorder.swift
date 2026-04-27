//
//  SceneRecorder.swift
//  SceneRecorder
//
//  Created by Vladislav Grigoryev on 11/03/2019.
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
import SceneKit
import CoreMedia

public final class SceneRecorder: BaseRecorder, Renderable, SCNSceneRendererDelegate {

  let videoInput: VideoInput

  init(videoInput: VideoInput, queue: DispatchQueue) {
    self.videoInput = videoInput
    super.init(
      queue: queue,
      mediaSession: MediaSession(queue: queue, videoInput: videoInput)
    )
  }

  public convenience init<T: MetalRecordable>(
    _ recordable: T,
    timeScale: CMTimeScale = 600
  ) throws {
    let queue = DispatchQueue(
      label: "SCNRecorder.Processing.DispatchQueue",
      qos: .userInteractive
    )
    try self.init(
      videoInput: VideoInput(
        recordable: recordable,
        timeScale: timeScale,
        queue: queue
      ),
      queue: queue
    )
  }

  public func render(atTime time: TimeInterval) {
    do {
      try videoInput.render(
        atTime: time,
        error: { [weak self] in self?.error = $0 }
      )
    }
    catch {
      self.error = error
    }
  }

  public func render(atTime time: TimeInterval, using commandQueue: MTLCommandQueue) {
    do {
      try videoInput.render(
        atTime: time,
        using: commandQueue,
        error: { [weak self] in self?.error = $0 }
      )
    }
    catch {
      self.error = error
    }
  }

  public func renderer(
    _ renderer: SCNSceneRenderer,
    didRenderScene scene: SCNScene,
    atTime time: TimeInterval
  ) {
    guard let commandQueue = renderer.commandQueue else { return }
    render(atTime: time, using: commandQueue)
  }
}

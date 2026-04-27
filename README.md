# SCNRecorder

[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/gorastudio/SCNRecorder/master/LICENSE.md)
![Platforms](https://img.shields.io/cocoapods/p/SCNRecorder.svg)
![Swift](https://img.shields.io/badge/swift-5.2-red.svg)
[![Cocoapods compatible](https://img.shields.io/cocoapods/v/SCNRecorder.svg)](https://cocoapods.org/pods/SCNRecorder)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)

SCNRecorder allows you to record videos and to capture images from ARSCNView, SCNView and ARView (RealityKit) without sacrificing performance. It gives you an incredible opportunity to share the media content of your augmented reality app or SceneKit based game.

Starting version 2.2.0 SCNRecorder supports Metal only. 

![Sample](/images/sample2.gif?raw=true )

## Requirements

- iOS 12.0+
- Xcode 12.0+
- Swift 5.0+

## Installation

### CocoaPods

```ruby
pod 'SCNRecorder', '~> 2.9'
```

### Carthage

```ruby
github "gorastudio/SCNRecorder"
```

## Usage

Import the SCNRecorder module.

```swift
import SCNRecorder
```

Call `sceneView.prepareForRecording()` at `viewDidLoad`.

```swift
@IBOutlet var sceneView: SCNView!

override func viewDidLoad() {
  super.viewDidLoad()
  sceneView.prepareForRecording()
}
```

And now you can use new functions to capture videos.

```swift
try sceneView.startVideoRecording()
```

```swift
sceneView.finishVideoRecording { (videoRecording) in 
  /* Process the captured video. Main thread. */
  let controller = AVPlayerViewController()
  controller.player = AVPlayer(url: recording.url)
  self.navigationController?.pushViewController(controller, animated: true)
}
```

To capture an image it is enough to call:

```swift
sceneView.takePhoto { (photo: UIImage) in
  /* Your photo is now here. Main thread. */
}
```
or
```swift
sceneView.takePhotoResult { (result: Result<UIImage, Swift.Error>) in
  /* Result is here. Main thread. */
}
```

Look at the Example project for more details.

### Audio capture

#### ARSCNView

To capture video with audio from `ARSCNView` enable audio in the `ARConfiguration`.

```swift
let configuration = ARWorldTrackingConfiguration()
configuration.providesAudioData = true
sceneView.session.run(configuration)
```

#### SCNView

To capture audio from `SCNView` you have to implement it by yourself.

```swift
var captureSession: AVCaptureSession?

override func viewDidLoad() {
  super.viewDidLoad()
  sceneView.prepareForRecording()
  
  guard let recorder = sceneView.recorder else { return }
  let captureSession = AVCaptureSession()
  
  guard let captureDevice = AVCaptureDevice.default(for: .audio) else { return }
  
  do {
    let captureInput = try AVCaptureDeviceInput(device: captureDevice)
    
    guard captureSession.canAddInput(captureInput) else { return }
    captureSession.addInput(captureInput)
  }
  catch { print("Can't create AVCaptureDeviceInput: \(error)")}
  
  guard captureSession.canAddRecorder(recorder) else { return }
  captureSession.addRecorder(recorder)
  
  captureSession.startRunning()
  self.captureSession = captureSession
}
```
or, simply
```swift
var captureSession: AVCaptureSession?

override func viewDidLoad() {
  super.viewDidLoad()
  sceneView.prepareForRecording()
  
  captureSession = try? .makeAudioForRecorder(sceneView.recorder!)
}
```

 **Known issue:** Capturing audio requires that you provide a valid NSCameraUsageDescription key in the InfoPlist when you submit your app to appstoreconnect. If you are not using the audio recorder, you can exclude the `AVCaptureSession+BaseRecorder.swift` extension from the Target Membership. Doing that fixes appstoreconnect asking for NSCameraUsageDescription key.

### Music Overlay

Instead of capturing audio using microphone you can play music and add it to video at the same time.

```swift

let auidoEngine = AudioEngine()

override func viewDidLoad() {
  super.viewDidLoad()
  
  sceneView.prepareForRecording()
  do {
    audioEngine.recorder = sceneView.recorder
    
    // If true, use sound data from audioEngine if any
    // If false, use sound data ARSession/AVCaptureSession if any
    sceneView.recorder?.useAudioEngine = true
    
    let player = try AudioEngine.Player(url: url)
    audioEngine.player = player
    
    player.play()
  }
  catch { 
    print(\(error))
  }
}
```

### RealityKit

To support recording RealityKit, copy [ARView+MetalRecordable.swift](Example/Source/Content/RealityKit/ARView+MetalRecordable.swift) and [ARView+SelfSceneRecordable.swift](Example/Source/Content/RealityKit/ARView+SelfSceneRecordable.swift) files to your project.
Then look at [RealityKitViewController.swift](Example/Source/Content/RealityKit/RealityKitViewController.swift) for usage.

### That's it!

Look at the Example project for more details.

## Author

- [Vladislav Grigoryev](https://github.com/v-grigoriev)

Thanks to [Fedor Prokhorov](https://github.com/prokhorovxo) and [Dmitry Yurlov](https://github.com/demonukg) for testing, reviewing and inspiration.

## GORA Studio

Made with magic 🪄 at [GORA Studio](https://gora.studio/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details

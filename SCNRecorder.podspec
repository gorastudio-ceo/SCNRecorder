Pod::Spec.new do |s|
  s.name                  = 'SCNRecorder'
  s.version               = '2.9.0'
  s.summary               = 'A lags-free recorder of ARKit and SceneKit for iOS in Swift'
  s.homepage              = 'https://github.com/gorastudio/SCNRecorder'
  s.license               = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author                = { 'Vladislav Grigoryev' => 'dev.grigoriev@gmail.com' }
  s.platform              = :ios, '12.0'
  s.source                = { :git => 'https://github.com/gorastudio-ceo/SCNRecorder.git', :tag => s.version.to_s }
  s.module_name           = 'SCNRecorder'
  s.swift_version         = '5.0'
  s.source_files          = 'Sources/**/*.{swift}'
  s.exclude_files         = 'Sources/Extensions/AVCaptureSession+BaseRecorder.swift'
  s.dependency 'MTDMulticastDelegate'

  s.app_spec 'Example' do |app_spec|
    app_spec.name                = "Example"
    app_spec.platform            = :ios, '13.0'
    app_spec.source_files        = 'Example/Source/**/*.{m,swift,metal}', 'Example/Source/Content/**/*.{h}'
    app_spec.preserve_paths      = 'Example/Source/Example-Bridging-Header.h'
    app_spec.resources           = 'Example/Source/Resources/**/*.{scnassets,xcassets}'
    app_spec.pod_target_xcconfig = {
      "SWIFT_OBJC_BRIDGING_HEADER" => "$(PODS_TARGET_SRCROOT)/Example/Source/Example-Bridging-Header.h"
    }

    app_spec.dependency 'SnapKit', '~> 5.7.1'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.platform            = :ios, '13.0'
    test_spec.requires_app_host   = true
    test_spec.app_host_name       = 'SCNRecorder/Example'
    test_spec.source_files        = 'SCNRecorderTests/**/*.{m,swift,metal}', 'SCNRecorderTests/Metal/**/*.h'
    test_spec.preserve_paths      = 'SCNRecorderTests/SCNRecorderTests-Bridging-Header.h'
    test_spec.pod_target_xcconfig = {
      "SWIFT_OBJC_BRIDGING_HEADER" => "$(PODS_TARGET_SRCROOT)/SCNRecorderTests/SCNRecorderTests-Bridging-Header.h"
    }

    test_spec.dependency 'SCNRecorder/Example'
  end
end



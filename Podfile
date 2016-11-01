platform :ios, '8.0'
use_frameworks!

target 'MonkeyChat' do
  pod 'MonkeyKitUI', '~> 7.4.0'
  pod 'RealmSwift', '~> 1.1.0'
  pod 'SDWebImage', '~> 3.8.1'
  pod 'Whisper', :git => 'https://github.com/hyperoslo/Whisper.git', :branch => 'swift-3'
  pod 'MonkeyKit', :git => 'https://github.com/Criptext/Monkey-SDK-iOS.git', :branch => '1.0.8'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
    end
  end
end

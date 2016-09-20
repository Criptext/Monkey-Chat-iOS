platform :ios, '8.0'
use_frameworks!

target 'MonkeyChat' do
  pod 'MonkeyKitUI'
  pod 'RealmSwift', '~> 1.1.0'
  pod 'SDWebImage'
  pod 'Whisper', :git => 'https://github.com/hyperoslo/Whisper.git', :branch => 'swift-3'
  pod 'MonkeyKit'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
    end
  end
end

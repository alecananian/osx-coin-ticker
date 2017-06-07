platform :osx, '10.10'

target 'CoinTicker' do
  use_frameworks!
  pod 'Alamofire', '~> 4.0'
  pod 'Starscream', '~> 2.0.3'
  pod 'Socket.IO-Client-Swift', '~> 10.0.0'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.2'
        end
    end
end

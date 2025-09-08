Pod::Spec.new do |s|
  s.name                        = "BlueConnect"
  s.version                     = "1.5.1"
  s.summary                     = "A modern approach to Bluetooth LE connectivity built around CoreBluetooth"
  s.license                     = { :type => "MIT", :file => "LICENSE" }
  s.homepage                    = "https://github.com/danielepantaleone/BlueConnect"
  s.authors                     = { "Daniele Pantaleone" => "danielepantaleone@me.com" }
  s.ios.deployment_target       = "13.0"
  s.osx.deployment_target       = "12.0"
  s.source                      = { :git => "https://github.com/danielepantaleone/BlueConnect.git", :tag => "#{s.version}" }
  s.source_files                = "Sources/BlueConnect/**/*.swift"
  s.swift_version               = "5.9"
end

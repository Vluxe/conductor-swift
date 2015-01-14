Pod::Spec.new do |s|
  s.name         = "conductor-swift"
  s.version      = "0.9.1"
  s.summary      = "Conductor client library in Swift."
  s.homepage     = "https://github.com/Vluxe/conductor-swift"
  s.license      = 'Apache License, Version 2.0'
  s.author       = {'Dalton Cherry' => 'http://daltoniam.com'}
  s.source       = { :git => 'https://github.com/Vluxe/conductor-swift.git',  :tag => '0.9.1'}
  s.platform     = :ios, 8.0
  s.source_files = '*.{h,swift}'
  s.dependency   = 'Starscream'
end
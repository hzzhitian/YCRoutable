Pod::Spec.new do |s|
version = "0.2.2"
s.name         = "YCRoutable"
s.version      = version
s.summary      = "A native in-app URL router for iOS."
s.homepage     = "https://github.com/hzzhitian/YCRoutable"
s.author       = { "Hangzhou Zhitian" => "bodimall@163.com" }
s.source       = { :git => "https://github.com/hzzhitian/YCRoutable.git", :tag => version }
s.platform     = :ios, '9.0'
s.source_files = 'YCRoutable/*.{h,m}'
s.requires_arc = true
s.license      = { :type => 'MIT', :file => 'LICENSE' }
end

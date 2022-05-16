#
# Be sure to run `pod lib lint Parallaxable.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Parallaxable'
  s.version          = '1.0.0'
  s.summary          = 'An simple parallaxable controller.'
  s.homepage         = 'https://github.com/SAGESSE-CN/Parallaxable'
  s.author           = { 'SAGESSE' => 'gdmmyzc@163.com' }
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.source           = { :git => 'https://github.com/SAGESSE-CN/Parallaxable.git', :tag => s.version.to_s }
  s.default_subspecs = 'Core'

  s.swift_versions = '5.0'

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '11.0'

  s.subspec 'Core' do |sp|
    sp.source_files = 'Sources/Parallaxable.swift'
  end

  s.subspec 'SwiftUI' do |sp|
	sp.source_files = 'Sources/ParallaxableView.swift'
	sp.dependency 'Parallaxable/Core'
  end

end

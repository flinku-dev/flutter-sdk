#
# flinku_sdk iOS stub — Install Referrer is Android-only; all channel calls return nil.
#
Pod::Spec.new do |s|
  s.name             = 'flinku_sdk'
  s.version          = '0.8.0-beta.2'
  s.summary          = 'Flinku Flutter SDK — deferred deep linking'
  s.description      = <<-DESC
Flinku Flutter plugin. iOS stub returns null for Play Install Referrer (Android-only).
                       DESC
  s.homepage         = 'https://flinku.dev'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Flinku' => 'support@flinku.dev' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end

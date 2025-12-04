Pod::Spec.new do |s|
  s.name             = 'ermis_stream_player'
  s.version          = '0.0.3+1'
  s.summary          = 'FMP4 Stream Player for Flutter'
  s.description      = <<-DESC
A Flutter plugin for streaming FMP4 video with Rust demuxer backend.
                       DESC
  s.homepage         = 'https://github.com/ermisnetwork/ermis_flutter_player.git'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }

  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/ErmisFFI/*.h'
  s.vendored_libraries = 'lib/*.a'

  s.dependency 'Flutter'
  s.dependency 'Starscream', '~> 4.0'
  s.dependency 'Swifter', '~> 1.5.0'

  s.platform = :ios, '13.0'
  s.swift_version = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load $(PODS_TARGET_SRCROOT)/lib/libermis_fmp4_demuxer_binding.a'
  }
end
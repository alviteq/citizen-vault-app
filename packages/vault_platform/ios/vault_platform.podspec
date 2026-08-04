Pod::Spec.new do |s|
  s.name             = 'vault_platform'
  s.version          = '0.2.0'
  s.summary          = 'Citizen Vault native security adapters.'
  s.description      = 'OS random, Keychain, and device-envelope adapters.'
  s.homepage         = 'https://github.com/taraka91/citizen-vault'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Citizen Vault contributors' => 'security@invalid.example' }
  s.source           = { :path => '.' }
  s.source_files     = 'vault_platform/Sources/vault_platform/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end


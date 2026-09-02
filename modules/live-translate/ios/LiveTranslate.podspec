require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'LiveTranslate'
  s.version        = package['version']
  s.summary        = package['description']
  s.license        = package['license']
  s.author         = ''
  s.homepage       = 'https://github.com/ramiz-alsafi/iTranslator'
  s.platform       = :ios, '17.4'
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  s.source_files = '**/*.{h,m,swift}'
end
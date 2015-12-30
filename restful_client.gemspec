lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'restful_client/version'

Gem::Specification.new do |spec|
  spec.name          = 'restful_client'
  spec.version       = RestfulClient::VERSION
  spec.authors       = ['Avner Cohen']
  spec.email         = ['israbirding@gmail.com']
  spec.description   = 'An HTTP framework for micro-services based environment, build on top of Typheous and Service Jynx'
  spec.summary       = 'An HTTP framework for micro-services based environment'
  spec.homepage      = 'https://github.com/AvnerCohen/restful_client'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'

  spec.add_runtime_dependency 'service_jynx'
  spec.add_runtime_dependency 'typhoeus'
end

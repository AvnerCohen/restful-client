# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'restfull_client/version'

Gem::Specification.new do |spec|
  spec.name          = "restfull_client"
  spec.version       = RestfullClient::VERSION
  spec.authors       = ["Avner Cohen"]
  spec.email         = ["israbirding@gmail.com"]
  spec.description   = %q{An HTTP framework for micro-services based environment, build on top of Typheous and Service Jynx}
  spec.summary       = %q{An HTTP framework for micro-services based environment}
  spec.homepage      = "https://github.com/AvnerCohen/restfull_client"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_runtime_dependency "service_jynx"
  spec.add_runtime_dependency "typhoeus"
end


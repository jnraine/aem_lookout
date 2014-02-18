# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dev_loop/version'

Gem::Specification.new do |spec|
  spec.name          = "dev_loop"
  spec.version       = DevLoop::VERSION
  spec.authors       = ["Jordan Raine"]
  spec.email         = ["jnraine@gmail.com"]
  spec.summary       = %q{Speeds up iteration loop while developing for AEM/CQ.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = ["dev_loop"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "vlt_wrapper", "~> 2.4.18"
  spec.add_runtime_dependency "builder", "~> 3.2.2"
  spec.add_runtime_dependency "rb-fsevent", "~> 0.9.4"

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rspec", "~> 2.14.1"
end

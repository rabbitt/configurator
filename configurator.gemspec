# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$:.unshift(lib) unless $:.include?(lib)
require 'configurator/version'

Gem::Specification.new do |spec|
  spec.name          = "configurator"
  spec.version       = Configurator::VERSION
  spec.authors       = ["Carl P. Corliss"]
  spec.email         = ["rabbitt@gmail.com"]
  spec.description   = %q{A library used to create Config classes with validation, type enforcement, casting and other goodies.}
  spec.summary       = %q{Config class builder and loader}
  spec.homepage      = "http://github.com/rabbitt/configurator"
  spec.license       = "GPLv2"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.extra_rdoc_files = ["README.md"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end

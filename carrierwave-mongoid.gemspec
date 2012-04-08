# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "carrierwave/mongoid/version"

Gem::Specification.new do |s|
  s.name        = "carrierwave-mongoid"
  s.version     = Carrierwave::Mongoid::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jonas Nicklas", "Trevor Turk"]
  s.email       = ["jonas.nicklas@gmail.com"]
  s.homepage    = "https://github.com/jnicklas/carrierwave-mongoid"
  s.summary     = %q{Mongoid support for CarrierWave}
  s.description = %q{Mongoid support for CarrierWave}

  s.rubyforge_project = "carrierwave-mongoid"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "carrierwave", ["~> 0.6.1"]
  s.add_dependency "mongoid", ["~> 2.1"]
  s.add_development_dependency "rspec", ["~> 2.6"]
  s.add_development_dependency "bson_ext", ["~> 1.3"]
  s.add_development_dependency "rake", ["~> 0.9"]
  s.add_development_dependency "mini_magick"
end

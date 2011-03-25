=begin
Copyright (c) 2011 Solano Labs All Rights Reserved
=end

# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "tddium_client/version"

Gem::Specification.new do |s|
  s.name        = "tddium_client"
  s.version     = TddiumClient::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jay Moorthi"]
  s.email       = ["info@tddium.com"]
  s.homepage    = "http://www.tddium.com/"
  s.summary     = %q{tddium Client Gem}
  s.description = %q{Internal Gem used to call the Tddium API}
  
  s.rubyforge_project = "tddium_client"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency("httparty")
  s.add_runtime_dependency("json")

  s.add_development_dependency("rspec")
  s.add_development_dependency("fakeweb")
  s.add_development_dependency("fakefs")
  s.add_development_dependency("rack-test")
  s.add_development_dependency("simplecov")
  s.add_development_dependency("rake")
end

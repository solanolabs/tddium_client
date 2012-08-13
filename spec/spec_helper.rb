=begin
Copyright (c) 2011 Solano Labs All Rights Reserved
=end

require "simplecov"
SimpleCov.start
require "tddium_client"
require "rspec"
require "rack/test"
require "webmock/rspec"
require "fakefs/spec_helpers"
require "tddium_client/tddium_spec_helpers"

def fixture_path(fixture_name)
  File.join File.dirname(__FILE__), "fixtures", fixture_name
end

def fixture_data(fixture_name)
  path = File.join File.dirname(__FILE__), "fixtures", fixture_name
  FakeFS.deactivate!
  data = File.read(path)
  FakeFS.activate!
  return data
end

module LastRequest
  def last_request
    @last_request
  end

  def last_request=(request_signature)
    @last_request = request_signature
  end
end

WebMock.extend(LastRequest)
WebMock.after_request do |request_signature, response|
  WebMock.last_request = request_signature
end

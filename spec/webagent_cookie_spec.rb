# Copyright (c) 2011, 2012, 2013, 2014, 2015 Solano Labs All Rights Reserved.

require File.expand_path(File.join(File.dirname(__FILE__),'../lib/tddium_client'))

describe "WebAgent::Cookie" do
  it "get cookie domain" do
    if WebAgent::Cookie.superclass.name == 'HTTP::Cookie'
      cookie = WebAgent::Cookie.new(
        :name=>'hoge1', :value=>'funi', :domain=>'http://www.example.com/', :path=>'/')
      expect(cookie.domain).to eq('http://www.example.com/')
    else
      cookie = WebAgent::Cookie.new
      expect(cookie.domain).to be nil
    end
  end 
end

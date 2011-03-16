=begin
Copyright (c) 2011 Solano Labs All Rights Reserved
=end

require 'fakefs'

module TddiumSpecHelpers

  private

  def register_uri_options(options = {})
    if options.is_a?(Array)
      options_array = []
      options.each do |sub_options|
        options_array << register_uri_options(sub_options)
      end
      options_array
    else
      options_for_fake_web = {:body => options[:body], :status => options[:status]}
      if options[:response]
        FakeFS.deactivate!
        response = File.open(options[:response]) { |f| f.read }
        FakeFS.activate!
        options_for_fake_web.merge!(:response => response)
      end
      options_for_fake_web
    end
  end

  def create_file(path, content = "blah")
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'w') do |f|
      f.write(content)
    end
  end

  def api_uri(path)
    uri = URI.parse("")
    uri.host = tddium_client_config["api"]["host"]
    uri.scheme = tddium_client_config["api"]["scheme"]
    uri.port = tddium_client_config["api"]["port"]
    URI.join(uri.to_s, "#{tddium_client_config["api"]["version"]}/#{path}").to_s
  end

  def tddium_client_config(raw = false, environment = "test")
   unless @tddium_config
     FakeFS.deactivate!
     @tddium_config = File.read(File.join(File.dirname(__FILE__), "..", "..", "config", "environment.yml"))
     FakeFS.activate!
   end
   raw ? @tddium_config : YAML.load(@tddium_config)[environment]
  end
end

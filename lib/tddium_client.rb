=begin
Copyright (c) 2011 Solano Labs All Rights Reserved
=end

require 'rubygems'
require 'httparty'
require 'json'

class TddiumClient
  API_KEY_HEADER = "X-tddium-api-key"
  API_ERROR_TEXT = "An error occured: "

  attr_accessor :environment

  def initialize(env = :development)
    self.environment = env
  end

  def call_api(method, api_path, params = {}, api_key = nil, retries = 5, &block)
    headers = { API_KEY_HEADER => api_key } if api_key

    done = false
    tries = 0
    while (retries < 0 || tries <= retries) && !done
      begin
        http = HTTParty.send(method, tddium_uri(api_path), :body => params, :headers => headers)
        done = true
      rescue Timeout::Error
      ensure
        tries += 1
      end
    end

    raise Timeout::Error if tries > retries

    response = JSON.parse(http.body) rescue {}

    if http.success?
      (response["status"] == 0 && block_given?) ? yield(response) : message = API_ERROR_TEXT + response["explanation"].to_s
    else
      message = API_ERROR_TEXT + http.response.header.msg.to_s
      message << " #{response["explanation"]}" if response["status"].to_i > 0
    end
    [response["status"], http.code, message]
  end

  private

  def tddium_uri(path)
    uri = URI.parse("")
    uri.host = tddium_config["api"]["host"]
    uri.port = tddium_config["api"]["port"]
    uri.scheme = tddium_config["api"]["scheme"]
    URI.join(uri.to_s, "#{tddium_config["api"]["version"]}/#{path}").to_s
  end

  def tddium_config
   unless @tddium_config
     @tddium_config = YAML.load(
       File.read(File.join(File.dirname(__FILE__), "..", "config", "environment.yml"))
     )[environment.to_s]
   end
   @tddium_config
  end
end


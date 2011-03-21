=begin
Copyright (c) 2011 Solano Labs All Rights Reserved
=end

require 'rubygems'
require 'httparty'
require 'json'

module TddiumClient
  API_KEY_HEADER = "X-tddium-api-key"
  API_ERROR_TEXT = "An error occured: "

  class Error < RuntimeError; end
  class TimeoutError < TddiumClient::Error; end
  
  class APIError < TddiumClient::Error
    attr_accessor :tddium_result

    def initialize(result)
      self.tddium_result = result
    end
  end

  class ServerError < TddiumClient::Error
    attr_accessor :http_code, :http_result

    def initialize(http_code, http_result)
      self.http_code = http_code
      self.http_result = http_result
    end
  end

  class Result
    attr_accessor :http_code, :http_result, :response

    def initialize(http_code, http_result, response)
      self.http_code = http_code
      self.http_result = http_result
      self.response = response
    end

    def success?
      !response.nil? && response.is_a?(Hash) && response["status"] == 0
    end
  end

  class Client
    attr_accessor :environment

    def initialize(env = :development)
      self.environment = env
    end

    def call_api(method, api_path, params = {}, api_key = nil, retries = 5)
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

      raise TimeoutError if tries > retries

      response = JSON.parse(http.body) rescue {}

      http_message = http.response.header.msg.to_s

      raise ServerError.new(http.code, http_message) if !response.is_a?(Hash)
      
      result = Result.new(http.code, http.response.header.msg.to_s, response)

      raise APIError.new(result) if !result.success?

      result
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
     @tddium_config = YAML.load(File.read(File.join(File.dirname(__FILE__), "..", "config", "environment.yml")))[environment.to_s] unless @tddium_config
     @tddium_config
    end
  end
end

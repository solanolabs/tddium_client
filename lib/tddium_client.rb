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

    def http_code
      self.tddium_result.http_code if self.tddium_result
    end

    def http_result
      self.tddium_result.http_result if self.tddium_result
    end

    def to_s
      "#{http_code} #{http_result} (#{self.tddium_result.status}) #{self.tddium_result.explanation}"
    end

    def message
      "API Error: #{to_s}"
    end
  end

  class ServerError < TddiumClient::Error
    attr_accessor :http_code, :http_result

    def initialize(http_code, http_result)
      self.http_code = http_code
      self.http_result = http_result
    end

    def to_s
      "#{http_code} #{http_result}"
    end

    def message
      "Server Error: #{to_s}"
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
      has_response? && response["status"] == 0
    end

    def has_response?
      !response.nil? && response.is_a?(Hash) 
    end

    def status
      has_response? ? response["status"] : nil
    end
      
    def explanation
      has_response? ? response["explanation"] : nil
    end
  end

  class Client
    attr_reader :environment

    def initialize(env = :development)
      @all_config = YAML.load(File.read(config_path))
      self.environment = env.to_s
    end

    def environment=(new_environment)
      env = new_environment.to_s
      raise ArgumentError, "Invalid environment #{env}" unless @all_config[env]
      @tddium_config = @all_config[env]
      @environment = env
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

      raise ServerError.new(http.code, http_message) unless response.is_a?(Hash) && response.include?("status")
      
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

      def config_path
        File.join(File.dirname(__FILE__), "..", "config", "environment.yml")
      end

      def tddium_config
        @tddium_config
      end
  end
end

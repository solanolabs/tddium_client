=begin
Copyright (c) 2011 Solano Labs All Rights Reserved
=end

require 'rubygems'
require 'httparty'
require 'json'

module TddiumClient
  API_KEY_HEADER = "X-tddium-api-key"
  API_ERROR_TEXT = "An error occured: "

  module Error
    class Base < RuntimeError; end
  end

  module Result
    class Base < Error::Base
      attr_accessor :http_response

      def initialize(http_response)
        self.http_response = http_response
      end

      def http_code
        http_response.code
      end

      def http_message
        http_response.response.header.msg.to_s
      end
    end

    class Abstract < Base
      attr_accessor :tddium_response

      def initialize(http_response)
        super
        self.tddium_response = JSON.parse(http_response.body) rescue {}
      end

      def [](value)
        tddium_response[value]
      end
    end

    class API < Abstract
      def initialize(http_response)
        super
        raise TddiumClient::Error::Server.new(http_response) unless tddium_response.include?("status")
        raise TddiumClient::Error::API.new(http_response) unless tddium_response["status"] == 0
      end
    end
  end

  module Error
    class Timeout < Base; end

    class Server < TddiumClient::Result::Base
      def to_s
        "#{http_code} #{http_message}"
      end

      def message
        "Server Error: #{to_s}"
      end
    end

    class API < TddiumClient::Result::Abstract
      def initialize(http_response)
        super
      end

      def to_s
        "#{http_code} #{http_message} (#{status}) #{explanation}"
      end

      def message
        "API Error: #{to_s}"
      end

      def explanation
        tddium_response["explanation"]
      end

      def status
        tddium_response["status"]
      end
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

      raise Error::Timeout if tries > retries && retries >= 0

      Result::API.new(http)
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

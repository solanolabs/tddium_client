# Copyright (c) 2011-2018 Solano Labs. All Rights Reserved

require 'rubygems'
require 'json'
require 'yaml'
require 'httpclient'
require 'securerandom'
require File.expand_path("../tddium_client/version", __FILE__)
require 'webagent_cookie'

module TddiumClient
  API_KEY_HEADER = "X-Tddium-Api-Key"
  CLIENT_VERSION_HEADER = "X-Tddium-Client-Version"
  API_ERROR_TEXT = "An error occured: "

  ERRORS = [ Errno::ECONNREFUSED,
             Errno::ETIMEDOUT,
             Timeout::Error,
             OpenSSL::SSL::SSLError,
             OpenSSL::SSL::Session::SessionError,
             HTTPClient::TimeoutError,
             HTTPClient::BadResponseError,
             SocketError ]

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
        v = http_response.header.send(:reason_phrase)
        return v
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
        raise TddiumClient::Error::UpgradeRequired.new(http_response) if http_response.code == 426
        raise TddiumClient::Error::API.new(http_response) unless tddium_response["status"] == 0
      end
    end
  end

  module Error
    class Timeout < Base; end

    class APICert < Base
      def initialize(err)
        @err = err
      end

      def message
       "API Cert Error: #{@err}"
     end
   end

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

  class UpgradeRequired < API
    def initialize(http_response)
      super
    end

    def message
      "API Error: #{explanation}"
    end
  end
end

class InternalClient
  attr_reader :client

  def initialize(host, port=nil, scheme='https', version=1, caller_version=nil, options={})
    @debug = ENV['SOLANO_CLIENT_DEBUG']=='true' || false
    @client = HTTPClient.new
    if options[:insecure]
      @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    @client.ssl_config.set_trust_ca(File.join(File.dirname(__FILE__), "..", "config", "GE_External_Root_CA_2_1.pem"))

    uri = URI.parse("")
    uri.host = host
    uri.port = port
    uri.scheme = scheme

    cookies = options[:cookies] || {}
    cookies.each_pair do |name, value|
        cookie = WebAgent::Cookie.new
        cookie.name = name
        cookie.value = value
        cookie.url = uri

        @client.cookie_manager.add(cookie)
    end

    if options[:receive_timeout] then
      @client.receive_timeout = options[:receive_timeout].to_i
    end

      
    @tddium_config = {"host" => host,
                      "port" => port,
                      "scheme" => scheme,
                      "version" => version,
                      "caller_version" => caller_version}
    end

    def call_api(method, api_path, params = {}, api_key = nil, retries = 5, xid=nil)
      headers = {'Content-Type' => 'application/json'}
      headers.merge!(API_KEY_HEADER => api_key) if api_key
      headers.merge!(CLIENT_VERSION_HEADER => version_header)

      xid ||= xid_gen
      call_params = params.merge({:xid => xid})

      tries = 0
      debug_msg({:method => method, :path => tddium_uri(api_path), :headers => headers, :body => call_params.to_json})
      begin
        http = @client.send(method, tddium_uri(api_path), :body => call_params.to_json, :header => headers)
      rescue *ERRORS => e
        raise Error::APICert.new(e) if e.message =~ /certificate verify failed/
        tries += 1
        delay = (tries>>1)*0.05*rand()
        Kernel.sleep(delay)
        retry if retries > 0 && tries <= retries
      end

      raise Error::Timeout if retries >= 0 && tries > retries
      res = Result::API.new(http)
      debug_msg({:result => res.tddium_response})
      return res
    end

    def caller_version
      @tddium_config["caller_version"]
    end

    def caller_version=(version)
      @tddium_config["caller_version"] = version
    end

    def xid_gen
      return SecureRandom.hex(8)
    end

    protected

    def debug_msg(msg={})
      return unless @debug
      STDERR.puts " "
      STDERR.puts "TDDIUM CLIENT DEBUG:"
      msg.each do |key, value|
        STDERR.puts "#{key}: #{value}"
      end
      STDERR.puts " "
    end

    def version_header
      hdr = "tddium_client-#{TddiumClient::VERSION}"
      hdr += ";#{caller_version}" if caller_version
      hdr
    end

    def tddium_uri(path)
      uri = URI.parse("")
      uri.host = tddium_config["host"]
      uri.port = tddium_config["port"]
      uri.scheme = tddium_config["scheme"]
      URI.join(uri.to_s, "#{tddium_config["version"]}/#{path}").to_s
    end

    def tddium_config
      @tddium_config
    end
  end


  class Client < InternalClient
    attr_reader :environment

    def initialize(env = :development, caller_version=nil, options={})
      @all_config = YAML.load(File.read(config_path))
      self.environment = env.to_s
      self.caller_version = caller_version

      super(host, port, scheme, version, caller_version, options)
    end

    def environment=(new_environment)
      env = new_environment.to_s
      raise ArgumentError, "Invalid environment #{env}" unless @all_config[env]
      @tddium_config = @all_config[env]["api"]
      @environment = env
    end

    def host
      @tddium_config["host"]
    end

    def port=(port)
      @tddium_config["port"] = port
    end

    def port
      @tddium_config["port"]
    end

    def scheme
      @tddium_config["scheme"]
    end

    def version
      @tddium_config["version"]
    end

    private

    def config_path
      File.join(File.dirname(__FILE__), "..", "config", "environment.yml")
    end
  end
end

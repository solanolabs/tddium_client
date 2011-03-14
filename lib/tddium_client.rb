require 'httparty'
require 'json'
class TddiumClient
  API_KEY_HEADER = "X-tddium-api-key"
  API_ERROR_TEXT = "An error occured: "

  attr_accessor :environment

  def initialize(env = :development)
    self.environment = env
  end

  def call_api(method, api_path, params = {}, api_key = nil, &block)
    headers = { API_KEY_HEADER => api_key } if api_key
    http = HTTParty.send(method, tddium_uri(api_path), :body => params, :headers => headers)
    response = JSON.parse(http.body) rescue {}

    if http.success?
      if response["status"] == 0
        yield response
      else
        message = API_ERROR_TEXT + response["explanation"].to_s
      end
    else
      message = API_ERROR_TEXT + http.response.header.msg.to_s
      message << " #{response["explanation"]}" if response["status"].to_i > 0
    end
    message ? [response["status"] || http.code, message] : nil
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


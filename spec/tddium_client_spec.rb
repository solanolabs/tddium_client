=begin
Copyright (c) 2011 Solano Labs All Rights Reserved
=end

require "spec_helper"

describe "TddiumClient" do
  let(:http_response) { mock(Net::HTTP).as_null_object }

  def stub_sample_api_response(options = {})
    options[:status]
    return_value = ""
    unless options[:status] == false
      options[:success] = true unless options[:success] == false
      return_value = {"status" => options[:success] ? 0 : 1}
      return_value.merge!(:explanation => options[:explanation] || "User not found") unless options[:success]
      return_value = return_value.to_json
    end
    http_response.stub(:body).and_return(return_value)
  end

  def stub_http_code(code = "401")
    http_response.stub(:code).and_return(code)
  end

  def stub_http_message(message = "Unauthorized")
    http_response.stub_chain(:response, :header, :msg).and_return(message)
  end

  describe "Response" do

    shared_examples_for "base" do
      describe "#http_code" do
        before {stub_http_code("200")}
        it "should return the http status code from the response" do
          base.http_code.should == "200"
        end
      end

      describe "#http_message" do
        before {stub_http_message("OK")}
        it "should return the http message from the response" do
          base.http_message.should == "OK"
        end
      end

      describe "#http_response" do
        it "should return the http response" do
          base.http_response.should == http_response
        end
      end
    end

    shared_examples_for "abstract" do
      it_should_behave_like "base" do
        let(:base) { TddiumClient::Result::API.new(http_response) }
      end

      before { stub_sample_api_response }

      describe "#tddium_response" do
        it "should return the parsed tddium_response" do
          abstract.tddium_response.should == {"status" => 0}
        end
      end

      describe "#[]" do
        it "should return the result from the tddium_response" do
          abstract["status"].should == 0
        end
      end
    end

    describe "Base" do
      it_should_behave_like "base" do
        let(:base) {TddiumClient::Result::Base.new(http_response)}
      end
    end

    describe "Abstract" do
      it_should_behave_like "abstract" do
        let(:abstract) { TddiumClient::Result::Abstract.new(http_response) }
      end
    end

    describe "API" do
      let(:api) { TddiumClient::Result::API.new(http_response) }
      it_should_behave_like "abstract" do
        let(:abstract) { api }
      end

      context "no status is included in the response" do
        before {stub_sample_api_response(:status => false) }

        it "should raise a ServerError" do
          expect {
            TddiumClient::Result::API.new(http_response)
          }.to raise_error(TddiumClient::Error::Server)
        end
      end

      context "a status is included in the response but it does not == 0" do
        before {stub_sample_api_response(:success => false) }

        it "should raise an APIError" do
          expect {
            TddiumClient::Result::API.new(http_response)
          }.to raise_error(TddiumClient::Error::API)
        end
      end

      context "a status is included in the response and it == 0" do
        before {stub_sample_api_response }
        it "should return a new instance of Response::Client" do
          TddiumClient::Result::API.new(http_response).should be_a(TddiumClient::Result::API)
        end
      end
    end
  end

  describe "Error" do
    shared_examples_for "#to_s" do
      before do
        stub_http_code("401")
        stub_http_message("Unauthorized")
      end

      it "should contain the http code" do
        result.should include("401")
      end

      it "should contain the http message" do
        result.should include("Unauthorized")
      end
    end

    describe "Server" do
      let(:server_error) { TddiumClient::Error::Server.new(http_response) }

      it_should_behave_like("base") do
        let(:base) { server_error }
      end

      describe "#to_s" do
        it_should_behave_like("#to_s") do
          let(:result) {server_error.to_s}
        end
      end

      describe "#message" do
        it_should_behave_like("#to_s") do
          let(:result) {server_error.message}
        end

        it "should start with 'Server Error:'" do
          server_error.message.should =~ /^Server Error:/
        end
      end
    end

    describe "API" do
      let(:api_error) { TddiumClient::Error::API.new(http_response) }

      it_should_behave_like("abstract") do
        let(:abstract) { api_error }
      end

      describe "#to_s" do
        it_should_behave_like("#to_s") do
          let(:result) {api_error.to_s}
        end
      end

      describe "#message" do
        before do
          stub_sample_api_response(:success => false, :explanation => "User is invalid")
        end

        it_should_behave_like("#to_s") do
          let(:result) {api_error.message}
        end

        it "should start with 'API Error:'" do
          api_error.message.should =~ /^API Error:/
        end

        it "should include the api status in brackets ()" do
          api_error.message.should include("(1)")
        end

        it "should include the api explanation" do
          api_error.message.should include("User is invalid")
        end

      end
    end
  end

  describe "InternalClient" do
    pending "implement InternalClient tests"
  end

  describe "Client" do
    include FakeFS::SpecHelpers
    include TddiumSpecHelpers

    EXAMPLE_HTTP_METHOD = :post
    EXAMPLE_TDDIUM_RESOURCE = "suites"
    EXAMPLE_PARAMS = {"key" => "value"}
    EXAMPLE_API_KEY = "afb12412bdafe124124asfasfabebafeabwbawf1312342erbfasbb"

    def stub_http_response(method, path, options = {})
      uri = api_uri(path)
      FakeWeb.register_uri(method, uri, register_uri_options(options))
    end

    def parse_request_params
      Rack::Utils.parse_nested_query(FakeWeb.last_request.body)
    end

    let(:tddium_client) { TddiumClient::Client.new }

    describe "#environment" do
      before(:each) do
        stub_tddium_client_config
      end

      it "should raise on init if environment can't be found" do
        expect { TddiumClient::Client.new('foobar') }.to raise_error(ArgumentError)
      end

      it "should set the default environment to :development" do
        tddium_client.environment.should == 'development'
      end
      it "should set the environment" do
        tddium_client.environment = :production
        tddium_client.environment.should == 'production'
      end
    end

    describe "#port" do
      before(:each) do
        stub_tddium_client_config
      end

      it "should set the port" do
        tddium_client.port = 2345
        tddium_client.port.should == 2345
      end
    end

    describe "#call_api" do
      before do
        FakeWeb.clean_registry
        stub_tddium_client_config
        stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :response => fixture_path("post_suites_201.json"))
      end

      context "('#{EXAMPLE_HTTP_METHOD}', '#{EXAMPLE_TDDIUM_RESOURCE}')" do
        it "should make a '#{EXAMPLE_HTTP_METHOD.to_s.upcase}' request to the api" do
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)
          FakeWeb.last_request.method.downcase.to_sym.should == EXAMPLE_HTTP_METHOD
        end

        it "should make a request to the correct resource" do
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)
          FakeWeb.last_request.path.should =~ /#{EXAMPLE_TDDIUM_RESOURCE}$/
        end
      end

      context "raises a timeout error" do
        before do
          HTTParty.stub(EXAMPLE_HTTP_METHOD).and_raise(Timeout::Error)
        end

        it "should retry 5 times by default to contact the API" do
          HTTParty.should_receive(EXAMPLE_HTTP_METHOD).exactly(6).times
          expect { tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE) }.to raise_error(TddiumClient::Error::Timeout)
        end

        it "should retry as many times as we want to contact the API" do
          HTTParty.should_receive(EXAMPLE_HTTP_METHOD).exactly(3).times
          expect { tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, {}, nil, 2) }.to raise_error(TddiumClient::Error::Timeout)
        end
      end

      context "('#{EXAMPLE_HTTP_METHOD}', '#{EXAMPLE_TDDIUM_RESOURCE}', {}, #{EXAMPLE_API_KEY}) # with api_key" do
        it "should include #{TddiumClient::API_KEY_HEADER}=#{EXAMPLE_API_KEY} in the request headers" do
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, {}, EXAMPLE_API_KEY)
          FakeWeb.last_request[TddiumClient::API_KEY_HEADER].should == EXAMPLE_API_KEY
        end
      end

      context "('#{EXAMPLE_HTTP_METHOD}', '#{EXAMPLE_TDDIUM_RESOURCE}') # without api_key" do
        it "should not include #{TddiumClient::API_KEY_HEADER} in the request headers" do
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, {})
          FakeWeb.last_request[TddiumClient::API_KEY_HEADER].should be_nil
        end
      end

      context "('#{EXAMPLE_HTTP_METHOD}', '#{EXAMPLE_TDDIUM_RESOURCE}', #{EXAMPLE_PARAMS}) # with params" do
        it "should include #{EXAMPLE_PARAMS} in the request params" do
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, EXAMPLE_PARAMS)
          parse_request_params.should include(EXAMPLE_PARAMS)
        end
      end

      context "('#{EXAMPLE_HTTP_METHOD}', '#{EXAMPLE_TDDIUM_RESOURCE}') # without params" do
        it "should not include any request params" do
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)
          parse_request_params.should == {}
        end
      end

      context "results in a successful response" do
        before do
          stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :response => fixture_path("post_suites_201.json"))
        end

        it "should try to contact the api only once" do
          HTTParty.should_receive(EXAMPLE_HTTP_METHOD).exactly(1).times.and_return(mock(HTTParty).as_null_object)
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, {}, nil) rescue {}
        end

        it "should return a TddiumClient::Result::Client" do
          result = tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, {}, nil)
          result.should be_a(TddiumClient::Result::API)
        end

        it "should parse the JSON response" do
          result = tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, {}, nil)
          result.tddium_response["status"].should == 0
          result.tddium_response["suite"]["id"].should == 19
        end
      end

      context "the response has no 'status' in the body" do
        before { stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :status => ["501", "Internal Server Error"]) }
        it "should raise a TddiumClient::Error::Server" do
          expect {
            tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)
          }.to raise_error(TddiumClient::Error::Server)
        end
      end

      context "where the http request was successful but API status is not 0" do
        before { stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :response => fixture_path("post_suites_269_json_status_1.json")) }

        it "should raise a TddiumClient::Error::API Error" do
          expect { tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE) }.to raise_error(TddiumClient::Error::API)
        end
      end
    end
  end
end

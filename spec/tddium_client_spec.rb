=begin
Copyright (c) 2011 Solano Labs All Rights Reserved
=end

require "spec_helper"

describe TddiumClient::Result do
  describe "#success?" do
    context "with successful params" do
      before(:each) do
        @res = TddiumClient::Result.new 200, "OK", {"status" => 0}
      end

      it "should be true" do
        @res.should be_success
      end
    end

    context "with unsuccessful params" do
      it "should handle no response" do
        @res = TddiumClient::Result.new 200, "OK", nil
        @res.should_not be_success
      end

      it "should handle 5xx" do
        @res = TddiumClient::Result.new 501, "Internal Server Error", {"status" => 1}
        @res.should_not be_success
      end
    end
  end
end

describe TddiumClient::Client do
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

  it "should set the default environment to :development" do
    tddium_client.environment.should == :development
  end

  describe "#environment" do
    it "should set the environment" do
      tddium_client.environment = :production
      tddium_client.environment.should == :production
    end
  end

  describe "#call_api" do
    before(:each) do
      FakeWeb.clean_registry
      stub_tddium_client_config
      stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, 
                         :body => '{"status": 0}',
                         :status => [200, "OK"])
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

    context "raises an error" do
      before do
        HTTParty.stub(EXAMPLE_HTTP_METHOD).and_raise(Timeout::Error)
      end

      it "should retry 5 times by default to contact the API" do
        HTTParty.should_receive(EXAMPLE_HTTP_METHOD).exactly(6).times
        expect { tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE) }.to raise_error(TddiumClient::TimeoutError)
      end

      it "should retry as many times as we want to contact the API" do
        HTTParty.should_receive(EXAMPLE_HTTP_METHOD).exactly(3).times
        expect { tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, {}, nil, 2) }.to raise_error(TddiumClient::TimeoutError)
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

      it "should return a TddiumClient::Result" do
        result = tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, {}, nil)
        result.should be_a(TddiumClient::Result)
      end

      it "should parse the JSON response" do
        result = tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, {}, nil)
        result.http_code.should == 201
        result.response.should be_a(Hash)
        result.response["status"].should == 0
        result.should be_success
        result.response["suite"]["id"].should == 19
      end
    end

    context "exceptions for an unprocessable response" do
      before { stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :status => ["501", "Internal Server Error"]) }
      it "should raise a TddiumClient::ServerError" do
        expect do
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)
        end.to raise_error do |error| 
          puts error.inspect
          error.should be_a(TddiumClient::ServerError)
          error.should respond_to(:http_code)
          error.http_code.should == 500
          error.http_message.should =~ /Internal Server Error/
        end
      end

      context "when no response is present" do
        before { stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :status => ["200", "OK"]) }
        it "should raise a TddiumClient::ServerError" do
          expect do
            tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)
          end.to raise_error do |error| 
            error.should be_a(TddiumClient::ServerError)
            error.should respond_to(:http_code)
            error.http_code.should == 200
            error.http_message.should =~ /OK/
          end
        end
      end
    end

    shared_examples_for "raising an APIError" do
      # users can set:
      #
      # aproc
      # http_code
      # http_message
      it "should raise the right exception" do
        expect { aproc.call }.to raise_error do |error|
          error.should be_a(TddiumClient::APIError)
          error.should respond_to(:tddium_result)
          error.tddium_result.should be_a(TddiumClient::Result)
        end
      end

      it "should capture the http response line" do
        expect { aproc.call }.to raise_error do |error|
          error.tddium_result.http_code.should == http_code if http_code
          error.tddium_result.http_message.should == http_message if http_message
        end
      end
    end

    context "where the http request was successful but API status is not 0" do
      before { stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :response => fixture_path("post_suites_269_json_status_1.json")) }

      it_should_behave_like "raising an APIError" do
        let(:aproc) { Proc.new { tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE) } }
        let(:http_code) {269}
      end
    end

    context "exceptions for an error response" do
      before { stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :status => ["404", "Not Found"]) }
      it_should_behave_like "raising an APIError" do
        let(:aproc) { Proc.new { tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE) } }
        let(:http_code) {404}
      end

      context "and an API error is returned" do
        before { stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :response => fixture_path("post_suites_409.json")) }
        it_should_behave_like "raising an APIError" do
          let(:aproc) { Proc.new { tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE) } }
          let(:http_code) {409}
        end

        it "should have an api status" do
          expect do
            tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)
          end.to raise_error do |error|
            error.tddium_result.response[:status].should == 1
          end
        end
      end
    end
  end
end

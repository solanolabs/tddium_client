require "spec_helper"
describe TddiumClient do
  include FakeFS::SpecHelpers
  include TddiumSpecHelpers

  EXAMPLE_HTTP_METHOD = :post
  EXAMPLE_TDDIUM_RESOURCE = "suites"
  EXAMPLE_PARAMS = {"key" => "value"}
  EXAMPLE_API_KEY = "afb12412bdafe124124asfasfabebafeabwbawf1312342erbfasbb"

  def stub_tddium_client_config
    create_file(File.join("config", "environment.yml"), tddium_client_config(true))
  end

  def stub_http_response(method, path, options = {})
    uri = api_uri(path)
    FakeWeb.register_uri(method, uri, register_uri_options(options))
  end

  let(:tddium_client) { TddiumClient.new }

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
    before do
      FakeWeb.clean_registry
      stub_tddium_client_config
      stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)
    end

    context "('#{EXAMPLE_HTTP_METHOD}', '#{EXAMPLE_TDDIUM_RESOURCE}')" do
      it "should make a '#{EXAMPLE_HTTP_METHOD.to_s.upcase}' request to the api" do
        tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)
        FakeWeb.last_request.method.downcase.to_sym.should == EXAMPLE_HTTP_METHOD
      end
    end

    context "('#{EXAMPLE_HTTP_METHOD}', '#{EXAMPLE_TDDIUM_RESOURCE}')" do
      it "should make a request to the correct resource" do
        tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)
        FakeWeb.last_request.path.should =~ /#{EXAMPLE_TDDIUM_RESOURCE}$/
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
        @block_is_called = false
        @dummy_block = Proc.new { @block_is_called = true }
      end
      it "should yield to the given block" do
        tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, {}, nil, &@dummy_block)
        @block_is_called.should == true
      end

      it "should return nil" do
        tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, {}, nil, &@dummy_block).should be_nil
      end
    end

    context "results in an unsuccessful response" do
      before { stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :status => ["404", "Not Found"]) }

      shared_examples_for "returning that an error occured" do
        it "should return that an error occured in the second element" do
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)[1].should =~ /^#{TddiumClient::API_ERROR_TEXT}/
        end
      end

      shared_examples_for("returning the API error") do
        it "should return the API error in the second element" do
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)[1].should =~ /\{\:suite_name\=\>\[\"has already been taken\"\]\}$/
        end
      end

      it "should return an array with two elements" do
        tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE).size.should == 2
      end

      context "where the http request was successful but API status is not 0" do
        before { stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :response => fixture_path("post_suites_201_json_status_1.json")) }
        it_should_behave_like("returning that an error occured")
        it_should_behave_like("returning the API error")

        it "should return the API error code in the first element" do
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)[0].should == 1
        end
      end

      context "where the http request was unsuccessful" do
        before { stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :status => ["501", "Internal Server Error"]) }
        it_should_behave_like("returning that an error occured")

        it "should return the HTTP error message in the second element" do
          tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)[1].should =~ /Internal Server Error/
        end

        context "and an API error is returned" do
          before { stub_http_response(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE, :response => fixture_path("post_suites_409.json")) }
          it_should_behave_like("returning the API error")
          it "should return the HTTP error code in the first element" do
            tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)[0].should == 1
          end
        end

        context "and no API error is returned" do
          it "should return the HTTP error code in the first element" do
            tddium_client.call_api(EXAMPLE_HTTP_METHOD, EXAMPLE_TDDIUM_RESOURCE)[0].should == 501
          end
        end
      end
    end
  end
end

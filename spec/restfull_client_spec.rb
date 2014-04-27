require 'spec_helper'

require 'pry'

def set_global(class_name)
  $some_global = class_name
end

describe :RestfullClient do

  before(:all) do
    # Start a local rack server to serve up test pages.
    server_thread = Thread.new do
      Rack::Handler::Thin.run MyApp::Test::Server.new, :Port => 8383
    end
    sleep(3) # wait a sec for the server to be booted
  end

  before(:each) do
    $some_global = nil
    Typhoeus::Expectation.clear
    RestfullClient.configuration.reset if RestfullClient.configuration
  end

  describe "Configuration" do

    it "raise when file_name not sent in" do
      expect { RestfullClient.configure { } }.to raise_error
    end

    it "correctly read configuration files" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
      end

      expect(RestfullClient.configuration.data).to_not eq(nil)
    end

    it "allow accesing url configuration" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
      end

      expect(RestfullClient.configuration.data["posts"]["url"]).to eq("http://1.2.3.4:8383/api/v1/")
    end

    it "allow accesing url configuration by environment" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
      end

      expect(RestfullClient.configuration.data["posts"]["url"]).to eq("http://1.2.3.4:8383/api/v0/")
    end

    it "allow should access with legacy configuration as well" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
        config.legacy_postfix = "_service"
      end

      expect(RestfullClient.callerr_config("pompa")["url"]).to_not eq(nil)
    end

    it "should register jynx with correct name in case of legacy" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
        config.legacy_postfix = "_service"
      end


      expect(ServiceJynx.alive?("pompa")).to eq(true)
    end


    it "have a logger" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
      end

      expect(RestfullClient.logger).to respond_to :info
    end

    it "correctly read the configuration from the registry" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
      end

      expect(RestfullClient.callerr_config("posts")["url"]).to eq("http://1.2.3.4:8383/api/v0/")
    end

    it "have a timeout defined for the service by default" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
      end

      expect(RestfullClient.timeout).to eq(10)
    end

    it "have a timeout defined for the service by default" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
        config.timeout = 2
      end

      expect(RestfullClient.timeout).to eq(2)
    end

    it "have a user agent defined for the service by default" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
      end

      expect(RestfullClient.user_agent).to eq(RestfullClientConfiguration::DEFAULT_USER_AGENT)
    end

    it "have a user agent defined for the service" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
        config.user_agent = "users_service"
      end

      expect(RestfullClient.user_agent).to eq("users_service")
    end

    it "have a retries defined for the service by default" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
      end

      expect(RestfullClient.retries).to eq(2)
    end

    it "have a retries defined for the service by default" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
        config.retries = 15
      end

      expect(RestfullClient.retries).to eq(15)
    end

  end

  describe "toJson" do

    it "automatically run to_json on an object" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
      end

      some_object = {"moshe" => "test"}
      res = RestfullClient.post("locally", "/bounce", some_object) { |m| m }

      expect(res).to eq(some_object)
    end

    it "doesn't re-run json on data that was already a json object" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
      end

      some_object = {"moshe" => "test"}.to_json
      res = RestfullClient.post("locally", "/bounce", some_object) { |m| m }

      expect(res).to eq(JSON.parse(some_object))
    end

  end

  describe "Restfull Calls" do

    it "allow sending in a reporting method (such as graylog/ airbrake instrumentiation)" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
        config.report_method = proc do |*args|
          klass, message = *args
          set_global(klass)
        end
      end
      RestfullClient.configuration.report_on

      expect($some_global).to eq("RestfullClientConfiguration")
    end

    it "report on a server error (end-2-end ish test)" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
        config.timeout = 1
        config.report_method = proc do |*args|
          klass, message = *args
          set_global(klass)
        end
      end
      RestfullClient.get("posts", "/a/a/a/a") { nil }

      expect($some_global).to eq("RestError")
    end

    it "do not report on a client side error (http_code < 500)" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
        config.report_method = proc do |*args|
          klass, message = *args
          set_global(klass)
        end
      end
      RestfullClient.get("locally", "/client_error") { nil }

      expect($some_global).to be_nil
    end

    it "do not report on a missing resource (http_code == 404)" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
        config.report_method = proc do |*args|
          klass, message = *args
          set_global(klass)
        end
      end

      RestfullClient.get("locally", "/non_existing") { nil }

      expect($some_global).to be_nil
    end

  end

  describe "Retry call count" do

    it "repeat the call if retry is set " do

      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
        config.retries = 3
        config.timeout = 2
        config.report_method = proc do |*args|
          klass, message = *args
          set_global(klass)
        end
      end

      # flow is a little wierdish
      ##Run something that hard codedly, in the test_server, increments the counter
      RestfullClient.get("locally", "a/a/a/b") { |m| nil }
      # Now checksomething that returns "200", put also the global server counter
      # And asset the number of retries. 
      res = RestfullClient.get("locally", "a") { "good" }

      expect(res["counter"]).to eq(4)
    end

  end

  describe "Default Value if no block is given" do

    it "should return nil when no value is given" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
        config.timeout = 1
      end
      res = RestfullClient.get("posts", "/a")
      expect(res).to eq(nil)
    end

    it "should allow skiping jynx completly" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
        config.use_jynx = false
        config.timeout = 1
      end
      res = RestfullClient.get("posts", "/a")
      expect(res).to eq(nil)
    end

  end

  describe "Uri Joining" do

    it "correct join two paths leading slash defined as [WithSlash : NoSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1/", "proposals/sent/count/123")
      expect(path).to eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

    it "correct join two paths leading slash defined as [WithSlash : WithSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1/", "/proposals/sent/count/123")
      expect(path).to eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

    it "correct join two paths leading slash defined as [NoSlash : WithSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1", "/proposals/sent/count/123")
      expect(path).to eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

    it "correct join two paths leading slash defined as [NoSlash : NowSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1", "proposals/sent/count/123")
      expect(path).to eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

  end

  describe "Fake response" do

    it "should return fake response" do
      RestfullClient.configure { |config| config.config_folder = "spec/config" }

      RestfullClient.fake('locally', 'fake/me') do
        Typhoeus::Response.new(
          code: 200,
          headers: {'Content-Type' => 'application/json'},
          body: { 'fake' => true }.to_json)
      end

      res = RestfullClient.get('locally', 'fake/me') { nil }
      expect(res).to eq({ 'fake' => true })
    end

  end

  describe "custom headers" do
    it "should allow sending custom headers to a single post request" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
      end

      custom_headers = {"moshe" => "OH MY GOD ~!!"}
      res = RestfullClient.post("locally", "/bounce_headers/moshe", {}, {"headers" => custom_headers})
      expect(res).to eq(custom_headers)

    end

    it "should allow sending custom headers to a single get request" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
      end

      custom_headers = {"moshe" => "OH MY GOD ~!!"}
      res = RestfullClient.get("locally", "/bounce_headers/moshe", nil, {"headers" => custom_headers})
      expect(res).to eq(custom_headers)

    end

    it "should allow sending custom headers to a single delete request" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
      end

      custom_headers = {"moshe" => "OH MY GOD ~!!"}
      res = RestfullClient.delete("locally", "/bounce_headers/moshe", {}, {"headers" => custom_headers})
      expect(res).to eq(custom_headers)

    end

    it "should allow sending custom headers to a single put request" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
      end

      custom_headers = {"moshe" => "OH MY GOD ~!!"}
      res = RestfullClient.put("locally", "/bounce_headers/moshe", {}, {"headers" => custom_headers})
      expect(res).to eq(custom_headers)

    end


  end

  describe :PlainURL do
    it "should be possible to get url from yml for custom calls" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
      end

      expect(RestfullClient.srv_url('posts')).to eq("http://1.2.3.4:8383/api/v0/")
    end
  end


end


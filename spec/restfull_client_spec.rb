require 'spec_helper'

require 'pry'
require 'pry-debugger'

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
  end

  describe "Configuration" do

    it "raise when file_name not sent in" do
      expect { RestfullClient.configure { } }.to raise_error
    end

    it "correctly read configuration files" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
      end

      RestfullClient.configuration.data.should_not be(nil)
    end

    it "allow accesing url configuration" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
      end

      RestfullClient.configuration.data["posts"]["url"].should eq("http://1.2.3.4:8383/api/v1/")
    end

    it "allow accesing url configuration by environment" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
      end

      RestfullClient.configuration.data["posts"]["url"].should eq("http://1.2.3.4:8383/api/v0/")
    end

    it "have a logger" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
      end

      RestfullClient.logger.should respond_to :info
    end

    it "correctly read the configuration from the registry" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
      end

      RestfullClient.callerr_config("posts")["url"].should eq("http://1.2.3.4:8383/api/v0/")
    end

    it "have a timeout defined for the service by default" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
      end

      RestfullClient.timeout.should eq(10)
    end

    it "have a timeout defined for the service by default" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
        config.timeout = 2
      end

      RestfullClient.timeout.should eq(2)
    end


    it "have a retries defined for the service by default" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
      end

      RestfullClient.retries.should eq(2)
    end

    it "have a retries defined for the service by default" do
      RestfullClient.configure do |config|
        config.config_folder = "spec/config"
        config.retries = 15
      end

      RestfullClient.retries.should eq(15)
    end

  end

  describe "toJson" do

    it "automatically run to_json on an object" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.timeout = 200
        config.config_folder = "spec/config"
      end

      some_object = {"moshe" => "test"}
      res = RestfullClient.post("locally", "/bounce", some_object) { |m| m }

      res.should eq(some_object)
    end

    it "doesn't re-run json on data that was already a json object" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.timeout = 200
        config.config_folder = "spec/config"
      end

      some_object = {"moshe" => "test"}.to_json
      res = RestfullClient.post("locally", "/bounce", some_object) { |m| m }

      res.should eq(JSON.parse(some_object))
    end

  end

  describe "Restfull Calls" do

    it "allow sending in a reporting method (such as graylog/ airbrake instrumentiation)" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.timeout = 2
        config.config_folder = "spec/config"
        config.report_method = proc do |*args|
          klass, message = *args
          set_global(klass)
        end
      end
      RestfullClient.configuration.report_on

      $some_global.should eq("RestfullClientConfiguration")
    end

    it "report on a server error (end-2-end ish test)" do
      RestfullClient.configure do |config|
        config.env_name = "production"
        config.config_folder = "spec/config"
        config.report_method = proc do |*args|
          klass, message = *args
          set_global(klass)
        end
      end
      RestfullClient.get("posts", "/a/a/a/a") { nil }

      $some_global.should eq("RestError")
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
      ##Run something thathard codedly, in the test_server, increamets the counter
      RestfullClient.get("locally", "a/a/a/b") { |m| nil }
      # Now checksomething that returns "200", put also the global server counter
      # And asset the number of retries. 
      res = RestfullClient.get("locally", "a") { "good" }

      res["counter"].should eq(4)
    end

  end


  describe "Uri Joining" do

    it "correct join two paths leading slash defined as [WithSlash : NoSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1/", "proposals/sent/count/123")
      path.should eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

    it "correct join two paths leading slash defined as [WithSlash : WithSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1/", "/proposals/sent/count/123")
      path.should eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

    it "correct join two paths leading slash defined as [NoSlash : WithSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1", "/proposals/sent/count/123")
      path.should eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

    it "correct join two paths leading slash defined as [NoSlash : NowSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1", "proposals/sent/count/123")
      path.should eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

  end

end


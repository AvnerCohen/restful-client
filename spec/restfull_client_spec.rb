require 'spec_helper'

require 'pry'
require 'pry-debugger'

def set_global(class_name)
  $some_global = class_name
end

describe :RestfullClient do
  before(:each) do
    $some_global = nil
    Typhoeus::Expectation.clear
  end

  it "should raise when file_name not sent in" do
    expect { RestfullClient.configure { } }.to raise_error
  end

  it "should correctly read configuration files" do
    RestfullClient.configure do |config|
      config.config_folder = "spec/config"
    end

    RestfullClient.configuration.data.should_not be(nil)
  end

  it "should allow accesing url configuration" do
    RestfullClient.configure do |config|
      config.config_folder = "spec/config"
    end

    RestfullClient.configuration.data["posts"]["url"].should eq("http://1.2.3.4:8383/api/v1/")
  end

  it "should allow accesing url configuration by environment" do
    RestfullClient.configure do |config|
      config.env_name = "production"
      config.config_folder = "spec/config"
    end

    RestfullClient.configuration.data["posts"]["url"].should eq("http://1.2.3.4:8383/api/v0/")
  end

  it "should have a logger" do
    RestfullClient.configure do |config|
      config.env_name = "production"
      config.config_folder = "spec/config"
    end

    RestfullClient.logger.should respond_to :info
  end

  it "should correctly read the configuration from the registry" do
    RestfullClient.configure do |config|
      config.config_folder = "spec/config"
    end

    RestfullClient.callerr_config("posts")["url"].should eq("http://1.2.3.4:8383/api/v0/")
  end

  it "should have a timeout defined for the service by default" do
    RestfullClient.configure do |config|
      config.config_folder = "spec/config"
    end

    RestfullClient.timeout.should eq(10)
  end

  it "should have a timeout defined for the service by default" do
    RestfullClient.configure do |config|
      config.config_folder = "spec/config"
      config.timeout = 15
    end

    RestfullClient.timeout.should eq(15)
  end

  it "should allow sending in a reporting method (such as graylog/ airbrake instrumentiation)" do
    RestfullClient.configure do |config|
      config.env_name = "production"
      config.config_folder = "spec/config"
      config.report_method = proc do |*args|
        klass, message = *args
        set_global(klass)
      end
    end
    RestfullClient.configuration.report_on

    $some_global.should eq("RestfullClientConfiguration")
  end

  it "should report on a server error (end-2-end ish test)" do
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

  describe "Uri Joining" do

    it "should correct join two paths leading slash defined as [WithSlash : NoSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1/", "proposals/sent/count/123")
      path.should eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

    it "should correct join two paths leading slash defined as [WithSlash : WithSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1/", "/proposals/sent/count/123")
      path.should eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

    it "should correct join two paths leading slash defined as [NoSlash : WithSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1", "/proposals/sent/count/123")
      path.should eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

    it "should correct join two paths leading slash defined as [NoSlash : NowSlash]" do
      path = RestfullClientUri.uri_join("http://load-balancer-int01:9999/api/v1", "proposals/sent/count/123")
      path.should eq("http://load-balancer-int01:9999/api/v1/proposals/sent/count/123")
    end

  end

end


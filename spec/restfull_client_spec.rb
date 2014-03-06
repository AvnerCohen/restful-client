require 'spec_helper'

require 'pry'
require 'pry-debugger'

def reporting_method(*args)
  @@some_global = *args
end

describe :RestfullClient do
  before(:all) do
    @@some_global = nil
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

  it "should allow sending in a reporting method (such as graylog/ airbrake instrumentiation" do
    RestfullClient.configure do |config|
      config.env_name = "production"
      config.config_folder = "spec/config"
      config.report_method = proc {|*args| @@some_global = *args }
    end
    RestfullClient.configuration.report_on

    @@some_global.should_not be(nil)
  end

end


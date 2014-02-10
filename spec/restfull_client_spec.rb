require 'spec_helper'

# Add when debugging
# require 'pry'
# require 'pry-debugger'


def reporting_method(*args)
  @@some_global = *args
end

describe :RestfullClient do
  before(:all) do
    @@some_global = nil
  end

  it "should raise when file_name not sent in" do
    expect { RestfullClient.new({}) }.to raise_error
  end

  it "should correctly read configuration files" do
    restfull_client = RestfullClient.new("./spec/config/services.yml")
    restfull_client.config.should_not be(nil)
  end

  it "should allow accesing url configuration" do
    restfull_client = RestfullClient.new("./spec/config/services.yml")
    restfull_client.config["posts"]["url"].should eq("http://1.2.3.4:8383/api/v1/")
  end

  it "should allow accesing url configuration by environment" do
    ENV["RACK_ENV"] = "production"
    restfull_client = RestfullClient.new("./spec/config/services.yml")
    restfull_client.config["posts"]["url"].should eq("http://1.2.3.4:8383/api/v0/")
  end

  it "should have a logger" do
    ENV["RACK_ENV"] = "production"
    restfull_client = RestfullClient.new("./spec/config/services.yml")
    restfull_client.logger.should respond_to :info
  end

  it "should allow sending in a reporting method (such as graylog/ airbrake instrumentiation" do
    ENV["RACK_ENV"] = "production"
    p = proc {|*args| @@some_global = *args }
    restfull_client = RestfullClient.new("./spec/config/services.yml", &p)
    @@some_global.should_not be(nil)
  end

end


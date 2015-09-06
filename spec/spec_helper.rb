require 'bundler'
Bundler.require

require 'rspec'

Dir["./spec/support/**/*.rb"].each {|f| load(f)}
load("#{File.dirname(__FILE__)}/../lib/restful_client.rb")

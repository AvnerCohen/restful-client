require 'rspec'

Dir["./spec/support/**/*.rb"].each {|f| load(f)}
Dir["#{File.dirname(__FILE__)}/../lib/**/*.rb"].each { |f| load(f)  }
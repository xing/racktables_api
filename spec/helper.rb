ENV['RACKTABLES_API_CONFIG'] ||= 'config.testing.yml'
ENV['RACK_ENV'] = 'testing'

require 'bundler/setup'
require 'racktables_api'
require 'rspec'
require 'simplecov'

SimpleCov.start

RSpec.configure do |config|

  config.around(:each){|ex|
    DB.transaction(:rollback=>:always,&ex)
  }

end

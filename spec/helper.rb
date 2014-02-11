ENV['RACK_ENV'] = 'testing'

require 'bundler/setup'
require 'racktables_api'
require 'rspec'
require 'simplecov'
begin
  require 'coveralls'
  Coveralls.wear!
rescue LoadError
  SimpleCov.start
end

RSpec.configure do |config|

  config.around(:each){|ex|
    DB.transaction(:rollback=>:always,&ex)
  }

end

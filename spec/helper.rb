ENV['RACK_ENV'] = 'testing'

require 'bundler/setup'
require 'simplecov'
require 'coveralls'
SimpleCov.start do
  formatter SimpleCov::Formatter::MultiFormatter[
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ]
  add_filter "/spec"
  maximum_coverage_drop 5
end
require 'racktables_api'
require 'rspec'

RSpec.configure do |config|

  config.around(:each){|ex|
    DB.transaction(:rollback=>:always,&ex)
  }

end

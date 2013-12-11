require 'bundler/setup'
require 'racktables_api'
require 'authenticator'

$stderr.puts <<BANNER
       _                    _
  _ __| |_       __ _ _ __ (_)
 | '__| __|____ / _` | '_ \| |
 | |  | ||_____| (_| | |_) | |
 |_|  \\__|      \\__,_| .__/|_|
                     |_|

WARNING: This is the development mode. Access is granted if user name and password are the same.
BANNER

class SetLogger

  def initialize(app)
    @app = app
  end

  def call(env)
    env['rack.logger'] = Logger.new(STDOUT)
    env['rack.logger'].sev_threshold = Logger::DEBUG
    return @app.call(env)
  end

end

use SetLogger

use Authenticator do |user, pass| user == pass end

run RacktablesApi.to_app

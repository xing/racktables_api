require 'rack/auth/basic'
require 'model/user'
require 'digest'

class RacktablesAuthenticator < Rack::Auth::Basic

  def initialize(app)
    super (app) do |user, pass|
      next false if user.empty? || pass.empty?

      Model::User::Account.where({:user_name => user, :user_password_hash => Digest::SHA1.hexdigest(pass)}).count == 1
    end
  end

  def call(env)
    if env['racktables.auth'] || ( env.key?('rack.session') && env['rack.session']['user'] )

      return @app.call(env)

    else

      auth = Rack::Auth::Basic::Request.new(env)

      if auth.provided? and auth.basic? and valid?(auth)
        if env.key?('rack.session')
          env['rack.session']['user'] = auth.username
          env['rack.session']['auth'] = 'authenticator'
        end
        env['racktables.auth'] = {'user' => auth.username, 'type' => 'authenticator'}
      end

      return @app.call(env)

    end
  end

end

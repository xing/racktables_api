require 'rack/auth/basic'
class Authenticator < Rack::Auth::Basic

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

require 'model/api_key'
require 'rack/auth/basic'
class ApiKeyAuthenticator < Rack::Auth::Basic

  API_KEY = 'HTTP_RACKTABLES_KEY'.freeze
  API_HASH = 'HTTP_RACKTABLES_HASH'.freeze

  def valid_api?(key, secret)
    k = Model::ApiKey[key]
    return false unless k
    return secret == k.secret
  end

  def authenticated_env?(env)
    ( env.key?('rack.session') && env['rack.session']['user'] ) || env['racktables.auth']
  end

  def authenticate_env!(env, key)
    if env.key? 'rack.session'
      env['rack.session']['user'] = key.owner
      env['rack.session']['key']  = key.pk
      env['rack.session']['auth'] = 'api'
    end
    env['racktables.auth'] = {'key' => key.pk, 'type' => 'api'}
  end

  def call(env)
    if authenticated_env? env
      return @app.call(env)
    elsif env.key?(API_KEY) and env[API_KEY].kind_of?(String)
      # this is a call by api key
      unless env[API_HASH].kind_of? String
        return [401,{'Content-Type'=>'text/plain'}, ["Missing the RACKTABLES_HASH http header"]]
      end
      key = Model::ApiKey[env[API_KEY]]
      unless key
        return [401,{'Content-Type'=>'text/plain'}, ["This key doesn't exist."]]
      end
      # okay, now check the secret
      d = Digest::SHA2.new(512)
      r = Rack::Request.new(env)
      body = r.body.read
      r.body.rewind
      str = [ key.secret , r.request_method , Digest::SHA2.new(512).update(body).hexdigest , r.fullpath ].join('|')
      hash = d.hexdigest( str )
      if hash != env[API_HASH]
        sleep( rand() )
        return [401,{'Content-Type'=>'text/plain'}, ["Api hash mismatch."]]
      end
      authenticate_env!(env, key)
      return @app.call(env)
    else
      auth = Rack::Auth::Basic::Request.new(env)
      return unauthorized unless auth.provided?
      return bad_request unless auth.basic?
      if( auth.credentials[0] =~ /\A\h{32}\z/ and auth.credentials[1] =~ /\A\h{32}\z/ )
        if valid_api?( *auth.credentials )
          key = Model::ApiKey[auth.credentials[0]]
          authenticate_env!(env, key)
          return @app.call(env)
        end
      end
      unauthorized
    end
  end

end

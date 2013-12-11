require 'rack/auth/basic'
require 'net-ldap'
class LDAPAuthenticator < Rack::Auth::Basic

  def initialize(app, config)
    super(app) do |user, password|
      next false if password.empty?
      net = Net::LDAP.new
      net.host = config[:host]
      net.auth "#{user}@#{config[:domain]}", password
      # Racktable itself queries the server after the
      # bind, but the result is only used to create
      # the display name.
      net.bind
    end
  end

  def call(env)
    if env['rack.session']['user']
      return @app.call(env)
    else
      auth = Rack::Auth::Basic::Request.new(env)
      if auth.provided? and auth.basic? and valid?(auth)
        env['rack.session']['user'] = auth.username
        env['rack.session']['auth'] = 'ldap'
        env['racktables.auth'] = {'user' => auth.username, 'type' => 'ldap'}
      end
      return @app.call(env)
    end
  end

end

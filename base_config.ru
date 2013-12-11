require File.expand_path('config', File.dirname(__FILE__))

require 'api_key_authenticator'
require 'logistician'
require 'api'
require 'meta'
require 'caller'
require 'client_counter'

class CatchExceptions

  NAME = "RACKTABLES API"

  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue Exception => e
    if env['rack.logger']
      env['rack.logger'].add(Logger::FATAL, e, NAME)
    else
      env["rack.errors"].puts(e.message)
      env["rack.errors"].puts(e.backtrace)
      env["rack.errors"].flush
    end
    return [500, {'Content-Type'=>'text/plain'}, ['Something went wrong.']]
  end
end

class RewriteLegacyURLNesting

  def initialize(app)
    @app = app
  end

  def call(env)
    qs = env['QUERY_STRING'].to_s
    if qs =~ /\[/
      query = qs.split('&')
      nqs = query.map{|part|
        k,v = part.split('=',2)
        k.gsub(/\[(.*?)\]/,'.\\1') + '=' + v.to_s
      }.join('&')
      env['QUERY_STRING'] = nqs
      env['rack.logger'].debug{ 'Rewritten the query string: '+ qs.inspect+ " => "+ nqs.inspect }
    end
    return @app.call(env)
  end

end


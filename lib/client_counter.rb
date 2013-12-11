require 'logistician'
class ClientCounter

  def initialize(app)
    @app = app
  end

  def call(env)
    Logistician::Utils.context(env).use(:statsd) do |statsd|
      statsd.increment('user_agent.'+parse_user_agent(env['HTTP_USER_AGENT']))
    end
    @app.call(env)
  end

private

  def parse_user_agent(ua)
    case(ua)
    when /\Axar\/v(\d+(?:\.\d+)*)\z/ then 'xar.'+$1
    else 'unknown'
    end
  end

end
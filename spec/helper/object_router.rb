require 'rack'
require 'api'
require 'statsd_fake'
require 'logistician/context'
module ObjectRouter

  def router
    @router ||= begin
      node = Addressive.node(:object) do

        app API[Model::RackObject], rewrite: ->(spec){ 
          spec.template = URITemplate.new('/object'+spec.template.to_s)
          spec
        }

        edge :api do 

          edge :object

          edge :rack do

            uri :single, '/rack/{id}'

          end

        end

      end
      r = Addressive::Router.new
      r.add( node )
      r
    end
  end

  def mock_stack(inner)
    Rack::Builder.new do

      use Logistician::Context::Build, :statsd do |ctx, mod, env|
        ctx[:statsd] = StatsdFake.new( lambda{|&_|} )
      end

      use Logistician::Context::Build, :addressive do |ctx, mod, env|
        ctx[:addressive] = env['addressive'] if env.key?('addressive')
      end

      run inner
    end
  end

  def mock_request(*args)
    Rack::MockRequest.new(mock_stack(router)).request(*args)
  end

  def mock_get(uri)
    mock_request('GET', uri )
  end

  def mock_patch(uri, data = {} )
    options = Hash[ data.select{|k,v| k.kind_of? Symbol }.map{|k,v| [k.to_s, v] } ]
    data = data.select{|k,v| !k.kind_of? Symbol }
    mock_request('PATCH', uri, options.merge( :input => MultiJson.dump(data) ) )
  end

  def mock_post(uri, data = {} )
    options = Hash[ data.select{|k,v| k.kind_of? Symbol }.map{|k,v| [k.to_s, v] } ]
    data = data.select{|k,v| !k.kind_of? Symbol }
    mock_request('POST', uri, options.merge( :input => MultiJson.dump(data) ) )
  end

end



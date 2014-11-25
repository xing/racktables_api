require 'logger'
require 'sequel'
require 'addressive'
require 'multi_json'

Dir[File.join(File.dirname(__FILE__),'chims/**/*.rb')].each do |file|
  require file
end

module RacktablesApi

  @logger = Logger.new(::STDERR)
  @logger.level = Logger::WARN

  if !ENV['RACKTABLES_DB']
    raise "No RACKTABLES_DB environment variable found. Please specify one."
  end

  @db = Sequel.connect( ENV['RACKTABLES_DB'] )
  @db.logger = @logger

  if ENV['RACKTABLES_META_DB']
    @meta_db = Sequel.connect( ENV['RACKTABLES_META_DB'] )
    @meta_db.logger = @logger
  else
    @meta_db = @db
  end

class << self
  attr :db, :meta_db, :logger

  def to_app
    builder.to_app
  end

  def builder
    Rack::Builder.new do

      use Rack::Lint

      use Caller do |env|
        time = Time.now

        result = super(env)

        if result[0] == 200 && env['addressive']
          Logistician::Utils.context(env).use(:statsd) do |statsd|
            statsd.timing( ['resources',env['addressive'].spec.app.name,'actions',env['addressive'].action, env['REQUEST_METHOD'] ,'total_time'].join('.'), (Time.now - time)*1000 )
          end
        end

        next result

      end

      use ApiKeyAuthenticator

      use Logistician::Context::Ensure, :statsd do |env|
        require 'statsd_fake'
        StatsdFake.new( lambda{|&block| env['rack.logger'].debug('statsd',&block) } )
      end

      use Logistician::Context::Build, :addressive do |ctx, mod, env|
        ctx[:addressive] = env['addressive'] if env.key?('addressive')
      end

      use ClientCounter
      use Caller do |env|
        env['QUERY_STRING'].gsub!('+','%20')
        super(env)
      end

      node_old = Addressive.node(:api) do

        edge :object do

          app API[Model::RackObject], rewrite: ->(spec){
            spec.template = URITemplate.new('/object'+spec.template.to_s)
            spec
          }

          edge :api

        end

        edge :rack do

          app API[Model::Rack], rewrite: ->(spec){
            spec.template = URITemplate.new('/rack'+spec.template.to_s)
            spec
          }

          edge :api

        end

        edge :port do

          app API[Model::Port], rewrite: ->(spec){
            spec.template = URITemplate.new('/port'+spec.template.to_s)
            spec
          }

          edge :api

        end

        edge :vlan do

          app API[Model::VLan], rewrite: ->(spec){
            spec.template = URITemplate.new('/vlan'+spec.template.to_s)
            spec
          }

          edge :api

        end

        edge :network do

          app API[Model::Network], rewrite: ->(spec){
            spec.template = URITemplate.new('/network'+spec.template.to_s)
            spec
          }

          edge :api

        end


      end

      node_1 = Addressive.node(:api) do

        edge :object do

          app API[Model::RackObject], rewrite: ->(spec){
            spec.template = URITemplate.new('/v19.1/objects'+spec.template.to_s)
            spec
          }

          edge :api

        end

        edge :rack do

          app API[Model::Rack], rewrite: ->(spec){
            spec.template = URITemplate.new('/v19.1/racks'+spec.template.to_s)
            spec
          }

          edge :api

        end

        edge :port do

          app API[Model::Port], rewrite: ->(spec){
            spec.template = URITemplate.new('/v19.1/ports'+spec.template.to_s)
            spec
          }

          edge :api

        end


        edge :vlan do

          app API[Model::VLan], rewrite: ->(spec){
            spec.template = URITemplate.new('/v19.1/vlans'+spec.template.to_s)
            spec
          }

          edge :api

        end

      end

      router = Addressive::Router.new
      router.add( *node_old.edges.values )
      router.add( *node_1.edges.values )

      map '/_meta' do
        run Meta
      end

      run router

    end

  end
end
end

DB = RacktablesApi.db
META_DB = RacktablesApi.meta_db

require 'api_key_authenticator'
require 'logistician'
require 'api'
require 'meta'
require 'caller'
require 'client_counter'

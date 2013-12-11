require 'logistician'
require 'logistician/resource'
require 'logistician/repository'
class Logistician
  module Repository::Shared

    attr_accessor :repository

    attr_accessor :uris

    def not_found(ctx)
      return [ 404, {'Content-Type'=>'application/json'}, ["null"]]
    end

    def bad_request(ctx, doc)
      return [ 400, {'Content-Type'=>'application/json'}, [ MultiJson.dump( doc ) ] ]
    end

    def success(ctx, doc = {})
      return [ 200, {'Content-Type'=>'application/json'}, [ MultiJson.dump( doc ) ] ]
    end

    def created(ctx, stuff)
      header = {'Content-Type'=>'application/json'}
      if repository.domain.exporter.referential? stuff
        header['Location'] = repository.domain.exporter.identify(ctx,stuff)
      end
      return [ 201, header, MultiJson.dump( repository.export(ctx,stuff) )]
    end

    def export(ctx, stuff, headers = {})
      r = repository
      if stuff.nil?
        return not_found(ctx)
      else
        return [ 200, {'Content-Type'=>'application/json'}.merge(headers), [MultiJson.dump( r.export(ctx,stuff) )] ]
      end
    end

    def name
      repository.name
    end

    def generate_uri_specs(builder)
      (self.class.uris || []).each do |args|
        options = args.last.kind_of?(Hash) ? args.pop.dup : {}
        options[:app] ||= self
        builder.uri( *args , options)
      end
    end

    def to_s
      return ['<',self.class.name,' for ',repository,'>'].join
    end

    def call(env)
      Logistician::Utils.context(env).use(:statsd) do |statsd|
        statsd_prefix = ['resources',name,'actions',env['addressive'].action,env['REQUEST_METHOD']].join('.')
        time = Time.now
        begin
          result = super
          if result[0] == 200
            statsd.timing("#{statsd_prefix}.inner_time", (Time.now - time)*1000 )
          end
          return result
        ensure
          statsd.increment("#{statsd_prefix}.count")
        end
      end
    end

    class << self

      def included(base)
        base.extend(ClassMethods)
      end

    end

    module ClassMethods

      attr_accessor :uris

      def uri(*args)
        @uris ||= []
        @uris << args
      end

    end

  end
end

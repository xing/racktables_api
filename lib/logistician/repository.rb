require 'logistician'
require 'logistician/resource'
require 'logistician/exporter'
require 'logistician/tree_destructor'
class Logistician

  class Repository

    class Query
      include TreeDestructor
    end

    class DSL

      extend Forwardable

      def_delegators :repository, :name, :endpoints

      attr_reader :repository

      def initialize(repo)
        @repository = repo
      end

      def publish(key,options = {})
        key = key.to_sym
        as = (options[:as] || key).to_s
        unless options[:export] == false
          if options[:export].nil?
            export.publish(key, :as => as )
          elsif options[:export].respond_to? :call
            export.publish(key, :as => as, &options[:export] )
          else
            export.publish(key, {:as => as}.merge( options[:export] ) )
          end
        end
      end

      def export(options = {}, &block)
        repository.exporter(options, &block)
      end

    end

    attr_reader :domain, :model, :endpoints
    attr_accessor :name

    def self.fits?(klass)
      false
    end

    def initialize(domain, model, options = {} )
      @domain = domain
      @model = model
      @query_class = Class.new(Query)
      @multi_resource = MultiResource.new
      @multi_resource.repository = self
      @single_resource = SingleResource.new
      @single_resource.repository = self
      @endpoints = {:single => @single_resource, :multi => @multi_resource}
      self.name = options[:as]
    end

    def generate_uri_specs(builder)
      @endpoints.each_value do |sub|
        sub.generate_uri_specs(builder)
      end
    end

    def export(*args)
      @domain.export(*args)
    end

    def exporter(*args,&block)
      domain.exporter.export( model, *args, &block )
    end

    def to_s
      ['<',self.class.name, ' model: ', @model,'>'].join
    end

  end

end

require 'logistician/repository/domain'
require 'logistician/repository/single_resource'
require 'logistician/repository/multi_resource'

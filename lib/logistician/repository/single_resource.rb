require 'logistician'
require 'logistician/resource'
require 'logistician/repository'
require 'logistician/repository/shared'
class Logistician

  class Repository::SingleResource < Resource

    include Repository::Shared

    attr_accessor :primary_key

    def initialize(*args)
      @primary_key = ['id']
      super
    end

    def generate_uri_specs(builder)
      super(builder)
      builder.uri( :single, primary_key.map{|pk| "/{#{pk}}" }.join, app: self )
    end

    def get( ctx, env )
      return export( ctx, repository.query(ctx, env['addressive'].variables ).all[0] )
    end

    def patch( ctx, env )
      query = env['addressive'].variables
      objects = repository.query(ctx, query)
      input = MultiJson.load(env['rack.input'])
      ups = 0
      DB.transaction do
        updates = repository.single_update(ctx, input, objects )
        ups = updates.do!
      end
      return success( ctx, 'updated' => ups )
    end

  end

end

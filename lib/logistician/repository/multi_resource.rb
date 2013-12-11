require 'logistician'
require 'logistician/resource'
require 'logistician/repository'
require 'logistician/repository/shared'
class Logistician

  class Repository::MultiResource < Resource

    class Paginator

      def initialize(ctx, env)
        @context = ctx
        @env = env
        @next = true
      end

      def read(query)
        if query.key?('_offset') || query.key?('_limit')
          query = query.dup
          @offset = [0, query.delete('_offset').to_i].max
          @limit = [100,[1, (query.delete('_limit') || 30).to_i].max].min
        end
        return @query = query
      end

      def apply(stuff)
        @size = stuff.count
        if @offset
          stuff = stuff.order(*Array(stuff.model.primary_key)) unless stuff.opts[:order]
          result = stuff.limit(@limit, @offset).all
          if @size < @limit + @offset
            @next = false
          end
          return result
        else
          stuff.all
        end
      end

      def header
        if @offset
          links = []
          links << "<#{prev_uri}>; rel=\"Previous\"" if prev?
          links << "<#{next_uri}>; rel=\"Next\"" if next?
          return {'Link' => links.join("\n"), 'X-Collection-Size' => @size.to_s}
        else
          return {'X-Collection-Size' => @size.to_s}
        end
      end

      def prev?
        @offset != 0
      end

      def next?
        @next
      end

      def next_uri
        @env['addressive'].uri(
          'query'=> @query.merge({
            '_offset' => @offset + @limit,
            '_limit'=> @limit
          })
        )
      end

      def prev_uri
        @env['addressive'].uri(
          'query'=> @query.merge({
            '_offset' => [ 0, @offset - @limit ].max,
            '_limit'=>[@offset,@limit].min
          })
        )
      end

    end

    include Repository::Shared

    uri '{?query*}'

    def get( ctx, env )
      pager = Paginator.new(ctx, env)
      query = pager.read(env['addressive'].variables['query'] || {})
      query = Utils.delinearize_query(query)
      return export( ctx, pager.apply(repository.query(ctx, query)), pager.header )
    end

    def patch( ctx, env )
      query = Utils.delinearize_query(env['addressive'].variables['query'])
      objects = repository.query(ctx, query)
      input = MultiJson.load(env['rack.input'])
      ups = 0
      updates = repository.multi_update(ctx, input, objects )
      ups = updates.do!
      return success( ctx, 'updated' => ups )
    end

    def post( ctx, env )
      input = MultiJson.load(env['rack.input'])
      nu = nil
      create = repository.create(ctx, input )
      nu = create.do!
      return created( ctx, nu )
    end

  end

end

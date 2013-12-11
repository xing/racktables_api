require 'logistician/sequel'
class Logistician

  module Sequel

    class Repository < Logistician::Repository

      class DSL < Logistician::Repository::DSL

        ENUM_VALUE = /\A'((?:[^']|'')*)'(?:,|\z)/
        def parse_enum(enum)
          if /\Aenum\((.*)\)\z/ =~ enum
            values = []
            str = $1
            while str.length > 0
              if ENUM_VALUE =~ str
                str = $'
                values << $1.gsub('\'\'','\'')
              else
                return nil
              end
            end
            return values
          else
            return nil
          end
        end 

        def publish(key, options={})
          options = options.dup.freeze
          key = key.to_sym
          as = (options[:as] || key).to_s
          updateable = options.fetch(:updateable){ true }
          createable = (options[:createable] != false)
          queryable = options.fetch(:queryable){ true }
          repo = repository
          if ref = repo.model.association_reflection(key)
            case(ref[:type])
            when :many_to_many then
              if queryable
                query do
                  on( as => macro(:to_many){|subquery|
                    dom = repo.domain[as, ref.associated_class]
                    if dom
                      subresult = dom.query(context, subquery)
                      subresult = options[:post_filter].call(subresult) if options[:post_filter].respond_to? :call
                      many_to_many_to_sql(ref, subresult)
                    end
                  })
                end
              end
              update(updateable) do
                on( as => {'_push' => Object}) do |subquery|
                  dom = repo.domain[as, ref.associated_class]
                  if dom
                    subresult = dom.query(context, subquery)
                    subresult = options[:post_filter].call(subresult) if options[:post_filter].respond_to? :call
                    update( ->(object){ subresult.each do |sub| object.send(ref.add_method, sub) end } )
                  end
                end
                on( as => {'_drop' => Object}) do |subquery|
                  dom = repo.domain[as, ref.associated_class]
                  if dom
                    subresult = dom.query(context, subquery)
                    subresult = options[:post_filter].call(subresult) if options[:post_filter].respond_to? :call
                    update( ->(object){ subresult.each do |sub| object.send(ref.remove_method, sub) end } )
                  end
                end
                on( as => Object) do |subquery|
                  dom = repo.domain[as, ref.associated_class]
                  if dom
                    subresult = dom.query(context, subquery)
                    subresult = options[:post_filter].call(subresult) if options[:post_filter].respond_to? :call
                    update( ->(object){ object.send(ref.setter_method, subresult) } )
                  end
                end
              end
            when :one_to_many then
              if queryable
                query do
                  on( as => macro(:to_many){|subquery|
                    dom = repo.domain[as, ref.associated_class]
                    if dom
                      subresult = dom.query(context, subquery)
                      subresult = options[:post_filter].call(subresult) if options[:post_filter].respond_to? :call
                      one_to_many_to_sql(ref, subresult)
                    else
                      raise "Unknown domain for #{as.inspect} or #{ref.associated_class.inspect}"
                    end
                  })
                end
              end
              update(updateable) do
                on( as => {'_drop' => Object}) do |subquery|
                  dom = repo.domain[as, ref.associated_class]
                  if dom
                    subresult = dom.query(context, subquery)
                    subresult = options[:post_filter].call(subresult) if options[:post_filter].respond_to? :call
                    write( ->(object){ subresult.filter( ref[:key] => object.send(ref.primary_key) ).delete } )
                  end
                end
                on( as => { '_push' => [Object] }) do |creates|
                  dom = repo.domain[as, ref.associated_class]
                  if dom
                    write( ->(object){ creates.each do |create| object.send(ref.add_method, dom.create(context, create, object.send(ref.dataset_method)).create! ) end } )
                  end
                end
                on( as => {'_push' => Object}) do |create|
                  dom = repo.domain[as, ref.associated_class]
                  if dom
                    write( ->(object){ object.send(ref.add_method, dom.create(context, create, object.send(ref.dataset_method)).create! ) } )
                  end
                end
              end
              write(updateable, createable) do
                on( as => [Object]) do |creates|
                  dom = repo.domain[as, ref.associated_class]
                  if dom
                    write( ->(object){
                          object.send(ref.setter_method, dom.create_all(context, creates, ref.associated_dataset) ) } )
                  end
                end
              end
            when :many_to_one then
              if queryable
                query do
                  on( as => macro(:to_one){|subquery|
                    dom = repo.domain[as, ref.associated_class]
                    if dom
                      subresult = dom.query(context, subquery)
                      subresult = options[:post_filter].call(subresult) if options[:post_filter].respond_to? :call
                      many_to_one_to_sql(ref, subresult)
                    end
                  })
                end
              end
              write( updateable, createable ) do
                on( as => Object ) do |subquery|
                  dom = repo.domain[as, ref.associated_class]
                  if dom
                    subresult = dom.query(context, subquery)
                    subresult = options[:post_filter].call(subresult) if options[:post_filter].respond_to? :call
                    fst = subresult.first
                    next false if fst.nil?
                    write( ->(object){ object.send(ref.setter_method, fst) } )
                  end
                end
              end
            end
            return super
          elsif repository.schema.key? key
            column =  repository.schema[key]
            case(column[:type])
            when :integer, :float, :string
              if queryable
                query do
                  on( as => macro(column[:type]){|op,value| ::Sequel::SQL::BooleanExpression.new(op, key, value)} )
                end
              end
              update(updateable) do
                on( as => macro(column[:type]){|value| {key => value} } )
              end
              if createable
                create do
                  on( as => macro(column[:type]){|value| {key => value} } )
                end
              end
            when :enum
              values = parse_enum( column[:db_type] )
              if queryable
                query do
                  on( as => macro(:enum, values){|op,value| ::Sequel::SQL::BooleanExpression.new(op, key, value)} )
                end
              end
              update(updateable) do
                on( as => macro(:enum, values){|value| {key => value} } )
              end
              if createable
                create do
                  on( as => macro(:enum, values){|value| {key => value} } )
                end
              end
            end
            return super
          else
            # no query support by default
            return super
          end
        end

        def query(&block)
          repository.query_class.instance_exec(&block) if block
          return repository.query_class
        end

        def update(which = true, &block)
          raise ArgumentError.new('A block is required for .update') unless block
          return unless which
          case( which )
          when true, :both
            repository.single_update_class.instance_exec(&block) if block
            repository.multi_update_class.instance_exec(&block) if block
          when :single
            repository.single_update_class.instance_exec(&block) if block
          when :multi
            repository.multi_update_class.instance_exec(&block) if block
          else
            raise ArgumentError, "Unknown option for .update: #{which.inspect} expected true, false, :both, :single or :multi"
          end
          return nil
        end

        def create(&block)
          repository.create_class.instance_exec(&block) if block
          return repository.create_class
        end

        def write(which = true, createable = true, &block)
          raise ArgumentError.new('A block is required for :write') unless block
          update(which, &block)
          create(&block) if createable
          return nil
        end

      end

      def self.fits?(klass)
        return klass < ::Sequel::Model
      end

      attr_reader :query_class,:single_update_class, :multi_update_class, :create_class, :exporter_class

      def initialize(*args, &block)
        super(*args)
        @query_class = Class.new(Query)
        @single_update_class = Class.new(Update)
        @multi_update_class = Class.new(Update)
        @create_class = Class.new(Create)
        DSL.new(self).instance_eval(&block) if block
      end

      def schema
        @schema ||= Hash[ model.db_schema ]
      end

      def query(ctx, query)
        q = @query_class.new(ctx, self)
        rest = q.parse( prequery(ctx, query) )
        if rest
          raise HTTPError.new("Bad query: #{rest.inspect}",400)
        end
        return postquery(ctx, query, q.dataset)
      end

      def prequery(ctx, query)
        query
      end

      def postquery(ctx, query, dataset)
        dataset
      end

      def multi_update(ctx, updates, dataset)
        q = multi_update_class.new(ctx, self, dataset)
        rest = q.parse( updates )
        if rest
          raise HTTPError.new("Bad query: #{rest.inspect}",400)
        end
        return q
      end

      def single_update(ctx, updates, dataset)
        q = single_update_class.new(ctx, self, dataset)
        rest = q.parse( updates )
        if rest
          raise HTTPError.new("Bad query: #{rest.inspect}",400)
        end
        return q
      end

      def create(ctx, creates, dataset = self.model.dataset)
        q = create_class.new(ctx, self, dataset)
        rest = q.parse( creates )
        if rest
          raise HTTPError.new("Bad query: #{rest.inspect}",400)
        end
        return q
      end

      def create_all( ctx, creates, dataset = self.model.dataset )
        creates.map do |cr|
          create( ctx, cr, dataset ).create!
        end
      end

    end
  end
end

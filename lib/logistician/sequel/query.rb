require 'logistician/sequel'
class Logistician

  module Sequel

    class Query

      NUMERIC_QUERIES = {
        '_le' => :<=,
        '_lt' => :<,
        '_gt' => :>,
        '_ge' => :>=,
        '_eq' => :'='
      }

      SET_QUERIES = {
        '_in' => :IN,
      }

      STRING_QUERIES = {
        '_match' => :~,
        '_eq' => :'='
      }

      class FilterMacro < TreeDestructor::Macro

        def initialize(&block)
          @block = block
        end

      end

      class FixedHexBinMacro < FilterMacro

        REGEXP = /\A\h+\z/i;

        def initialize(storage, length=8)
          super()
          @storage = storage
          @length = length
        end

        def call(node)
          block = @block
          this = self
          node.append(REGEXP, lambda do |s|
            filter( instance_exec(:'=', this.convert(s.to_s) , &block) )
          end )
          node.append({'_not' => REGEXP}, lambda do |s|
            filter( ~instance_exec(:'=', this.convert(s.to_s) , &block) )
          end )
          node.append([REGEXP], lambda do |s|
            filter( instance_exec(:IN, s.map{|t| this.convert(t.to_s) }, &block) )
          end )
          node.append({'_not' => [REGEXP]}, lambda do |s|
            filter( ~instance_exec(:IN, s.map{|t| this.convert(t.to_s) }, &block) )
          end )
          SET_QUERIES.each do |name, op|
            node.append({name => [REGEXP]}, lambda do |s|
              filter( instance_exec(op, s.map{|t| this.convert(t.to_s) }, &block)  )
            end )
            node.append({'_not' => {name => [REGEXP]} }, lambda do |s|
              filter( ~instance_exec(op, s.map{|t| this.convert(t.to_s) }, &block) )
            end)
          end
        end

        def convert(s)
          case(@storage)
          when :string then s.rjust(@length*2,'0')
          when :numeric then s.to_i(16)
          when :binary then ::Sequel::SQL::Blob.new( s.each_char.map{|c| c.to_i(16) }.pack('c*').rjust(@length, '\0') )
          end
        end

      end

      class StringMacro < FilterMacro
        def call(node)
          block = @block
          node.append(String, lambda do |s|
            filter( instance_exec(:'=', s, &block) )
          end )
          node.append({'_not' => String}, lambda do |s|
            filter( ~instance_exec(:'=', s, &block) )
          end )
          node.append([String], lambda do |s|
            filter( instance_exec(:IN, s, &block) )
          end )
          node.append({'_not' => [String]}, lambda do |s|
            filter( ~instance_exec(:IN, s, &block) )
          end )
          STRING_QUERIES.each do |name, op|
            node.append({name => String}, lambda do |s|
              filter( instance_exec(op, s, &block) )
            end )
            node.append({'_not' => {name => String} }, lambda do |s|
              filter( ~instance_exec(op, s, &block)  )
            end )
          end
          SET_QUERIES.each do |name, op|
            node.append({name => [String]}, lambda do |s|
              filter( instance_exec(op, s, &block)  )
            end )
            node.append({'_not' => {name => [String]} }, lambda do |s|
              filter( ~instance_exec(op, s, &block) )
            end)
          end
        end
      end

      FALSE_VALUES = ['0',/\Af(?:a(?:l(?:se?)?)?)?\z/i]

      class BooleanMacro < FilterMacro

        def call(node)
          block = @block
          FALSE_VALUES.each do |v|
            node.append(v, {'_eq'=>v},lambda do
              filter( instance_exec(:'=',false, &block) )
            end)
            node.append({'_not'=>v}, {'_not'=>{'_eq'=>v}},lambda do |_|
              filter( ~instance_exec(:'=',false, &block) )
            end)
          end
          node.append(String, {'_eq'=>String}, lambda do |_|
            filter( instance_exec(:'=', true, &block) )
          end )
          node.append({'_not' => String},{'_not'=>{'_eq'=>String}}, lambda do |_|
            filter( ~instance_exec(:'=', true, &block) )
          end )
        end
      end


      class NumericMacro < FilterMacro

        REGEX =/\A[1-9]\d*(?:\.\d+)?\z/.freeze
        CONVERTER = :to_f

        def call(node)
          block = @block
          conv = self.class::CONVERTER
          node.append(self.class::REGEX, lambda do |m|
            filter( instance_exec(:'=', m[0].send(conv), &block) )
          end )
          node.append([self.class::REGEX], lambda do |ms|
            filter( instance_exec(:IN, ms.map{|m| m[0].send(conv)}, &block)  )
          end )
          node.append({'_not' => [self.class::REGEX] }, lambda do |ms|
            filter( ~instance_exec(:IN, ms.map{|m| m[0].send(conv)}, &block) )
          end)
          NUMERIC_QUERIES.each do |name, op|
            node.append({name => self.class::REGEX}, lambda do |m|
              filter( instance_exec(op, m[0].send(conv), &block) )
            end )
            node.append({'_not' => {name =>self.class::REGEX} }, lambda do |m|
              filter( ~instance_exec(op, m[0].send(conv), &block)  )
            end )
          end
          SET_QUERIES.each do |name, op|
            node.append({name => [self.class::REGEX]}, lambda do |ms|
              filter( instance_exec(op, ms.map{|m| m[0].send(conv)}, &block)  )
            end )
            node.append({'_not' => {name => [self.class::REGEX]} }, lambda do |ms|
              filter( ~instance_exec(op, ms.map{|m| m[0].send(conv)}, &block) )
            end)
          end
        end
      end

      class ToManyMacro < FilterMacro

        def call(node)
          block = @block
          node.append( {'_contains' => [ Object ] }, [Object] , lambda do | subquery |
            subquery.each do |subsubquery|
              filter( instance_exec(subsubquery, &block) )
            end
          end )
          node.append( {'_not' => {'_contains' => [ Object ]} } , {'_not' => [Object]}, lambda do | subquery |
            subquery.each do |subsubquery|
              filter( ~instance_exec(subsubquery, &block) )
            end
          end )
          node.append( {'_contains' => Object } , Object ,  lambda do | subquery |
            filter( instance_exec(subquery, &block) )
          end )
          node.append( {'_not' => {'_contains' => Object } }, {'_not' => Object} , lambda do | subquery |
            filter( ~instance_exec(subquery, &block) )
          end )
        end

      end

      class ToOneMacro < FilterMacro

        def call(node)
          block = @block
          node.append( {'_not' => Object }, lambda do | subquery |
            filter( ~instance_exec(subquery, &block) )
          end )
          node.append( Object , lambda do | subquery |
            filter( instance_exec(subquery, &block) ) 
          end )
        end

      end

      class EnumMacro < FilterMacro

        def initialize(*values)
          @values = values.flatten
          super()
        end

        def call(node)
          block = @block
          @values.each do |value|
            node.append( {'_eq'=>value}, value, lambda do |_|
              filter( instance_exec(:'=', value, &block) )
            end )
            node.append( {'_not'=>{'_eq'=>value}}, {'_not' => value }, lambda do |_|
              filter( ~instance_exec(:'=', value &block) )
            end )
          end
          node.append( { '_in' => @values }, @values, lambda do |values|
            filter( instance_exec(:'IN', values, &block) )
          end )
          node.append( {'_not' => {'_in' => @values } }, {'_not'=>@values}, lambda do |values|
            filter( ~instance_exec(:'IN', values, &block) )
          end )
        end
      end


      class IntegerMacro < NumericMacro

        REGEX = /\A[1-9]\d*\z/.freeze
        CONVERTER = :to_i

      end

      class NullMacro < FilterMacro

        def call(node)
          block = @block
          node.append( {'_is' => {'_not' => '_null'} } , lambda do |*_|
            filter( ~instance_exec(:IS, nil, &block) )
          end)
          node.append( {'_is' => '_null'} , lambda do |*_|
            filter( instance_exec(:IS, nil, &block) )
          end)
        end

      end

      class AppendableFilter
        attr_reader :filter
        def initialize
          @filter = false
          @ored = false
        end
        def <<(other)
          if !@filter
            @filter = ::Sequel::SQL::BooleanExpression.new(:OR, ::Sequel::SQL::BooleanExpression.new(:AND,other))
          elsif @ored
            @filter.args << ::Sequel::SQL::BooleanExpression.new(:AND,other)
            @ored = false
          else
            @filter.args.last.args << other
          end
          return self
        end
        def or!
          @ored = true
          return self
        end
      end

      include TreeDestructor

      macros[:string] = StringMacro
      macros[:integer] = IntegerMacro
      macros[:fixed_hex_bin] = FixedHexBinMacro
      macros[:float] = NumericMacro
      macros[:boolean] = BooleanMacro
      macros[:to_many] = ToManyMacro
      macros[:to_one] = ToOneMacro
      macros[:enum] = EnumMacro
      macros[:null] = NullMacro

      attr_reader :repository, :context

      def domain
        repository.domain
      end

      def initialize(ctx, repository)
        super()
        @context = ctx
        @repository = repository
        @dataset = repository.model.dataset
        @filter = AppendableFilter.new
        @limit = nil
      end

      def model
        @repository.model
      end

      def dataset
        result = repository.model.dataset
        if @filter.filter
          result = result.filter(@filter.filter)
        end
        if @limit
          result = result.limit(@limit)
        end
        return result
      end

      def filter(*args)
        @filter << repository.model.dataset.send(:filter_expr,*args) if args.size > 0
        return @filter
      end

      def limit(num)
        @limit = num
      end

      def or!
        @filter.or!
      end

      def many_to_many_to_sql(ref, subresult)
        rpk = ref.right_primary_key
        joinresult = case( subresult )
          when ::Sequel::Dataset then
            subresult.inner_join(
              ref[:join_table],
              ::Sequel::SQL::BooleanExpression.new(:'=', ref[:right_key].qualify(ref[:join_table]), rpk.qualify(subresult.first_source_alias))
            )
          when Enumerable then
              dataset.db[ref[:join_table]].filter(
                ::Sequel::SQL::BooleanExpression.new(:IN, ref[:right_key], subresult.map(&rpk))
              )
          else
            raise "Expected an Enumberable or Sequel::Dataset, but got: #{subresult.inspect}."
          end
        if cond = ref[:conditions]
          if cond.is_a?(Array) && !::Sequel.condition_specifier?(cond)
            joinresult = joinresult.filter(*cond)
          else
            joinresult = joinresult.filter(cond)
          end
        end
        return ::Sequel::SQL::BooleanExpression.new(:IN,
            ref[:left_primary_key],
            joinresult.select(*Array(ref[:left_key]))
          )
      end

      def many_to_one_to_sql(ref, subresult)
        case( subresult )
        when ::Sequel::Dataset then
          ::Sequel::SQL::BooleanExpression.new(:IN, ref[:key_column] || ref[:key] , subresult.select(ref.qualified_primary_key))
        when Enumerable then
          ::Sequel::SQL::BooleanExpression.new(:IN, ref[:key_column] || ref[:key] , subresult.map{|object| object.send(ref[:key_method]) })
        else
          raise "Expected an Enumberable or Sequel::Dataset, but got: #{subresult.inspect}."
        end
      end

      def one_to_many_to_sql(ref, subresult)
        case( subresult )
        when ::Sequel::Dataset then
          ::Sequel::SQL::BooleanExpression.new(:IN, ref.qualified_primary_key, subresult.select(ref[:key]))
        when Enumerable then
          ::Sequel::SQL::BooleanExpression.new(:IN, ref.qualified_primary_key, subresult.map{|object| object.send(ref[:key_method]) })
        else
          raise "Expected an Enumberable or Sequel::Dataset, but got: #{subresult.inspect}."
        end
      end

    end
  end
end

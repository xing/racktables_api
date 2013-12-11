require 'logistician/sequel'
class Logistician

  module Sequel

    class Write

      class WriteMacro < TreeDestructor::Macro

        def initialize(&block)
          @block = block
        end

      end

      class StringMacro < WriteMacro

        def call(node)
          block = @block
          this = self
          node.append(String, ->(value){
            write( instance_exec(value, &block)); nil
          })
        end

      end

      class NumericMacro < WriteMacro

        REGEX =/\A[1-9]\d*(?:\.\d+)?\z/.freeze
        CONVERTER = :to_f
        NUMERIC_CLASS = Numeric

        def call(node)
          block = @block
          this = self
          node.append(self.class::REGEX, ->(value){
            write( instance_exec(this.convert(value[0]), &block)); nil
          })
          node.append(self.class::NUMERIC_CLASS, ->(value){
            write( instance_exec(this.convert(value), &block)); nil
          })
        end

        def convert(x)
          return x.send(self.class::CONVERTER)
        end

      end

      class IntegerMacro < NumericMacro

        REGEX =/\A[1-9]\d*\z/.freeze
        CONVERTER = :to_i
        NUMERIC_CLASS = Fixnum

      end

      class EnumMacro < WriteMacro

        def initialize(*values)
          @values = values.flatten
          super()
        end

        def call(node)
          block = @block
          @values.each do |v|
            node.append(v, ->(value){
              write( instance_exec(value, &block)); nil
            })
          end
        end
      end

      class FixedHexBinMacro < WriteMacro

        REGEXP = /\A\h+\z/i;

        def initialize(storage, length=8)
          @storage = storage
          @length = length
          super()
        end

        def call(node)
          block = @block
          this = self
          node.append(REGEXP, lambda do |s|
            write( instance_exec( this.convert(s.to_s) , &block) )
          end )
        end

        def convert(s)
          case(@storage)
          when :string then s.rjust(@length*2,'0')
          when :numeric then s.to_i(16)
          when :binary then ::Sequel::SQL::Blob.new( s.each_char.map{|c| c.to_i(16) }.pack('c*').rjust(@length, '\0') )
          end
        end

      end

      class ToOneMacro < WriteMacro

        def call(node)
          block = @block
          this = self
          node.append( Object , ->(subquery){
            write( instance_exec(subquery, &block) ); nil
          })
        end

      end

      include TreeDestructor

      macros[:string] = StringMacro
      macros[:float] = NumericMacro
      macros[:integer] = IntegerMacro
      macros[:enum] = EnumMacro
      macros[:fixed_hex_bin] = FixedHexBinMacro
      macros[:to_one] = ToOneMacro

      attr_reader :updates, :repository, :context, :dataset

      def initialize(ctx, repository, dataset)
        super()
        @context = ctx
        @repository = repository
        @dataset = dataset
        @updates = []
      end

      def empty?
        updates.none?
      end

      def write(x)
        @updates << x
        return self
      end

    protected

      def apply_to!(object)
        updates.each do |up|
          if up.respond_to? :call
            up.call(object)
          elsif up.kind_of? Hash
            up.each do |k,v|
              object.send("#{k}=".to_s, v)
            end
          else
            raise "Don't know how to apply update: #{up.inspect}"
          end
        end
      end

    end

  end

end

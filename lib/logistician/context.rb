require 'logistician'
class Logistician

  class Context

    class Ensure

      def initialize(app, name, *rest, &block)
        @app = app
        @name = name
        @rest = rest
        @block = block
      end

      def call(env)
        ctx = Logistician::Utils.context(env)
        ctx[@name] ||= @block.call(env, *@rest)
        return @app.call(env)
      end

    end

    class Build

      def initialize(app, name, *rest, &block)
        @app = app
        @name = name
        @rest = rest
        @block = block
      end

      def call(env)
        ctx = Logistician::Utils.context(env)
        ctx.build(@name) do |*args|
          @block.call(*args, env, *@rest)
        end
        return @app.call(env)
      end

    end

    extend Forwardable

    def_delegators :@data, :[]=, :fetch, :each, :to_h, :to_hash, *Enumerable.instance_methods

    def initialize
      @data = {}
      @builder = {}
    end

    def use(*modules)
      if useable? *modules
        if block_given?
          return yield( *modules.map{|r| @data[r] } )
        else
          return *modules.map{|r| @data[r] }
        end
      else
        return nil
      end
    end

    def [](mod)
      if useable?(mod)
        return @data[mod]
      else
        return nil
      end
    end

    def build(mod, &block)
      return false if @data.key? mod
      @builder[mod] = block
      return true
    end

    def useable?(*modules)
      modules.all?{|mod| try_build(mod) }
    end

  private
    def try_build(mod)
      return true if @data.key? mod
      builder = @builder[mod]
      return false if builder.nil?
      builder.call(self, mod)
      if @data.key?(mod)
        @builder.delete(mod)
        return true
      else
        return false
      end
    end

  end

end
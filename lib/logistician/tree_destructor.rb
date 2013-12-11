require 'logistician'
class Logistician
  module TreeDestructor

    def self.new(*args)
      Module.new.tap{|m| m.extend(self) }
    end

    class Node

      attr_reader :children, :complex_keys, :rules

      def dup
        s = super
        s.instance_variable_set(:@children, @children.dup)
        s.instance_variable_set(:@rules, @rules.dup)
        s.instance_variable_set(:@complex_keys, @complex_keys.dup)
        return s
      end

      def initialize
        @children = Hash.new{|hsh,key| hsh[key] = Node.new }
        @complex_keys = []
        @rules = {}
      end

      def append( *rules, action )
        rules.each do |rule|
          if rule.kind_of? Macro
            rule.call(self)
          elsif( rule.kind_of?(Hash) and rule.size == 1 )
            key = rule.keys.first
            unless key.kind_of?(String) or children.key?(key)
              @complex_keys << key
            end
            children[ key ].append( rule.values.first, action )
          else
            @rules[ rule ] = action
          end
        end
        return self
      end

      def detect( prefix, value, block )
        if( value.kind_of? Hash )
          value = value.dup
          value.keys.each do |k|
            if @children.key?(k)
              if !@children[k].detect( prefix, value[k], block )
                value.delete(k)
              end
            end
          end
          @complex_keys.each do |key|
            value.each do |k,v|
              key_result = match(key, k)
              if key_result
                if !@children[key].detect( prefix + key_result, v, block )
                  value.delete(k)
                end
              end
            end
          end
          if value.size == 0
            return nil
          end
        end
        @rules.each do |rule, action|
          if result = match( rule, value )
            if block.call( action, *prefix, *result ) != false
              return nil
            end
          end
        end
        return value
      end

      def match( rule, value )
        case( rule )
        when Regexp then
          if value.kind_of? String
            rule.match( value ){|m| return [m] }
          else
            return nil
          end
        when Array then
          return nil unless value.kind_of? Array
          result = []
          value.each do |i|
            found = false
            rule.each do |r|
              m =  match(r, i)
              if m 
                result.push( *m )
                found = true
                break
              end
            end
            return nil unless found
          end
          return [result]
        when Hash
          return nil unless value.kind_of? Hash
          result = []
          value = value.dup
          rule.each do |k, v|
            sub = match( v, value.delete(k) )
            return nil if sub.nil?
            result.push(*sub)
          end
          if value.size > 0
            return nil
          end
          return result
        when String, Numeric
          if rule == value
            return [value]
          end
        when ->x{ x.respond_to? :call}
          return rule.call(value)
        else
          if rule === value 
            return [value]
          end
        end
        return nil
      end

      def explain
        buffer = []
        @children.each do |key, value|
          value.explain.each do |sub|
            buffer << "#{key.inspect} => #{sub}"
          end
        end
        @rules.each do |rule, action|
          buffer << "#{rule.inspect} ==>> #{action.inspect}"
        end
        return buffer
      end

    end

    class Action

      def call(*args)
        if args.size == 1 and args[0].kind_of?(Symbol)
          @symbol = args[0]
          return self
        else

        end
      end
      
      def to_proc
        sym = @symbol
        @proc ||= lambda{|*args|
          send(sym,*args)
        }
      end

    end

    class Macro

      def call(node)
      end

    end

    def self.included(base)
      base.extend(ModuleMethods)
    end

    def self.extended(base)
      base.extend(ModuleMethods)
    end

    module ModuleMethods

      def on(*rules,&block)
        if block
          (@destructor_node ||= Node.new).append(*rules,block)
          return self
        else
          action = Action.new
          (@destructor_node ||= Node.new).append(*rules,action)
          return action
        end
      end

      def macro(name,*args,&block)
        return macros[name].new(*args,&block) if macros.key?(name) 
        superclass.macro(name,*args,&block) if superclass.respond_to?(:macro)
      end

      def macros
        @macros ||= {}
      end

      def each(value, &block)
        if !block
          return Enumerable::Enumerator.new(self, :each, value)
        end
        return (@destructor_node ||= Node.new).detect( [], value, block)
      end

      def parse(value)
        return each(value){|action, *args|
          self.instance_exec(*args,&action)
        }
      end

      def explain
        (@destructor_node ||= Node.new).explain 
      end

    end

    def parse(value)
      return self.class.each(value){|action, *args|
        self.instance_exec(*args,&action)
      }
    end

  end

end

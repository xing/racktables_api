require 'set'
require 'logistician'

class Logistician::Exporter

  module FakeClass

    def fake_class(klass = nil)
      klass ? @fake_class = klass : @fake_class
    end

  end

  module Deferred
  end

  class Lazy

    include FakeClass
    include Deferred

    def initialize(fc, infos = {} , &block)
      fake_class(fc)
      @infos = infos
      @block = block
    end

    def call
      @block.call
    end

    def [](key)
      @infos[key]
    end

    def method_missing(name,*args)
      if args.none?
        return @infos[name]
      end
      super
    end

  end

  NA = Module.new

  module DSL

    def export(what, options = {}, &block)
      if @type_map[what]
        @type_map[what].instance_eval(&block) if block
        return @type_map[what]
      end
      type = options[:using] || HashlikeType
      @type_map[what] = type.new(&block)
    end

  end

  include DSL

  module Referential

    def call(procedure, object, options)
      id = identify(procedure, object, options)
      if options[:as_link]
        return {'__ref__' => id}
      end
      procedure.once(id) do
        result = super
        if result.kind_of? Hash
          result['__self__'] = id
        else
          result = { '__self__' => id, '__data__' => result }
        end
        next result
      end
    end

    def identify_by(&block)
      @identify_by = block if block
      return @identify_by
    end

    def identify(procedure, object, options = {})
      EncodeContext.new( procedure, options).instance_exec( object, &identify_by)
    end

  end

  class EncodeContext

    attr_reader :options

    def initialize(procedure, options)
      @procedure = procedure
      @options = options
    end

    def context
      @procedure.context
    end

    def encode(x, as = x, opts = options)
      enc = @procedure.exporter.get_encoder(as)
      return enc.call(@procedure, x, opts )
    end

    def lazy(*args,&block)
      return Lazy.new(*args, &block)
    end

    def reference(uri)
      return {'__ref__' => uri}
    end

  end

  class HashlikeType

    module Dynamic
      def self.call(obj,procedure)
        #procedure.
        procedure.call(obj)
      end
    end

    module DSL

      def publish(key,opts = {}, &block)
        sym = key.to_sym
        name = (opts[:as] || key).to_s
        block ||= opts[:block] || lambda{ |object| encode( object.send(sym) ) }
        @keys[name] = opts.merge({:as => name,:block => block})
        return self
      end

      def referential(&block)
        extend Referential
        identify_by(&block)
        self
      end

    end

    include DSL

    def initialize(&block)
      @keys = {}
      instance_eval(&block) if block
    end

    def call(procedure, object, options)
      object = object.call if object.kind_of? Deferred
      result = {}
      @keys.each do |k, opt|
        val = EncodeContext.new(procedure,opt).instance_exec(object, &opt[:block] )
        if val != NA
          result[k] = val
        end
      end
      return result
    end

  end

  class ArraylikeType

    def initialize(&block)
      @mapper = ->(x){ encode(x) }
      instance_eval(&block) if block
    end

    def call(procedure, object, options)
      object = object.call if object.kind_of? Deferred
      result = []
      object.each do |x|
        val = EncodeContext.new(@mapper,opt).instance_exec(x, &opt[:block] )
        if val != NA
          result << val
        end
      end
      return result
    end

  end

  class Rewrite

    def rewrite(&block)
      @rewrite = block
    end

    def call(procedure, object, options)
      object = object.call if object.kind_of? Deferred
      return EncodeContext.new(procedure,options).instance_exec(object, &@rewrite )
    end

    def initialize(&block)
      instance_eval(&block)
    end

  end

  module Builtin
    def self.call(_,x,_)
      return x
    end
    def self.new
      return self
    end
  end

  module ArrayBuiltin
    def self.call(procedure,x,options)
      return x.map{|o| procedure.call(o,options) }
    end
    def self.new
      return self
    end
  end

  module HashBuiltin
    def self.call(procedure,x,options)
      return Hash[ x.map{|k, o| [k.to_s, procedure.call(o,options)] } ]
    end
    def self.new
      return self
    end
  end

  def initialize(options = {}, &block)
    @type_map = {}
    unless options[:builtin] == false
      add_defaults!
    end
    instance_eval(&block) if block
  end

  class ExportProcedure

    attr_reader :context, :exporter

    def initialize(ctx, exporter)
      @context = ctx
      @exporter = exporter
      @exported = Set.new
    end

    def once(id)
      if !@exported.include? id
        @exported << id
        return yield
      else
        return {'__ref__' => id }
      end
    end

    def call(object, options)
      @exporter.get_encoder(object).call(self,object,options)
    end

    def identify(object, options = {})
      @exporter.get_encoder(object).identify(self, object, options)
    end

  end

  def referential?(x)
    get_encoder(x).kind_of? Referential
  end

  def identify(ctx, object, options = {})
    procedure(ctx).identify(object,options)
  end

  def get_encoder(x)
    if x.kind_of? FakeClass
      klass = x.fake_class
    elsif x.kind_of? Class
      klass = x
    else
      klass = x.class
    end
    while klass != Object do
      return @type_map[klass] if @type_map.key? klass
      klass = klass.superclass
    end
    raise("Can't find an encoder for #{x}.")
  end

  def call(options)
    procedure(options[:context]).call(options[:object], options)
  end

  def procedure(context)
    return ExportProcedure.new(context,self)
  end

  def add_defaults!
    [ String, Fixnum, Integer, Float, TrueClass, FalseClass, NilClass ].each do |t|
      @type_map[t] = Builtin
    end
    @type_map[Array] = ArrayBuiltin
    @type_map[Hash] = HashBuiltin
  end
end
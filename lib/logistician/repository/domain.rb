require 'logistician/repository'
class Logistician
  class Repository::Domain

    attr_reader :exporter

    class DSL

      attr_reader :domain

      def initialize(dom)
        @domain = dom
      end

      def use(repo_type)
        domain.repository_types << repo_type
        return self
      end

      def define(model, options = {}, &block)
        type = options[:type] || domain.repository_types.detect{|t| t.fits? model }
        name = options[:as]
        if !name
          raise ArgumentError, "Please pass a named Class or use the :as option to specify a name for this repository" if model.anonymous?
          name = model.name.pathize
        end
        repo = type.new(domain, model, :as => name , &block)
        domain[name] = repo
        return self
      end

      def export(*args,&block)
        domain.exporter.export(*args,&block)
        return self
      end

    end

    CLASS_REGEX = /\A[A-Z_][A-Za-z0-9_]*(::[A-Z_][A-Za-z0-9_]*)*\z/

    attr_reader :repository_types, :exporter

    def initialize(&block)
      @repository_types = []
      @repositories_by_name = {}
      @repositories_by_class = {}
      @exporter = Exporter.new
      super(){}
      DSL.new(self).instance_eval(&block) if block
    end

    def [](*keys)
      keys.each do |key| 
        if key.kind_of? String
          if @repositories_by_name.key? key
            return @repositories_by_name[key]
          elsif CLASS_REGEX =~ key
            begin
              return self[constant(key)]
            rescue NameError
            end
          end
        elsif key.kind_of? Module
          while key
            if @repositories_by_class.key? key
              return @repositories_by_class[key]
            else
              key = key.superclass
            end
          end
        end
      end
      return nil
    end

    def []=(name,repo)
      @repositories_by_name[name] = repo
      if repo.respond_to? :model
        @repositories_by_class[repo.model] = repo
      end
      return repo
    end

    def export(ctx, object, projection = nil )
      @exporter.call( object: object, context: ctx, projection: projection )
    end

  end
end
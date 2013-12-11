module Model

  # By creating an anonymous class we get a model without dataset without
  # asking the database if a certain table exists.
  base = Class.new(Sequel::Model) do
    # The schema is not determined automatically
    def self.get_db_schema
      set_columns(nil)
      def_column_accessor(:id, :ip, :name, :type, :version)
      return {:object_id=>
        {:allow_null=>false,
         :default=>nil,
         :primary_key=>true,
         :db_type=>"int(10) unsigned",
         :type=>:integer,
         :ruby_default=>nil},
       :ip=>
        {:allow_null=>false,
         :default=>nil,
         :primary_key=>true,
         :db_type=>"binary(16)",
         :type=>:blob,
         :ruby_default=>nil},
       :name=>
        {:allow_null=>true,
         :default=>nil,
         :primary_key=>false,
         :db_type=>"char(255)",
         :type=>:string,
         :ruby_default=>nil},
       :type=>
        {:allow_null=>true,
         :default=>nil,
         :primary_key=>false,
         :db_type=>"enum('regular','shared','virtual','router')",
         :type=>:string,
         :ruby_default=>nil},
       :version=>
        {:allow_null=>false,
         :default=>nil,
         :primary_key=>false,
         :db_type=>"int(10) unsigned",
         :type=>:integer,
         :ruby_default=>nil},
      }
    end

    ds = DB[:IPv4Allocation].select(:object_id,Sequel.function(:LPAD, Sequel.function(:CHAR,:ip),4,"\0").as(:ip),:name,:type,Sequel.expr(4).as(:version)).union(
         DB[:IPv6Allocation].select(:object_id,:ip,:name,:type,Sequel.expr(6).as(:version)),
           :alias => :ip_allocation
         )

    # Supres additional sequel queryies to get the schema
    ds.instance_variable_set(:@columns, [:object_id,:ip,:name,:type,:version])
    set_dataset ds
  end


  class IpAllocation < base

    dataset_module do

      def clone(*args)
        result = super
        if result.v4?
          result.v4 = result.v4.clone
        end
        result.v6 = result.v6.clone if result.v6?
        return result
      end

      def v4?
        opts[:from][0].kind_of? Sequel::SQL::AliasedExpression
      end

      def v4=(x)
        opts[:from] = [ Sequel::SQL::AliasedExpression.new(x, opts[:from][0].aliaz) ]
      end

      def v4
        opts[:from][0].expression
      end

      def v6?
        v4? and opts[:from][0].expression.opts[:compounds]
      end

      def v6=(x)
        expr = v4.dup
        expr.opts[:compounds] = [[:union, x]]
        self.v4 = expr
      end

      def v6
        opts[:from][0].expression.opts[:compounds][0][1]
      end

      def extract_v4
        result = v4.clone(:compounds => [])
        result.filter(opts[:where]) if opts[:where]
        return IPv4.capture(result)
      end

      def extract_v6
        result = v6.clone
        result.filter(opts[:where]) if opts[:where]
        return IPv6.capture(result)
      end

    end

    def_column_alias(:obj_id, :object_id) 

    many_to_one :object, :class => 'Model::RackObject', :key => :obj_id, :key_column => :object_id

    class IPv4 < self

      set_dataset DB[:IPv4Allocation].select(:object_id,Sequel.function(:LPAD, Sequel.function(:CHAR,:ip),4,"\0").as(:ip),:name,:type,4 => :version)

      def ip
        @ip = IPAddress::IPv4.parse_data(self[:ip])
      end

      def version
        4
      end

      def v4?
        true
      end

      def v6?
        false
      end

    end

    class IPv6 < self

      set_dataset DB[:IPv6Allocation].select(:object_id,:ip,:name,:type,6 => :version)

      def ip
        @ip = IPAddress::IPv6.parse_data(self[:ip])
      end

      def version
        6
      end

      def v4?
        false
      end

      def v6?
        true
      end

    end


    def self.capture(union)
      union.row_proc = self
      union.model = self if union.respond_to?(:model=)
      return union
    end

    def self.call(row)
      return super unless self == IpAllocation
      raise ArgumentError unless row.kind_of? Hash
      case(row[:version])
      when 4 then return IPv4.call(row)
      when 6 then return IPv6.call(row)
      else raise ArgumentError, "Unknown IP version: #{row.inspect}"
      end
    end

  end
end


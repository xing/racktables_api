module Model

  # By creating an anonymous class we get a model without dataset without
  # asking the database if a certain table exists.
  base = Class.new(Sequel::Model) do
    # The schema is not determined automatically
    def self.get_db_schema
      set_columns(nil)
      def_column_accessor(:id, :ip, :mask, :name, :comment, :version)
      return {:id=>
        {:allow_null=>false,
         :default=>nil,
         :db_type=>"int(10) unsigned",
         :type=>:integer,
         :ruby_default=>nil},
       :ip=>
        {:allow_null=>false,
         :default=>nil,
         :primary_key=>false,
         :db_type=>"binary(16)",
         :type=>:blob,
         :ruby_default=>nil},
       :mask=>
        {:allow_null=>false,
         :default=>nil,
         :primary_key=>false,
         :db_type=>"int(10) unsigned",
         :type=>:integer,
         :ruby_default=>nil},
       :name=>
        {:allow_null=>true,
         :default=>nil,
         :primary_key=>false,
         :db_type=>"char(255)",
         :type=>:string,
         :ruby_default=>nil},
       :comment=>
        {:allow_null=>true,
         :default=>nil,
         :primary_key=>false,
         :db_type=>"text",
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

    ds = DB[:IPv4Network].select(:id,:ip,:mask,:name,:comment,Sequel.expr(4).as(:version)).union(
         DB[:IPv6Network].select(:id,:ip,:mask,:name,:comment,Sequel.expr(6).as(:version)),
           :alias => :networks
         )

    # Supres additional sequel queryies to get the schema
    ds.instance_variable_set(:@columns, [:id,:ip,:mask,:name,:comment, :version])

    set_dataset ds

  end

  class Network < base

    dataset_module do

      def clone(*args)
        result = super
        result.v4 = result.v4.clone if result.v4?
        result.v6 = result.v6.clone if result.v6?
        return result
      end

      def v4?
        opts[:from][0].kind_of? Sequel::SQL::AliasedExpression
      end

      def v4=(x)
        opts[:from][0].instance_variable_set(:@expression, x)
      end

      def v4
        opts[:from][0].expression
      end

      def v6?
        v4? and opts[:from][0].expression.opts[:compounds]
      end

      def v6=(x)
        opts[:from][0].expression.opts[:compounds][0][1] = x
      end

      def v6
        opts[:from][0].expression.opts[:compounds][0][1]
      end

      def extract_v4
        result = v4.clone(:compounds => [])
        result.filter!(opts[:where]) if opts[:where]
        return IPv4.capture(result)
      end

      def extract_v6
        result = v6.clone
        result.filter!(opts[:where]) if opts[:where]
        return IPv6.capture(result)
      end

    end

    def vlan_id
      0
    end

    many_to_one :vlan, class: "Model::VLan",
      eager_loader: ->(eo){
        v4, v6 = eo[:rows].partition(&:v4?)
        assocs = eo[:associations].kind_of?(Hash) ? eo[:associations] : Array(eo[:associations]).inject({}){|memo,key| memo[key]=[]; memo }
        [ [v4,:VLANIPv4, :ipv4net_id], [v6,:VLANIPv6, :ipv6net_id] ].each do |rows, table, column|
          id_map = {}
          rows.each do |row|
            id_map[row.id] = row
            row.associations[:vlan] = nil
          end
          VLan.capture(DB[table].where(column => id_map.keys)).eager(assocs).all.each do |vlan|
            id_map[vlan[column]].associations[:vlan] = vlan
          end
        end
      }

    class IPv4 < Network

      set_dataset DB[:IPv4Network].select(:id,:ip,:mask,:name,:comment,Sequel.expr(4).as(:version))

      many_to_one :vlan, class: "Model::VLan",
        dataset: ->{ VLan.capture(DB[:VLANIPv4].where(:ipv4net_id => id)) }

      def ip
        @ip ||= IPAddress::IPv4.parse_u32(self[:ip].to_i,self[:mask])
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

    class IPv6 < Network

      set_dataset DB[:IPv6Network].select(:id,:ip,:mask,:name,:comment,Sequel.expr(6).as(:version))

      many_to_one :vlan, class: "Model::VLan",
        dataset: ->{ VLan.capture(DB[:VLANIPv6].where(:ipv6net_id => id)) }

      def ip
        @ip ||= begin
          IPAddress::IPv6.parse_data(self[:ip]).tap{|ip| ip.prefix = self[:mask] }
        end
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
      return super unless self == Network
      raise ArgumentError unless row.kind_of? Hash
      case(row[:version])
      when 4 then return IPv4.call(row)
      when 6 then return IPv6.call(row)
      else raise ArgumentError, "Unknown IP version: #{row.inspect}"
      end
    end

  end
end

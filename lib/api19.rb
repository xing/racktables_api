require 'ipaddress'
require 'logistician/sequel'
require 'logistician'
require 'model/object'
require 'model/rack_object'
require 'model/rack'
require 'model/port'
require 'model/tag'
require 'model/space'
require 'model/ipv4allocation'
require 'model/ip_allocation'
require 'model/network'
require 'model/vlan'
require 'attribute_query'
require 'attribute_write'
require 'double_filter'

API19 = Logistician::Repository::Domain.new do

  use Logistician::Sequel::Repository

  export Sequel::Dataset, :using => Logistician::Exporter::Rewrite do
    rewrite {|ds| encode(ds.all) }
  end

  export Addressive::URIBuilder, :using => Logistician::Exporter::Rewrite do
    rewrite {|ds| ds.to_s }
  end

  export IPAddress::IPv4 do 

    publish :__type__ do 'IPAddress' end
    publish :address do |ip| ip.to_s end
    publish :prefix do |ip| ip.prefix.to_i end
    publish :netmask do |ip| ip.netmask.to_s end
    publish :version do |ip| 4 end

  end

  export IPAddress::IPv6 do 

    publish :__type__ do 'IPAddress' end
    publish :address do |ip| ip.to_s end
    publish :prefix do |ip| ip.prefix.to_i end
    publish :netmask do |ip| IPAddress::IPv6.parse_u128(ip.prefix.to_u128).to_s end
    publish :version do |ip| 6 end

  end

  define Model::RackObject, :as => 'object' do

    publish :id, :updateable => false, :createable => false
    publish :name,
      updateable: :single, # names must be unique, batch updates are pointless
      export: ->(object) do object.name.to_s end
    publish :label
    publish :asset_no
    publish :type
    publish :tags,
      post_filter: ->(result){ result.descendants(:with_self => true) }
    publish :rack_id,
      as: 'rack',
      export: {
        as_link: true,
        block: ->(object) do object.rack_id ? encode( lazy(Model::Rack,:id => object.rack_id){ object.rack } ) : nil end
      }
    publish :spaces
    publish :ports
    publish :ips

    export do

      referential do |object| context[:addressive].uri(:api, :object, :single, id: object.id).to_s end

      publish :has_problems do |object| object.has_problems == 'yes' end

      publish :attributes do |object| encode( Hash[ object.attributes.map{|a| [a.name, a.value.kind_of?(Time) ? a.value.strftime('%Y-%m-%d') : a.value ]} ] ) end

    end

    query do

      on [Object] do |queries|
        bad = nil
        queries.each_with_index do |query,index|
          rest = parse(query)
          if rest
            bad = {index => rest}
            break
          end
          or!
        end
        bad
      end

      on /\A\d+\z/ do |id|
        filter(
          :id => id[0].to_i
        )
      end

      on 'has_problems' => macro(:boolean){|op,value|
        ::Sequel::SQL::BooleanExpression.new(op, :has_problems, value ? 'yes' : 'no')
      }

      on( {'rack' => /\A\/rack\/(\d+)\z/}, {'rack'=>{'_eq'=>/\A\/rack\/(\d+)\z/}} ) do |match|
        filter(
          one_to_many_to_sql(
            model.association_reflection(:spaces),
            Model::Space.filter(:rack_id => match[1].to_i )
        ))
      end

      on 'rack' => Object do |subquery|
        subresult = domain['rack'].query(context, subquery)
        filter(
          one_to_many_to_sql(
            model.association_reflection(:spaces),
            Model::Space.filter(many_to_one_to_sql(Model::Space.association_reflection(:rack),subresult))
        ))
      end

      # querying with tag=??? is currently in some documentations
      # keep this for legacy
      on 'tag' => macro(:string){|op, value|
        many_to_many_to_sql(model.association_reflection(:tags), Model::Tag.filter(::Sequel::SQL::BooleanExpression.new(op, :tag, value)).descendants(:with_self=>true))
      } 

      on 'attributes' => {String => Object} do |name, query|
        type = Model::Attribute::Type[:name => name]
        next false if !type
        qt = AttributeQuery::TYPES[type.type].new
        rest = qt.parse(query)
        next false if rest
        if qt.expression.nil?
          next false
        end
        null_query = case type.type
          when 'dict'
            Model::Attribute.eager_graph(:dict).filter(qt.expression)
          when 'string', 'uint', 'float'
            Model::Attribute.filter(qt.expression)
          end
        # Find out where this query returns true for null
        null_query = null_query.select(1).from(DB.select(Sequel.expr(nil).as(:object_id),
                                                         Sequel.expr(nil).as(:object_tid),
                                                         Sequel.expr(nil).as(:attr_id),
                                                         Sequel.expr(nil).as(:string_value),
                                                         Sequel.expr(nil).as(:uint_value),
                                                         Sequel.expr(nil).as(:float_value)).as(:AttributeValue))
        double_invert = !null_query.first.nil?
        expr = qt.expression
        expr = ~expr if double_invert
        query = case type.type
          when 'dict'
            Model::Attribute.filter(:attr_id => type.pk ).eager_graph(:dict).filter(expr)
          when 'string', 'uint', 'float'
            Model::Attribute.filter(:attr_id => type.pk ).filter(expr)
          end
        if double_invert
          filter( ~one_to_many_to_sql(model.association_reflection(:attributes), query ) )
        else
          filter( one_to_many_to_sql(model.association_reflection(:attributes), query ) )
        end
      end

    end

    write do

      on 'attributes' => {String => Object} do |name, update|
        type = Model::Attribute::Type[:name => name]
        next false if !type
        qt = AttributeWrite::TYPES[type.type].new
        rest = qt.parse(update)
        next false if rest
        write( qt.write.curry[type] )
      end

    end

    def repository.get(ctx, get)
      return super(ctx, get)
    end

    def repository.postquery(ctx, query, dataset)
      return dataset.eager(:type, :spaces, :ips, :ports => [:type, :link => { :ports => :type } ], :attributes => [:type, :dict], :tags => :ancestors )
    end

  end

  define Model::Rack, :as => 'rack' do

    publish :id, :updateable => false
    publish :name
    publish :height
    publish :comment, export: ->(rack){ rack.comment.to_s }

    query do

      on /\A\d+\z/ do |id|
        filter(
          :id => id[0].to_i
        )
      end

      on 'row' => macro(:string){|op,value|
        many_to_many_to_sql(model.association_reflection(:row), Model::RackRow.filter(::Sequel::SQL::BooleanExpression.new(op, :name, value)))
      }

    end

    export do

      referential do |rack| context[:addressive].uri(:api, :rack, :single, id: rack.id).to_s end

      publish :row do |object| if orf = object.row.first ; orf.name ; end ; end
      publish :content do |rack|
        reference( context[:addressive].uri(:api, :object, query: {rack: rack.id} ).to_s )
      end

    end

    def repository.postquery(ctx, query, dataset)
      return dataset.eager(:row, :attributes)
    end

  end

  define Model::Port, :as => 'port' do

    publish :id, :updateable => false, :createable => false
    publish :name
    publish :label
    publish :object,
      export: {
        as_link: true,
        block: ->(port) do encode( lazy(Model::RackObject,:id => port.obj_id){ port.object } ) end
      }
    publish :type
    publish :remote_port
    publish :l2address
    publish :cable

    query do

      on /\A\d+\z/ do |id|
        filter(
          :id => id[0].to_i
        )
      end

      on 'l2address' => macro(:fixed_hex_bin, :string, 12){|op, value|
        ::Sequel::SQL::BooleanExpression.new(op, :l2address, value)
      }

      on 'object' => /\A\/object\/(\d+)\z/ do |match|
        filter( :object_id => match[1].to_i )
      end 

      on 'remote_port' => /\A\/port\/(\d+)\z/ do |match|
        subresult = domain['port'].query(context, subquery)
        cond =::Sequel::SQL::BooleanExpression.new(:OR,
            {:Port__id => Model::Link.select(:Link__porta).filter(:Link__portb => match[1].to_i ) },
            {:Port__id => Model::Link.select(:Link__portb).filter(:Link__porta => match[1].to_i ) }
          )
        filter( cond )
      end

      on( 'remote_port' => Object ) do |subquery|
        subresult = domain['port'].query(context, subquery)
        cond =::Sequel::SQL::BooleanExpression.new(:OR,
            {:Port__id => Model::Link.select(:Link__porta).filter(:Link__portb => subresult.select(:Port__id)) },
            {:Port__id => Model::Link.select(:Link__portb).filter(:Link__porta => subresult.select(:Port__id)) }
          )
        filter( cond )
      end

      on( 'cable' => macro(:string){|op,value|
        f = ::Sequel::SQL::BooleanExpression.new(op, :cable, value)
        ::Sequel::SQL::BooleanExpression.new(:OR,
            {:Port__id => Model::Link.select(:Link__porta).filter( f ) },
            {:Port__id => Model::Link.select(:Link__portb).filter( f ) }
        )
      })

    end

    export do

      referential do |port| context[:addressive].uri(:api, :port, :single, id: port.id).to_s end

    end

    write do

      on 'cable' => String do |value|
        write( ->(port){ port.cable = value } )
      end

    end

    def repository.postquery(ctx, query, dataset)
      return dataset.eager(:type, :link => {:ports => :type})
    end

  end

  define Model::Tag, :as => 'tag' do

    REGEX = /\A[a-z0-9_\-]+(?:\.[a-z0-9_\-]+)*\z/i

    query do

      on( '_eq' => REGEX ) do |value|

        *path, lst = value.to_s.split('.')
        q = path.inject(nil){|memo, name|
          Model::Tag.select(:id).where( :tag => name, :parent_id => memo )
        }
        filter({:tag => lst, :parent_id => q })

        nil

      end

      on( REGEX , '_sub' => REGEX) do |value|

        *path, lst = value.to_s.split('.')
        q = path.inject( {} ){|memo, name|
          {:parent_id => Model::Tag.select(:id).where( {:tag => name}.merge( memo )  )}
        }
        filter({:tag => lst}.merge(q))

        nil

      end

      on [REGEX] do |queries|

        if queries.none?
          filter(false)
          next
        end

        bad = nil
        queries.each_with_index do |query,index|
          rest = parse(query.to_s)
          if rest
            bad = {index => rest}
            break
          end
          or!
        end
        bad

      end

    end

    export :using => Logistician::Exporter::Rewrite do

      rewrite{|object| 
        [ *object.ancestors.reverse.map(&:tag), object.tag ].join('.')
      }

    end

  end

  define Model::DictionaryValue, :as => 'dictionary_value' do

    query do

      on macro(:string){|op, value|
        ::Sequel::SQL::BooleanExpression.new(op,:dict_value, value)
      }

    end

    export :using => Logistician::Exporter::Rewrite do

      rewrite{|object| 
        object.dict_value
      }

    end

  end

  define Model::Space, :as => 'space' do

    publish :unit_no
    publish :atom

  end

  define Model::Network, :as => 'network' do

    publish :ip, as: "range"
    publish :vlan
    publish :name
    publish :comment

    endpoints[:single].primary_key = ['range']

    query do

      include DoubleFilter

      on 'vlan' => macro(:to_one){|subquery|
        ds = domain['vlan'].query(context, subquery)
        DoubleFilter::InvertableHash[
          4, ::Sequel::SQL::BooleanExpression.new(:IN, :id, ds.extract_v4.select(:ipv4net_id) ),
          6, ::Sequel::SQL::BooleanExpression.new(:IN, :id, ds.extract_v6.select(:ipv6net_id) )
        ]
      }

      on( "range" => ->(x){ (x.kind_of?(String) ? [IPAddress.parse(x)] : nil) rescue nil } ) do |ip|

        if ip.ipv4?

          filter4( ::Sequel::SQL::BooleanExpression.new(:'=', :ip, ip.to_u32 ) )
          filter4( ::Sequel::SQL::BooleanExpression.new(:'=', :mask, ip.prefix.to_i ) )

        else

          filter6( ::Sequel::SQL::BooleanExpression.new(:'=', :ip, ::Sequel.blob(ip.data) ) )
          filter6( ::Sequel::SQL::BooleanExpression.new(:'=', :mask, ip.prefix.to_i ) )

        end

      end

    end

    export do

      referential do |network|
        context[:addressive].uri(:api, :network, :single, range: network.ip.to_string ).to_s
      end

    end

    def repository.postquery(ctx, query, dataset)
      return dataset.eager(:vlan => :domain)
    end


  end

  define Model::VLan, :as => 'vlan' do

    publish :vlan_id, as: 'id'
    publish :domain
    publish :vlan_type, as: 'type'
    publish :vlan_descr, as: 'description'
    publish :networks, 
      queryable: false,
      export: ->(vlan){
          if vlan.associations.key? :networks 
            encode(vlan.networks) 
          else
            reference( context[:addressive].uri(:api, :network, :default, query: {'vlan.id' => vlan.vlan_id,'vlan.domain' => vlan.domain.to_s}).to_s )
          end
        }

    endpoints[:single].primary_key = [:domain,:id]

    query do

      on 'id' => macro(:integer){|op, value|
        ::Sequel::SQL::BooleanExpression.new(op, :vlan_id,  value)
      }

      on 'networks' => macro(:to_many){|subquery|
        ds = domain['network'].query(context, subquery)
        ::Sequel::SQL::BooleanExpression.new( :OR,
          many_to_many_to_sql( repository.model.association_reflection(:ipv4networks), ds.extract_v4.select(:id) ),
          many_to_many_to_sql( repository.model.association_reflection(:ipv6networks), ds.extract_v6.select(:id) )
        )
      }

    end

    export do

      referential do |vlan| context[:addressive].uri(:api, :vlan, :single, domain: vlan.domain, id: vlan.vlan_id).to_s end

    end

    def repository.postquery(ctx, query, dataset)
      return dataset.eager(:domain, :networks)
    end

  end

  define Model::VLan::Domain, :as => 'vlan_domain' do

    query do

      on macro(:string){|op,value|
        ::Sequel::SQL::BooleanExpression.new(op, :description, value)
      }

    end

    export :using => Logistician::Exporter::Rewrite do

      rewrite{|object| 
        object.description
      }

    end

  end

  define Model::IpAllocation, :as => 'ip' do

    publish :object,
      export: {
        as_link: true,
        block: ->(ip_alloc) do encode( lazy(Model::RackObject,:id => ip_alloc.obj_id){ ip_alloc.object } ) end
      }
    publish :version
    publish :type
    publish :ip
    publish :name

    export do
      publish :__type__ do 'IPAllocation' end
      # For backward compat
      publish :address do |alloc| '%08x' % alloc.ip end
    end

    query do
      include DoubleFilter
      on( "ip" => ->(x){ (x.kind_of?(String) ? [IPAddress.parse(x)] : nil) rescue nil } ) do |ip|
        if ip.ipv4?
          filter4( ::Sequel::SQL::BooleanExpression.new(:'=', :ip, ip.to_u32 ) )
        else
          filter6( ::Sequel::SQL::BooleanExpression.new(:'=', :ip, ::Sequel.blob(ip.data) ) )
        end
      end
    end
  end
end

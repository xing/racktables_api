module Model

  class Port < Sequel::Model(DB[:Port])

    plugin :instance_hooks

    def_column_alias(:obj_id, :object_id)
    many_to_one :object, :class => 'Model::RackObject', :key => :obj_id, :key_column => :object_id

    many_to_one :link, :class => 'Model::Link', :foreign_key => :porta, :key => :id,
      :dataset=>(proc do
        Link.filter( id => [:porta,:portb] )
        end),
      :eager_loader=>(proc do |eo|
        kh = eo[:key_hash][:id]
        links = {}
        assocs = eo[:associations].kind_of?(Hash) ? eo[:associations] : Array(eo[:associations]).inject({}){|memo,key| memo[key]=[]; memo }
        pl_assoc = assocs.delete(:ports)
        ds = Link.filter( Sequel::SQL::BooleanExpression.new(:OR, {:porta => kh.keys} , {:portb => kh.keys} ) ).eager(assocs)
        if pl_assoc 
          missing = {}
          ds.all.each{|link|
            links[link.porta_id] = link
            links[link.portb_id] = link
            link.associations[:ports] = []
            if( kh.key? link.porta_id )
              link.associations[:ports].push( *kh[link.porta_id] )
            else
              missing[link.porta_id] = link
            end
            if( kh.key? link.portb_id )
              link.associations[:ports].push( *kh[link.portb_id] )
            else
              missing[link.portb_id] = link
            end
          }
          unless missing.empty?
            p = Port.filter( :id => missing.keys ).eager(pl_assoc)
            p.all.each do |port|
              missing[port.id].associations[:ports] << port
              port.associations[:link] = missing[port.id]
            end
          end
        else
          ds.all.each{|link|
            links[link.porta_id] = link
            links[link.portb_id] = link
          }
        end
        kh.each do |id, ports|
          ports.each do |port|
            port.associations[:link] = links[id]
          end
        end
        end)


    many_to_one :type, :class => 'Model::DictionaryValue', :foreign_key => :dict_key , :key => :oif_id, :key_column => :type, :conditions => {:chapter_id=>2}

    def remote_port
      return nil unless link
      return (link.ports - [self]).first
    end

    def oif_id
      return self[:type]
    end

    def oif_id=(id)
      oif = DB['SELECT `iif_id` FROM `PortInterfaceCompat` WHERE `oif_id` = ?', id].first
      raise "Invalid oif_id: #{id}" if oif.nil?
      self[:iif_id] = oif[:iif_id]
      self[:type] = id
      return id
    end

    def cable
      if link
        link.cable
      end
    end

    def cable=(cb)
      if link
        link.cable = cb
        after_save_hook{ link.save }
      end
    end

  end

end
require 'model/rack_object'
require 'model/link'

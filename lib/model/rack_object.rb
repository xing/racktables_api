module Model
  class RackObject < Model::Object

    plugin :association_pks

    set_dataset(Model::Object.dataset.filter(::Sequel.~( :objtype_id => Model::Object::MODEL_MAP.keys ) ))

    one_to_many :spaces, :class => 'Model::Space', :key_method => :obj_id, :key => :object_id

    one_to_many :ports, :class => 'Model::Port', :key_method => :obj_id, :key => :object_id

    one_to_many :ipv4allocations, :class=>'Model::IPv4Allocation', :key_method => :obj_id, :key => :object_id

    one_to_many :ips, :class => 'Model::IpAllocation', :key_method => :obj_id, :key => :object_id

    def rack
      if sf = spaces.first
        sf.rack
      end
    end

    def rack_id
      if sf = spaces.first
        sf.rack_id
      end
    end

    def ips=(ips)
      if @values.key? :id
        #self.remove_all_ips
        ips.each do |ip|
          ip.object = self
        end
      else
        after_save_hook{
          self.ips = ips
        }
      end
    end

  end
end

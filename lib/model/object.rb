module Model
  class Object < Sequel::Model(DB[:Object])


    class Link < Sequel::Model(DB[:EntityLink])

      many_to_one :parent, :key => :parent_entity_id, :class => 'Model::Object'
      many_to_one :child, :key => :child_entity_id, :class => 'Model::Object'

    end

    MODEL_MAP = Hash.new{ 'Model::RackObject' }
    MODEL_MAP.update(
      1560 => 'Model::Rack',
      1561 => 'Model::RackRow'
    )

    plugin :single_table_inheritance, :objtype_id,
      :model_map=>MODEL_MAP

    plugin :instance_hooks
    plugin :association_pks

    many_to_one :type, :key => :objtype_id, :class => 'Model::ObjectType'

    one_to_many :parent_links, :foreign_key => :child_entity_id, :class => 'Model::Object::Link'
    one_to_many :child_links, :foreign_key => :parent_entity_id, :class => 'Model::Object::Link'

    many_to_many :tags, 
      :join_table => :TagStorage, 
      :left_key => :entity_id,
      :conditions => {:entity_realm=>'object'}

    one_to_many :attributes, :class => 'Model::Attribute', :key_method => :obj_id, :key => :object_id

    def tags=(tgs)
      after_save_hook{
        self.tag_pks = tgs.map(&:id)
      }
    end

  end
end
require 'model/object_type'
require 'model/attribute'
require 'model/space'
require 'model/port'
require 'model/ipv4allocation'
require 'model/rack_object'

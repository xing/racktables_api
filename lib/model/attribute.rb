require 'forwardable'
module Model
  
  class Attribute < Sequel::Model(DB[:AttributeValue])
    
    extend Forwardable
    
    delegate :name => :type
    
    class Type < Sequel::Model(DB[:Attribute])
      
      one_to_many :map, :class => 'Model::Attribute::Map', :key => :attr_id
      
      def values
        map.values
      end

      def map_for(type)
        map_dataset.filter(:object_type => type)
      end
      
    end
    
    class Map < Sequel::Model(DB[:AttributeMap])
      
      many_to_one :type, :class => 'Model::Attribute::Type', :key => :attr_id, :primary_key => :id
      many_to_one :object_type, :class => 'Model::ObjectType', :key => :objtype_id
      one_to_many :chapter, :class => 'Model::DictionaryValue', :key => :chapter_id, :primary_key => :chapter_id

    end
    
    def_column_alias(:obj_id, :object_id)

    many_to_one :type, :class => 'Model::Attribute::Type', :key => :attr_id
    many_to_one :object, :class => 'Model::RackObject', :key => :obj_id, :key_column => :object_id
    many_to_one :dict, :class => 'Model::DictionaryValue', :key => :uint_value, :foreign_key => :dict_key

    def dict_value
      if dict
        dict.dict_value
      end
    end
    
    def value
      case(type.type)
        when 'uint' then uint_value
        when 'string' then string_value
        when 'float' then float_value
        when 'date' then 
          if uint_value 
            Time.at(uint_value)
          end
        when 'dict' then dict_value
      end
    end

  end
end

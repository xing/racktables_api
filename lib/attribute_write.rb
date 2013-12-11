require 'logistician'
require 'logistician/sequel'
class AttributeWrite
  include Logistician::TreeDestructor

  def make_update(value)
    return ->(type, object){
      object.after_save_hook do
        map = type.map_for(object.type).first
        if map.nil?
          raise "Bad value!"
        else
          attribute = {object_id: object.id, object_tid: object.objtype_id, attr_id: type.id }
          case( type.type )
          when 'string'
            attribute[:string_value] = value
          when 'date', 'uint'
            attribute[:uint_value] = value.to_i
          when 'float'
            attribute[:float_value] = value
          when 'dict'
            # D'oh
            dict = map.chapter_dataset.filter(:dict_value => value ).first
            if dict.nil?
              raise "Bad value!!"
            end
            attribute[:uint_value] = dict.dict_key
          end
        end
        Model::Attribute.dataset.replace( attribute )
      end
    }
  end

  def write(*args)
    @write = args[0] if args.any?
    return @write
  end

  TYPES = {}
  TYPES['string'] = Class.new(self){
    on( Logistician::Sequel::Write::StringMacro.new{|value| make_update(value) } )
  }
  TYPES['uint'] = Class.new(self){
    on( Logistician::Sequel::Write::IntegerMacro.new{|value| make_update(value) } )
  }
  TYPES['float'] = Class.new(self){
    on( Logistician::Sequel::Write::NumericMacro.new{|value| make_update(value) } )
  }

  TYPES['dict'] = Class.new(self){
    on( Logistician::Sequel::Write::StringMacro.new{|value| make_update(value) } )
  }

end
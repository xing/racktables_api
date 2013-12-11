module Model
  class Rack < Model::Object

    many_to_many :row , :class => 'Model::RackRow',
      :join_table => :EntityLink,
      :left_key => :child_entity_id,
      :right_key => :parent_entity_id,
      :conditions => {:parent_entity_type => 'row', :child_entity_type => 'rack'}

    def height
      attributes.each do |a|
        return a.uint_value if a.attr_id == 27
      end
    end

  end
end
require 'model/rack_row'

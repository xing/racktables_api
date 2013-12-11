module Model
  class IPv4Allocation < Sequel::Model(DB[:IPv4Allocation])

    def_column_alias(:obj_id, :object_id) 

    many_to_one :object, :class => 'Model::RackObject', :key => :obj_id, :key_column => :object_id

  end
end

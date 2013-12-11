module Model

  class Space < Sequel::Model(DB[:RackSpace])

    def_column_alias(:obj_id, :object_id)

    many_to_one :object, :class => 'Model::RackObject', :key => :obj_id, :key_column => :object_id
    many_to_one :rack, :class => 'Model::Rack', :key => :rack_id

    # Meanings for state:
    #  T = true, in use by an object
    #  U = unuseable, this space has problems
    #  F = free ( this is not inserted by RackTables )
    #  A = absent, this space is not available by design

  end

end

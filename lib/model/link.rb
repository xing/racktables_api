module Model

  class Link < Sequel::Model(DB[:Link])

    one_to_many :ports, :class => 'Model::Port', :key => [:id,:id],
      :dataset=>(proc do
        Port.filter( :id => [porta_id, portb_id] )
      end)

    def_column_alias(:porta_id, :porta)
    def_column_alias(:portb_id, :portb)

  end

end

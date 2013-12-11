require 'logistician/sequel'
require 'logistician/sequel/write'
class Logistician

  module Sequel

    class Create < Write

      def do!
        return create!.save(:raise_on_failure => true, :transaction => false, :changed => true)
      end

      def create!
        object = dataset.model.new
        apply_to!(object)
        return object
      end

    end

  end

end

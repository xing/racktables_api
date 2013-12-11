require 'logistician/sequel'
require 'logistician/sequel/write'
class Logistician

  module Sequel

    class Update < Write

      alias update write

      def native?
        updates.all?{|up| up.kind_of? Hash }
      end

      def do!
        if empty?
          return 0
        elsif native?
          return do_native!
        else
          return do_foreign!
        end
      end

    private

      def do_native!
        ups = updates.inject(:merge)
        return dataset.update(ups)
      end

      def do_foreign!
        i = 0
        ds = dataset
        if ds.respond_to? :for_update
          ds = ds.for_update
        end
        ds.each do |object|
          apply_to!(object)
          object.save(:raise_on_failure => true, :transaction => false, :changed => true)
          i = i + 1
        end
        return i
      end

    end

  end

end
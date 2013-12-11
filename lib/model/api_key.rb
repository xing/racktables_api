require 'securerandom'
module Model

  class ApiKey < Sequel::Model(META_DB[:api_key])

    unrestrict_primary_key

    def self.generate(opts)
      secret = SecureRandom.hex(16)
      loop do 
        key = SecureRandom.hex(16)
        begin
          r = self.create({:key=>key, :secret=>secret, :description=>''}.merge(opts))
          return r
        rescue Sequel::DatabaseError => e
          raise unless e.message =~ /Duplicate entry/
        end
      end
    end

  end

end

require 'logistician'
require 'logistician/context'
class Logistician

  module Utils

    def context(env)
      env.fetch('logistician.context'){
        env['logistician.context'] = Context.new
      }
    end

    def delinearize_query(hash)
      return hash unless hash.kind_of? Hash
      result = Hash.new{|hsh,key| hsh[key] = {}}
      hash.each do |key,value|
        prefix, rest = key.split('.',2)
        if rest
          result[prefix] = {} unless result.kind_of? Hash
          result[prefix][rest] = value
        else
          result[prefix] = value
        end
      end
      return result if result.size == 0
      if (0...result.size).all?{|i| result.key? i.to_s }
        return (0...result.size).map{|i| delinearize_query(result[i.to_s])}
      else
        return Hash[ result.map{|k,v|
          [k, delinearize_query(v) ]
        } ]
      end
    end

    extend self

  end

end
class Logistician

  module HTTPError

    attr_reader :http_status, :http_block
    attr_writer :http_status, :http_block

    def self.annote( exception, http_status = nil, &http_block )
      exception.extend( self )
      exception.http_status = http_status
      exception.http_block = http_block
    end

    def self.new(msg, status, &block)
      self::Class.new(msg, status, &block)
    end

    class Class < Exception
      include HTTPError

      def initialize(msg, http_status=500,&http_block)
        super(msg)
        self.http_status = http_status
        self.http_block = http_block || lambda{|rsp| rsp['Content-Type']='text/plain' ; http_status < 500 ? rsp.write(msg) : rsp.write('Something went wrong') }
      end

    end

  end

end

require 'logistician/utils'
require 'logistician/exporter'
require 'logistician/resource'
require 'logistician/tree_destructor'
require 'logistician/repository'

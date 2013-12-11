require 'logistician'
class Logistician

  class Unsupported < StandardError
  end

  class Resource

    ACTION = {
      "GET" => :get,
      "HEAD" => :head,
      "POST" => :post,
      "PUT" => :put,
      "DELETE" => :delete,
      "PATCH" => :patch
    }

    def get(ctx, env)
      raise Unsupported
    end

    def head(ctx, env)
      get(ctx)
    end

    def options(ctx, env)
      raise Unsupported
    end

    def put(ctx, env)
      raise Unsupported
    end

    def post(ctx, env)
      raise Unsupported
    end

    def delete(ctx, env)
      raise Unsupported
    end

    def patch(ctx, env)
      raise Unsupported
    end

    def call(env)
      method = ACTION[env["REQUEST_METHOD"]]
      ctx = Utils.context(env)
      self.__send__(method, ctx, env)
    end

  end

end


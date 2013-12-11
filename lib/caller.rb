class Caller

  class << self

    alias new2 new

    def new(app, &block)
      klass = Class.new(self)
      klass.send(:define_method, :call, &block)
      klass.new2(app)
    end

  end

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env)
  end

end
module DoubleFilter # non-chill btw!

  class InvertableHash < Hash

    def ~@
      return self.class[self.map{|k,v| [k, ~v] }]
    end

  end

  def initialize(*args)
    super
    @filter4 = Logistician::Sequel::Query::AppendableFilter.new
    @filter6 = Logistician::Sequel::Query::AppendableFilter.new
  end

  def filter(*args)
    if args.size == 1 and args.first.kind_of?(Hash) and args.first.keys.all?{|k| k.kind_of? Numeric }
      hash = args.first
      @filter4 << repository.model.dataset.send(:filter_expr,*hash[4]) if hash[4]
      @filter6 << repository.model.dataset.send(:filter_expr,*hash[6]) if hash[6]
    else
      return super
    end
    return @filter
  end

  def filter4(*args)
    @filter4 << repository.model.dataset.send(:filter_expr,*args) if args.size > 0
    @filter6 << false
    return @filter4
  end

  def filter6(*args)
    @filter4 << false
    @filter6 << repository.model.dataset.send(:filter_expr,*args) if args.size > 0
    return @filter6
  end

  def or!
    @filter4.or!
    @filter6.or!
  end

  def dataset
    result = repository.model.dataset.clone
    if @filter4.filter or @filter6.filter
      result.v4 = result.v4.filter(@filter4.filter)
      result.v6 = result.v6.filter(@filter6.filter)
    end
    if @limit
      result = result.limit(@limit)
    end
    return result
  end

end

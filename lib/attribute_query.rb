require 'logistician'
require 'logistician/sequel'
class AttributeQuery
  include Logistician::TreeDestructor

  def make_matcher(op, value)
    ::Sequel::SQL::BooleanExpression.new(op, self.class::NAME, value)
  end

  def filter(*exp)
    @filter.unshift(*exp)
  end

  def expression
    case(@filter.size)
    when 0 then Sequel::SQL::Constants::SQLTRUE
    when 1 then @filter.first
    else ::Sequel::SQL::BooleanExpression.new(:AND, *@filter)
    end
  end 

  def initialize
    @filter = []
  end

  TYPES = {}
  TYPES['string'] = Class.new(self){
    self::NAME = :string_value
    on( Logistician::Sequel::Query::StringMacro.new{|op,value| make_matcher(op,value) } )
    on( Logistician::Sequel::Query::NullMacro.new{|op,value| make_matcher(op,value) } )
  }
  TYPES['uint'] = Class.new(self){
    self::NAME = :uint_value
    on( Logistician::Sequel::Query::IntegerMacro.new{|op,value| make_matcher(op,value) },
        Logistician::Sequel::Query::NullMacro.new{|op,value| make_matcher(op,value) } )
  }
  TYPES['float'] = Class.new(self){
    self::NAME = :float_value
    on( Logistician::Sequel::Query::NumericMacro.new{|op,value| make_matcher(op,value) } )
    on( Logistician::Sequel::Query::NullMacro.new{|op,value| make_matcher(op,value) } )
  }
  TYPES['dict'] = Class.new(self){
    self::NAME = :dict_value
    on( Logistician::Sequel::Query::StringMacro.new{|op,value| make_matcher(op,value) } )
    on( Logistician::Sequel::Query::NullMacro.new{|op,value| make_matcher(op,value) } )
  }
end

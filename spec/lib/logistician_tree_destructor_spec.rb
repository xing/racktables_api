require 'logistician'
require 'logistician/tree_destructor'

describe Logistician::TreeDestructor do

  it "should destruct trees" do
    t = Logistician::TreeDestructor.new
    found = false
    t.on( '_foo' => '_bar' ) do
      found = true
    end
    t.parse( '_foo' => '_baz' ).should == {'_foo' => '_baz' }
    found.should == false
    t.parse( '_foo' => '_bar' ).should == nil
    found.should == true
  end

  it "should work with regexps" do
    t = Logistician::TreeDestructor.new
    found = nil
    t.on( '_foo' => /\A\d+\z/ ) do |match|
      found = match
    end
    t.parse( '_foo' => '_baz' ).should == {'_foo' => '_baz' }
    found.should be_nil
    t.parse( '_foo' => '666' ).should == nil
    found.should_not be_nil
    found[0].should == '666'
  end

  it "should be possible to work with arrays" do
    t = Logistician::TreeDestructor.new
    found = nil
    t.on( '_foo' => [String] ) do |strings|
      found = strings
    end
    t.parse( '_foo' => '_baz' ).should == {'_foo' => '_baz' }
    found.should be_nil
    t.parse( '_foo' => ['A','B'] ).should == nil
    found.should == ['A','B']
  end

  it "should be possible to work with hashes in arrays" do
    t = Logistician::TreeDestructor.new
    found = nil
    t.on( '_foo' => [Object] ) do |objects|
      found = objects
    end
    t.parse( '_foo' => '_baz' ).should == {'_foo' => '_baz' }
    found.should be_nil
    t.parse( '_foo' => [{'a'=>'A','b'=>'B'}, {'c'=>'C','d'=>'D'}] ).should == nil
    found.should == [{'a'=>'A','b'=>'B'}, {'c'=>'C','d'=>'D'}]
  end

  it "should be possible to work with hashes" do
    t = Logistician::TreeDestructor.new
    found = nil
    t.on( '_foo' =>{'a'=>String, 'b'=>String} ) do |*strings|
      found = strings
    end
    t.parse( '_foo' => '_baz' ).should == {'_foo' => '_baz' }
    found.should be_nil
    t.parse( '_foo' => {'a'=>'A','b'=>'B'} ).should == nil
    found.should == ['A','B']
  end

  it "should be possible to create classes" do
    c = Class.new{
      include Logistician::TreeDestructor

      on '_foo' => '_bar' do
        trigger!
      end

      def trigger!
        @trigger = true
      end

      def triggered?
        @trigger == true
      end
    }

    o = c.new
    o.parse('_foo' => '_bar').should == nil
    o.should be_triggered
  end

  it "should be possible to specify a method to call directly" do
    c = Class.new{
      include Logistician::TreeDestructor

      on('_foo' => '_bar').call(:trigger!)

      def trigger!(val)
        @trigger = true
      end

      def triggered?
        @trigger == true
      end
    }

    o = c.new
    o.parse('_foo' => '_bar').should == nil
    o.should be_triggered
  end

end

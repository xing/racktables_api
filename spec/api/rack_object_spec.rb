require 'helper/object_router'

module ObjectFixtures

  def use_fixture_set
    DB << "INSERT INTO Object (id, name, label, objtype_id, asset_no) VALUES (1, 'foo', 'bar', 13, 'baz')"
    DB << "INSERT INTO Object (id, name, label, objtype_id, asset_no) VALUES (2, 'server', NULL, 4, 'baaz')"
    # a rack:
    DB << "INSERT INTO Object (id, name, label, objtype_id, asset_no) VALUES (3, 'rack1', NULL, 1560, 'rack1')"
    DB << "INSERT INTO Object (id, name, label, objtype_id, asset_no) VALUES (4, 'rack2', NULL, 1560, 'rack2')"

    DB << "INSERT INTO TagTree (id, tag) VALUES (1,'baz');"
    DB << "INSERT INTO TagTree (id, tag) VALUES (2,'buz');"
    DB << "INSERT INTO TagTree (id, tag, parent_id) VALUES (3,'zab', 1);"
    DB << "INSERT INTO TagTree (id, tag, parent_id) VALUES (4,'zub', 2);"
    DB << "INSERT INTO TagTree (id, tag, parent_id) VALUES (5,'zub2', 4);"
    DB << "INSERT INTO TagStorage (tag_id, entity_id, entity_realm) VALUES (1,1,'object');"
    DB << "INSERT INTO TagStorage (tag_id, entity_id, entity_realm) VALUES (5,1,'object');"
    DB << "INSERT INTO RackSpace (rack_id, object_id) VALUES (3, 1);"

    DB << "INSERT INTO Attribute VALUES (50001, 'uint', 'attr');"
    DB << "INSERT INTO AttributeMap VALUES (4, 50001, NULL);"
    DB << "INSERT INTO AttributeValue (object_id, object_tid, attr_id, uint_value) VALUES (2, 4, 50001, 10);"

    DB << "INSERT INTO Attribute VALUES (50002, 'dict', 'bttr');"
    DB << "INSERT INTO AttributeMap VALUES (4, 50002, 29);" # 29 is the yes/no dict
    DB << "INSERT INTO AttributeValue (object_id, object_tid, attr_id, uint_value) VALUES (2, 4, 50002, 1500);" # 1500 is yes

    DB << "INSERT INTO IPv4Allocation VALUES (2, 1, 'eth0', 'regular');"
    DB << "INSERT INTO IPv6Allocation VALUES (2, '1234', 'eth0', 'regular');"
  end

end

describe "rack object api" do

  describe "querying" do

    include ObjectRouter
    include ObjectFixtures

    it "should be possible" do
      # These queries will be use by rt:
      use_fixture_set
      resp = mock_get('/object?name=foo')
      resp.should be_ok
      MultiJson.load(resp.body).should == [
        { "id"=>1,
          "name"=>"foo",
          "label"=>"bar",
          "asset_no"=>"baz",
          "type"=>"Modem",
          "tags"=>['baz',"buz.zub.zub2"],
          "rack"=>{'__ref__'=>'/rack/3'},
          "spaces"=>[{"unit_no"=>0, "atom"=>"interior"}],
          "ports"=>[],
          "ips"=>[],
          "parent_objects"=>[],
          "child_objects"=>[],
          "has_problems"=>false,
          "attributes"=>{},
          "__self__"=>"/object/1"
        }]
    end

    it "should be possible by tag" do
      use_fixture_set
      resp = mock_get('/object?tags._contains=baz')
      resp.should be_ok
      MultiJson.load(resp.body).should == [{
          "id"=>1,
          "name"=>"foo",
          "label"=>"bar",
          "asset_no"=>"baz",
          "type"=>"Modem",
          "tags"=>['baz','buz.zub.zub2'],
          "rack"=>{'__ref__'=>'/rack/3'},
          "spaces"=>[{"unit_no"=>0, "atom"=>"interior"}],
          "ports"=>[],
          "ips"=>[],
          "parent_objects"=>[],
          "child_objects"=>[],
          "has_problems"=>false,
          "attributes"=>{},
          "__self__"=>"/object/1"
        }]
    end

    it "should be possible by unqualified nested tag" do
      use_fixture_set
      resp = mock_get('/object?tags._contains=zub')
      resp.should be_ok
      MultiJson.load(resp.body).map{|i| i['id'] }.should == [1]
    end

    it "should be possible by qualified nested tag" do
      use_fixture_set
      resp = mock_get('/object?tags._contains=buz.zub')
      resp.should be_ok
      MultiJson.load(resp.body).map{|i| i['id'] }.should == [1]
    end

    it "should be possible by attribute" do
      use_fixture_set
      resp = mock_get('/object?attributes.attr=10')
      resp.should be_ok
      result = MultiJson.load(resp.body)
      result.should have(1).item
    end

    it "should be possible by uint attribute with null" do
      use_fixture_set
      resp = mock_get('/object?attributes.attr._is=_null')
      resp.should be_ok
      result = MultiJson.load(resp.body)
      result.should have(1).item
      result[0]['id'].should == 1
    end

    it "should be possible by dict attribute with null" do
      use_fixture_set
      resp = mock_get('/object?attributes.bttr._is=_null')
      resp.should be_ok
      result = MultiJson.load(resp.body)
      result.should have(1).item
      result[0]['id'].should == 1
    end

    it "should be possible by uint attribute with null" do
      use_fixture_set
      resp = mock_get('/object?attributes.attr._is._not=_null')
      resp.should be_ok
      result = MultiJson.load(resp.body)
      result.should have(1).item
      result[0]['id'].should == 2
    end

    it "should be possible by dict attribute with null" do
      use_fixture_set
      resp = mock_get('/object?attributes.bttr._is._not=_null')
      resp.should be_ok
      result = MultiJson.load(resp.body)
      result.should have(1).item
      result[0]['id'].should == 2
    end

    it "should be possible by dict attribute with null" do
      use_fixture_set
      resp = mock_get('/object?attributes.bttr._not=Yes&attributes.bttr._is._not=_null')
      resp.should be_ok
      result = MultiJson.load(resp.body)
      result.should have(1).item
      result[0]['id'].should == 2
    end

    it "should accept a _offset param" do
      use_fixture_set
      resp = mock_get('/object?_offset=1')
      resp.should be_ok
      resp['Link'].should == '</object?_offset=0&_limit=1>; rel="Previous"'
    end

    it "should accept a _limit param" do
      use_fixture_set
      resp = mock_get('/object?_limit=1')
      resp.should be_ok
      resp['Link'].should == '</object?_offset=1&_limit=1>; rel="Next"'
      resp['X-Collection-Size'].should == '2'
    end

    it "should return the collection size" do
      use_fixture_set
      resp = mock_get('/object')
      resp.should be_ok
      resp['X-Collection-Size'].should == '2'
    end

    it "should keep the query when offsetting" do
      use_fixture_set
      resp = mock_get('/object?_limit=1&id._lt=100000')
      resp.should be_ok
      resp['Link'].should == '</object?id._lt=100000&_offset=1&_limit=1>; rel="Next"'
    end

    it "works with ips versions" do
      use_fixture_set
      resp = mock_get('/object?ips._contains.version=6')
      resp.should be_ok
      result = MultiJson.load(resp.body)
      result.should == [
        { "id"=>2,
          "name"=>"server",
          "label"=>nil,
          "asset_no"=>"baaz",
          "type"=>"Server",
          "tags"=>[],
          "rack"=>nil,
          "spaces"=>[],
          "ports"=>[],
          "ips"=>[
            { "object"=>{"__ref__"=>"/object/2"},
              "version"=>4,
              "type"=>"regular",
              "ip"=>{"__type__"=>"IPAddress", "address"=>"0.0.0.1", "prefix"=>32, "netmask"=>"255.255.255.255", "version"=>4},
              "name"=>"eth0",
              "__type__"=>"IPAllocation",
              "address"=>"00000001"},
            { "object"=>{"__ref__"=>"/object/2"},
              "version"=>6,
              "type"=>"regular",
              "ip"=>{"__type__"=>"IPAddress", "address"=>"3132:3334::", "prefix"=>128, "netmask"=>"ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff", "version"=>6},
              "name"=>"eth0",
              "__type__"=>"IPAllocation",
              "address"=>"31323334000000000000000000000000"
            }
          ],
          "parent_objects"=>[],
          "child_objects"=>[],
          "has_problems"=>false,
          "attributes"=>{"attr"=>10, "bttr"=>"No"},
          "__self__"=>"/object/2"
      }]
    end

    it "works with v4 ips" do
      use_fixture_set
      resp = mock_get('/object?ips._contains.ip=0.0.0.1')
      resp.should be_ok
      result = MultiJson.load(resp.body)
      result.should have(1).item
    end

    it "works with v6 ips" do
      use_fixture_set
      resp = mock_get('/object?ips._contains.ip=3132%3A3334%3A%3A')
      resp.should be_ok
      result = MultiJson.load(resp.body)
      result.should have(1).item
    end

  end

  describe "editing" do

    include ObjectRouter
    include ObjectFixtures

    it "should refuse batch updating the name" do

      use_fixture_set

      expect{
        resp = mock_patch('/object', 'name' => 'bar' )
        resp.should_not be_ok
      }.to raise_error

    end

    it "should be possible to set the name" do

      use_fixture_set

      resp = mock_patch('/object/1', 'name' => 'bar' )
      resp.should be_ok

      Model::RackObject[1].name.should == 'bar'

    end

    it "should be possible to set the type" do

      use_fixture_set

      resp = mock_patch('/object/1', 'type' => 'MediaConverter' )
      resp.should be_ok

      Model::RackObject[1].type.dict_value.should == 'MediaConverter'

    end

    it "should be possible to set the rack" do

      pending

      use_fixture_set

      resp = mock_patch('/object/1', 'rack' => '/rack/2' )
      resp.should be_ok

    end

    it "should be possible to set the spaces" do

      pending

      use_fixture_set

      resp = mock_patch('/object/1', 'spaces' => [{"unit_no"=>10, "atom"=>"front"}] )
      resp.should be_ok

    end

    it "should be possible to add tags" do

      use_fixture_set

      resp = mock_patch('/object/1', 'tags' => {'_push' => 'baz.zab' } )
      resp.should be_ok

      Model::RackObject[1].tags.should have(3).items

    end

    it "should be possible to remove tags" do

      use_fixture_set

      mock_patch('/object/1', 'tags' => {'_push' => 'baz.zab' } )

      resp = mock_patch('/object/1', 'tags' => {'_drop' => 'baz.zab' } )
      resp.should be_ok

      Model::RackObject[1].tags.should have(2).items

    end

    it "should be possible to set the tags" do

      use_fixture_set

      resp = mock_patch('/object/1', 'tags' => [ 'baz.zab' ] )
      resp.should be_ok

      Model::RackObject[1].tags.should have(1).items
      Model::RackObject[1].tags.first.tag.should == 'zab'

    end

    it "should be possible to set the tags to an empty list" do

      use_fixture_set

      resp = mock_patch('/object/1', 'tags' => [] )
      resp.should be_ok

      Model::RackObject[1].tags.should have(0).items

    end

    it "should be possible to set attributes" do

      use_fixture_set
      expect do
        resp = mock_patch('/object/2', 'attributes' => {'FQDN' => 'x.y.com'} )
        resp.should be_ok
      end.to change{Model::RackObject[2].attributes.size}.by(1)

      Model::RackObject[2].attributes[0].string_value.should == 'x.y.com'

    end

    it "should be possible to add a port" do

      use_fixture_set

      resp = mock_patch('/object/2', 'ports' => {'_push' => {'name' => 'foo', 'type' => '1000Base-T'} } )
      resp.should be_ok

      Model::RackObject[2].ports.should have(1).item
      Model::RackObject[2].ports[0].name.should == 'foo'

    end

    it "should be possible to add mulitple ports" do

      use_fixture_set

      resp = mock_patch('/object/2', 'ports' => {'_push' => [ {'name' => 'foo', 'type' => '1000Base-T'}, {'name' => 'bar', 'type' => '1000Base-T'} ] } )
      resp.should be_ok

      Model::RackObject[2].ports.should have(2).items

    end

    it "should be possible to remove a port" do

      use_fixture_set

      mock_patch('/object/2', 'ports' => {'_push' => [ {'name' => 'foo', 'type' => '1000Base-T'}, {'name' => 'bar', 'type' => '1000Base-T'} ] } )

      resp = mock_patch('/object/2', 'ports' => {'_drop' => {'name' => 'foo', 'type' => '1000Base-T'} } )
      resp.should be_ok

      Model::RackObject[2].ports.should have(1).item

    end

    it "should return a 400 for overlapping queries" do
      use_fixture_set
      resp = mock_get('/object?a=a&a.b=b')
      expect(resp).to be_client_error
    end

  end

  describe "creation" do

    include ObjectRouter
    include ObjectFixtures

    it "should be possible to create an object" do
      pending
      use_fixture_set

      resp = mock_post('/object')
      resp.status.should == 201 # HTTP Created

      resp.headers.should have_key('Location')
      resp.headers['Location'].should =~ %r{/object/\d+}

    end

  end

end

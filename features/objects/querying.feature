Feature: Object querying
  Objects are the backbone of racktables. There are some preconfigured object 
  types like Server and VMs but you can also add more.

  The racktables api provides the "/object" namespace to create/retrieve/update
  /delete them.

  Scenario: Get all objects when nothing is present
    Well if no objects are present, the response to /object is simply an empty 
    array.
    When I request "/object"
    Then the response should be:
    """json
    []
    """

  Scenario: Inserting the smallest possible object
    Creating objects requires just the name and the type of the object.
    When I POST this to "/object":
      """json
      {
        "name": "foo",
        "type": "VM"
      }
      """
    And I follow the Location header
    Then the response should be like:
      """json-like
      {
        "name" : "foo",
        "type" : "VM",
        ...
      }
      """

  Scenario: Inserting an object with some more data.
    Objects have a hash of attributes. This hash is not freeform, it is 
    configurable per object type. The FQDN for example is allowed for most types.
    When I POST this to "/object":
      """json
      {
        "name" : "foo",
        "type" : "VM",
        "attributes" : {
          "FQDN" : "foo.example.com"
        }
      }
      """
    And I follow the Location header
    Then the response should be like:
      """json-like
      {
        "name" : "foo",
        "type" : "VM",
        "attributes" : {
          "FQDN" : "foo.example.com"
        },
        ...
      }
      """

  Scenario: Get all objects after inserting one
    Objects have some more properties like tags and ports. After inserting one 
    you can see that it appears in the list of objects.
    When I POST this to "/object":
      """json
      {
        "name": "foo",
        "type": "VM"
      }
      """
    And I request "/object"
    Then the response should be like:
      """json-like
      [
        {
           "name"   : "foo",
           "type"   : "VM",
           "tags"   : [],
           "ports"  : [],
           "rack"   : null,
           "spaces" : [],
           "attributes" : {},
           "has_problems" : false,
           "ips"    : []
           ...
        }
      ]
      """

  Scenario: A simple search for objects after inserting some
    Let's do some basic searching. First I insert some data.
    To search for something I can use a query string like
    "?<property>=<expected value>".
    Given I have POSTed this to "/object":
      """json
      {
        "name": "foo",
        "type": "VM"
      }
      """
    And I have also POSTed this to "/object":
      """json
      {
        "name": "bar",
        "type": "VM"
      }
      """
    When I request "/object?name=foo"
    Then the response should be like:
      """json-like
      [
        {
           "name"   : "foo",
           "type"   : "VM",
           ...
        }
      ]
      """

  Scenario: A simple search for null
    The null value is somewhat special as it cannot be encoded in urls 
    properly. To check for null you can use "?<property>._is=_null".
    Given I have POSTed this to "/object":
      """json
      {
        "name": "foo",
        "type": "VM",
        "asset_no": null
      }
      """
    And I have also POSTed this to "/object":
      """json
      {
        "name": "bar",
        "type": "VM",
        "asset_no": "bar"
      }
      """
    When I request "/object?asset_no._is=_null"
    Then the response should be like:
      """json-like
      [
        {
           "name"   : "foo",
           "type"   : "VM",
           "asset_no" : null,
           ...
        }
      ]
      """

  Scenario: A simple search for null
    The null value is somewhat special as it cannot be encoded in urls 
    properly. To check for null you can use "?<property>._is=_null".
    Given I have POSTed this to "/object":
      """json
      {
        "name": "foo",
        "type": "VM",
        "asset_no": null
      }
      """
    And I have also POSTed this to "/object":
      """json
      {
        "name": "bar",
        "type": "VM",
        "asset_no": "bar"
      }
      """
    When I request "/object?asset_no._is=_null"
    Then the response should be like:
      """json-like
      [
        {
           "name"   : "foo",
           "type"   : "VM",
           "asset_no" : null,
           ...
        }
      ]
      """




  Scenario: Updating attributes
    Given I have POSTed this to "/object":
      """json
      {
        "name": "foo",
        "type": "VM",
        "attributes" : {
          "FQDN" : "foo.bar.com",
          "contact person" : "Foo Bar"
        }
      }
      """
    When I PATCH this to "/object?name=foo":
      """json
      {
        "attributes" : {
          "FQDN" : "foo.rab.com"
        }
      }
      """
    And I request "/object"
    Then the response should be like:
      """json-like
      [
        {
           "name"   : "foo",
           "type"   : "VM",
           "attributes" : {
             "FQDN" : "foo.rab.com",
             "contact person" : "Foo Bar"
           },
           ...
        }
      ]
      """

  Scenario: Adding a port
    Given I have POSTed this to "/object":
      """json
      {
        "name": "foo",
        "type": "VM"
      }
      """
    When I PATCH this to "/object?name=foo":
      """json
      {
        "ports":
        {
          "_push":
          {
            "name": "eth0",
            "type": "1000Base-T",
            "l2address": "005056bc449b"
          }
        }
      }
      """
    And I request "/object"
    Then the response should be like:
      """json-like
      [
        {
           "name"   : "foo",
           "type"   : "VM",
           "ports" : [
              {
                "name": "eth0",
                "type": "1000Base-T",
                "l2address": "005056bc449b",
                ...
              }
            ],
            ...
        }
      ]
      """




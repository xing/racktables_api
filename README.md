# Racktables API

[![Build Status](https://travis-ci.org/xing/racktables_api.png?branch=master)](https://travis-ci.org/xing/racktables_api)
[![Coverage Status](https://coveralls.io/repos/xing/racktables_api/badge.png)](https://coveralls.io/r/xing/racktables_api)

REST access to racktables objects. With this REST api you can request your racktables objects in JSON format to use them in your scripts. You can generate DNS or DHCP configs right from your Racktables data.

You can find some examples, what we are doing with this in Falks ( @fstern ) [slides](http://www.slideshare.net/falkstern/racktables-osdc) - currently in german only

## INSTALL
Please refer to the [INSTALL.md](https://github.com/xing/racktables_api/blob/master/INSTALL.md)

## API Client Usage

First, generate a key:secret pair if you haven't done yet:

 	https://racktables-api.example.com/_meta/api-key/

My key:secret pair is stored in my .bashrc in a variable $RTUSER and I'm using an alias rtcurl:

	rtcurl='curl -s --user '

To parse the JSON output on the CLI, I recommend the usage of [jq](http://stedolan.github.io/jq/).

### Examples

#### Getting a list of real servers with hostname \*build\*

	$ rtcurl $RTUSER 'https://racktables-api.example.com/object?type._match=Server&attributes.FQDN._match=build' | jq '.[] | .name'
	"buildhost-1.datacenter"
	"deb-build-1.datacenter"
	"qabuild-1.office"

#### Getting a list of virtual servers with hostname \*build\*

	$ rtcurl $RTUSER 'https://racktables-api.example.com/object?type._match=VM&attributes.FQDN._match=build' | jq '.[] | .name'
	"qabuild-1.datacenter"
	"opsbuild-1.datacenter"
	"opsbuild-1.office"
	"opsbuild-2.datacenter"
	"opsbuild-2.office"
	"opsbuild-3.office"

#### Getting a complete object

	$ rtcurl $RTUSER 'https://racktables-api.example.com/object?attributes.FQDN._match=buildhost-1.datacenter' | jq '.[]'
	{
	  "__self__": "/object/782",
	  "attributes": {
	    "State": "Under construction",
	    "not-ready": "Yes",
	    "Needs Backup": "No",
	    "iLO user": "admin",
	    "FQDN": "buildhost-1.datacenter.example.com",
	    "HW type": "IBM xSeries%GPASS%3650",
	    "OEM S/N 1": "KDXDAFF"
	  },
	  "has_problems": false,
	  "ips": [
	    {
	      "address": "0a040606",
	      "__type__": "IPAllocation",
	      "name": "bond0",
	      "ip": {
	        "version": 4,
	        "netmask": "255.255.255.255",
	        "prefix": 32,
	        "address": "10.4.6.6",
	        "__type__": "IPAddress"
	      },
	      "type": "regular",
	      "version": 4,
	      "object": {
	        "__ref__": "/object/782"
	      }
	    },
	    {
	      "address": "0a054079",
	      "__type__": "IPAllocation",
	      "name": "mgmt0",
	      "ip": {
	        "version": 4,
	        "netmask": "255.255.255.255",
	        "prefix": 32,
	        "address": "10.5.64.121",
	        "__type__": "IPAddress"
	      },
	      "type": "regular",
	      "version": 4,
	      "object": {
	        "__ref__": "/object/782"
	      }
	    }
	  ],
	  "ports": [
	    {
	      "__self__": "/port/14653",
	      "id": 14653,
	      "name": "eth0",
	      "label": "1",
	      "object": {
	        "__ref__": "/object/782"
	      },
	      "type": "1000Base-T",
	      "remote_port": {
	        "__self__": "/port/1308",
	        "id": 1308,
	        "name": "eth115/1/19",
	        "label": "",
	        "object": {
	          "__ref__": "/object/110"
	        },
	        "type": "1000Base-T",
	        "remote_port": {
	          "__ref__": "/port/14653"
	        },
	        "l2address": null,
	        "cable": "C6B-012-100035"
	      },
	      "l2address": "00215E5291E8",
	      "cable": "C6B-012-100035"
	    },
	    {
	      "__self__": "/port/14654",
	      "id": 14654,
	      "name": "eth1",
	      "label": "2",
	      "object": {
	        "__ref__": "/object/782"
	      },
	      "type": "1000Base-T",
	      "remote_port": {
	        "__self__": "/port/1334",
	        "id": 1334,
	        "name": "eth115/1/19",
	        "label": "",
	        "object": {
	          "__ref__": "/object/111"
	        },
	        "type": "1000Base-T",
	        "remote_port": {
	          "__ref__": "/port/14654"
	        },
	        "l2address": null,
	        "cable": "C6B-012-100036"
	      },
	      "l2address": "00215E5291EA",
	      "cable": "C6B-012-100036"
	    },
	    {
	      "__self__": "/port/14655",
	      "id": 14655,
	      "name": "mgmt0",
	      "label": "mgmt",
	      "object": {
	        "__ref__": "/object/782"
	      },
	      "type": "1000Base-T",
	      "remote_port": {
	        "__self__": "/port/2556",
	        "id": 2556,
	        "name": "fa0/19",
	        "label": "",
	        "object": {
	          "__ref__": "/object/166"
	        },
	        "type": "100Base-TX",
	        "remote_port": {
	          "__ref__": "/port/14655"
	        },
	        "l2address": null,
	        "cable": "C6R-012-100009"
	      },
	      "l2address": "00215E2AC845",
	      "cable": "C6R-012-100009"
	    },
	    {
	      "__self__": "/port/14651",
	      "id": 14651,
	      "name": "ps1",
	      "label": "",
	      "object": {
	        "__ref__": "/object/782"
	      },
	      "type": "AC-C14",
	      "remote_port": {
	        "__self__": "/port/6032",
	        "id": 6032,
	        "name": "outlet-6",
	        "label": null,
	        "object": {
	          "__ref__": "/object/269"
	        },
	        "type": "AC-C13",
	        "remote_port": {
	          "__ref__": "/port/14651"
	        },
	        "l2address": null,
	        "cable": "PBlack-010-100184"
	      },
	      "l2address": null,
	      "cable": "PBlack-010-100184"
	    },
	    {
	      "__self__": "/port/14652",
	      "id": 14652,
	      "name": "ps2",
	      "label": "",
	      "object": {
	        "__ref__": "/object/782"
	      },
	      "type": "AC-C14",
	      "remote_port": {
	        "__self__": "/port/6061",
	        "id": 6061,
	        "name": "outlet-6",
	        "label": null,
	        "object": {
	          "__ref__": "/object/270"
	        },
	        "type": "AC-C13",
	        "remote_port": {
	          "__ref__": "/port/14652"
	        },
	        "l2address": null,
	        "cable": "PGrey-010-100170"
	      },
	      "l2address": null,
	      "cable": "PGrey-010-100170"
	    }
	  ],
	  "id": 782,
	  "name": "buildhost-1.datacenter",
	  "label": "buildhost-1.datacenter",
	  "asset_no": "20002134",
	  "type": "Server",
	  "tags": [
	    "datacenter",
	    "ParentTag.ops",
	    "ParentTag.build",
	  ],
	  "rack": {
	    "__ref__": "/rack/1678"
	  },
	  "spaces": [
	    {
	      "atom": "front",
	      "unit_no": 36
	    },
	    {
	      "atom": "interior",
	      "unit_no": 36
	    },
	    {
	      "atom": "rear",
	      "unit_no": 36
	    },
	    {
	      "atom": "front",
	      "unit_no": 37
	    },
	    {
	      "atom": "interior",
	      "unit_no": 37
	    },
	    {
	      "atom": "rear",
	      "unit_no": 37
	    }
	  ]
	}

#### Getting names and tags

	$ rtcurl $RTUSER 'https://racktables-api.example.com/object?attributes.FQDN._match=build' | jq '.[] | [.name,.tags]'
	[
	  "buildhost-1.datacenter",
	  [
	    "datacenter",
	    "ParentTag.ops",
	    "ParentTag.build",
	  ]
	]
	[
	  "deb-build-1.datacenter",
	  [
	    "datacenter",
	    "ParentTag.build"
	  ]
	]
	[
	  "qabuild-1.office",
	  [
	    "office",
	    "ParentTag.build",
	    "ParentTag.qa",
	  ]
	]
	[
	  "qabuild-1.datacenter",
	  [
	    "datacenter",
	    "ParentTag.build",
	    "ParentTag.qa"
	  ]
	]
	[
	  "opsbuild-1.datacenter",
	  [
	    "datacenter",
	    "ParentTag.ops",
	    "ParentTag.build"
	  ]
	]
	[
	  "opsbuild-1.office",
	  [
	    "office",
	    "ParentTag.build",
	  ]
	]
	[
	  "opsbuild-2.datacenter",
	  [
	    "datacenter",
	    "ParentTag.ops",
	    "ParentTag.build",
	  ]
	]
	[
	  "opsbuild-2.office",
	  [
	    "office",
	    "ParentTag.ops",
	    "ParentTag.build",
	  ]
	]
	[
	  "opsbuild-3.office",
	  [
	    "office",
	    "ParentTag.ops",
	    "ParentTag.build",
	  ]
	]

## AUTHOR
Hannes Georg - XING AG 2013

## LICENSE
The MIT License (MIT)

Copyright (c) 2013 XING AG

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

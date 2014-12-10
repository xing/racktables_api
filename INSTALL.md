Installation
===============

rt-api requires installing racktables first to initialize the database.

Quick and dirty
---------------

- Clone this repository
- Install ruby >= 1.9.3 and bundler
- Run `bundle install`
- Run `bundle exec env RACKTABLES_DB=mysql2://<user>:<password>@<mysqlhost>/<database> rackup`
- Api should now listen on port 9292

This version is only intended to get a quick look at the api. It is in no way production grade as it lacks proper authentication and just uses the default web server which is pretty crappy.

Somewhat cleaner
---------------

- Chose a rack ruby server, I recomend puma,unicorn or passenger
- Write Gemfile like this:

    ```ruby
    source 'https://rubygems.org'
    gem 'racktables_api', :git => 'git://github.com/xing/racktables_api.git'
    gem 'mysql2'  # or any connector sequel can use for mysql ( http://sequel.rubyforge.org/rdoc/files/doc/opening_databases_rdoc.html )
    gem 'unicorn' # or puma or none if you use passenger
    ```

- Write a config.ru like this if you want to use the LDAPAuthenticator:

    ```ruby
    require 'bundler/setup'
    require 'racktables_api'
    require 'ldap_authenticator'
    use LDAPAuthenticator, :host => '<your ldap host>', :domain => '<your domain>'
    run RacktablesApi.to_app
    ```

- Write a config.ru like this if you want to use the RacktablesAuthenticator:

    ```ruby
    require 'bundler/setup'
    require 'racktables_api'
    require 'racktables_authenticator'
    use RacktablesAuthenticator
    run RacktablesApi.to_app
    ```

- Install your bundle
- Make sure the server has the RACKTABLES_DB env variable and all the other config stuff it needs.
- Fire!

This config has ldap authentication and a proper webserver. You can customize the stack further to your needs, but it should work like this.

Enabling api-keys
----------------------

- To use api keys add this table to your racktables db:

    ```sql
    CREATE TABLE `api_key` (
      `key` char(32) NOT NULL,
      `owner` varchar(100) NOT NULL,
      `description` text NOT NULL,
      `secret` char(32) NOT NULL,
      PRIMARY KEY (`key`),
      KEY `owner` (`owner`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    ```

- Restart your server.

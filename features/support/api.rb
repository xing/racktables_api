$LOAD_PATH << File.expand_path('../..', File.dirname(__FILE__))
require 'spec/helper'
require 'spec/helper/object_router'

Around do |_, inner|
  DB.transaction(:rollback=>:always, &inner)
end

World(ObjectRouter)

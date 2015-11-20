require 'midb'
require_relative ("./addin")

# First, create a config hash
cc = Hash.new
# We're using SQLite3, so we only need to specify the engine and endpoints
cc["dbengine"] = :sqlite3
cc["serves"] = ["users.json"] # file in ./json/
# Init the engine, given db='test' and starting HTTP status=420 WAIT
engine = MIDB::API::Engine.new("test", "420 WAIT", cc)
engine.start()
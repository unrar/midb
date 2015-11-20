require 'midb'
require_relative ("./addin")

# Create the configuration for my API
cc = Hash.new
cc["dbengine"] = :sqlite3
# New engine binding to the "test" database
engy = MIDB::API::Engine.new("test", "100 WAITING", cc)
engy.start

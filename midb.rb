#!/usr/bin/env ruby
## midb: middleware for databases! ##
# 08/27/15, unrar
require './app/controllers/server_controller'

# this will probably go to the binary when this becomes a gem

# Pass the arguments to the controler, we don't want the action here ;-)
ServerController.args = ARGV

# And start the server
ServerController.init()

# Save data in case we didn't actually start the server but change the configuration
ServerController.save()

require 'midb/server_model'
require 'midb/server_view'
require 'midb/errors_view'
require 'midb/security_controller'

require 'yaml'
require 'socket'
require 'uri'
require 'json'
require 'sqlite3'

module MIDB
  # This controller controls the behavior of the midb server.
  class ServerController
    # Variable declaration
    class << self
      # args[] => passed by the binary
      # config => configuration array saved and loaded from .midb.yaml
      # db => the database we're using
      # http_status => the HTTP status, sent by the model
      attr_accessor :args, :config, :db, :http_status, :port
    end
    # status => server status
    # serves[] => JSON files served by the API
    @http_status = "200 OK"
    @args = []
    @config = Hash.new()
    @port = 8081

    # Method: init
    # Decide what to do according to the supplied command!
    def self.init()
      # We should have at least one argument, which can be `run` or `serve`
      MIDB::ErrorsView.die(:noargs) if @args.length < 1

      # Load the config
      if File.file?(".midb.yaml")
        @config = YAML.load_file(".midb.yaml")
      else
        # If the file doesn't exist, we need to bootstrap
        MIDB::ErrorsView.die(:bootstrap) if @args[0] != "help" && args[0] != "bootstrap"
      end

      case @args[0]

      # Command: help
      # Shows the help
      when "help"
        if @args.length > 1
          case @args[1]
          when "bootstrap"
            MIDB::ServerView.help(:bootstrap)
          when "set"
            MIDB::ServerView.help(:set)
          when "start"
            MIDB::ServerView.help(:start)
          when "serve"
            MIDB::ServerView.help(:serve)
          when "unserve"
            MIDB::ServerView.help(:unserve)
          else
            MIDB::ErrorsView.die(:no_help)
          end
        else
          MIDB::ServerView.help(:list)
        end

      # Command: bootstrap
      # Create config file and initial directories
      when "bootstrap"
        if File.file?(".midb.yaml")
          MIDB::ErrorsView.die(:already_project)
        else
          # If the file doesn't exist it, create it with the default stuff
          @config["serves"] = []
          @config["status"] = :asleep    # The server is initially asleep
          @config["apikey"] = "midb-api" # This should be changed, it's the private API key
          @config["dbengine"] = :sqlite3  # SQLite is the default engine
          # Default DB configuration for MySQL and other engines
          @config["dbhost"] = "localhost"
          @config["dbport"] = 3306
          @config["dbuser"] = "nobody"
          @config["dbpassword"] = "openaccess" 
          File.open(".midb.yaml", 'w') do |l|
            l.write @config.to_yaml
          end
          # Create json/ and db/ directory if it doesn't exist 
          Dir.mkdir("json") unless File.exists?("json")
          Dir.mkdir("db") unless File.exists?("db")
          MIDB::ServerView.info(:bootstrap)
        end
    
      # Command: set
      # Sets configuration factors.
      when "set"
        # Check syntax
        MIDB::ErrorsView.die(:syntax) if @args.length < 2
        subset = @args[1].split(":")[0]
        subcmd = @args[1].split(":")[1]
        set = @args.length < 3 ? false : true
        setter = @args[2] if set
        case subset
        when "db"
          # DB Config
          case subcmd
          when "engine"
            if set
              @config["dbengine"] = case setter.downcase
                                    when "sqlite3" then :sqlite3
                                    when "mysql" then :mysql
                                    else :undef
                                    end
              if @config["dbengine"] == :undef
                MIDB::ErrorsView.die(:unsupported_engine)
                @config["dbengine"] = :sqlite3
              end
            end
            MIDB::ServerView.out_config(:dbengine)
          when "host"
            @config["dbhost"] = setter if set
            MIDB::ServerView.out_config(:dbhost)
          when "port"
            @config["dbport"] = setter if set
            MIDB::ServerView.out_config(:dbport)
          when "user"
            @config["dbuser"] = setter if set
            MIDB::ServerView.out_config(:dbuser)
          when "password"
            @config["dbpassword"] = setter if set
            MIDB::ServerView.out_config(:dbpassword)
          else
            MIDB::ErrorsView.die(:synax)
          end
        when "api"
          case subcmd
          when "key"
            @config["apikey"] = setter if set
            MIDB::ServerView.out_config(:apikey)
          end
        else
          MIDB::ErrorsView.die(:syntax)
        end


      # Command: start
      # Starts the server
      when "start"
        # Check syntax
        MIDB::ErrorsView.die(:syntax) if @args.length < 2
        MIDB::ErrorsView.die(:syntax) if @args[1].split(":")[0] != "db"
        # Is the server already started?
        MIDB::ErrorsView.die(:server_already_started) if @config["status"] == :running
        # Are any files being served?
        MIDB::ErrorsView.die(:no_serves) if @config["serves"].length == 0
        # If it successfully starts, change our status and notify thru view
        @args.each do |arg|
          if arg.split(":")[0] == "db"
            @db = arg.split(":")[1]
          elsif arg.split(":")[0] == "port"
            @port = arg.split(":")[1]
          end
        end

        if self.start(@port)
          @config["status"] = :running
          MIDB::ServerView.success()
        else
          MIDB::ErrorsView.die(:server_error)
        end

      # Command: serve
      # Serves a JSON file
      when "serve"
        # Check if there's a second argument
        MIDB::ErrorsView.die(:syntax) if @args.length < 2
        # Is the server running? It shouldn't
        MIDB::ErrorsView.die(:server_already_started) if @config["status"] == :running
        # Is there such file as @args[1]?
        MIDB::ErrorsView.die(:file_404) unless File.file?("./json/" + @args[1])
        # Is the file a JSON file?
        MIDB::ErrorsView.die(:not_json) unless File.extname(@args[1]) == ".json"
        # Is the file already loaded?
        MIDB::ErrorsView.die(:json_exists) if @config["serves"].include? @args[1]

        # Tests passed, so let's add the file to the served list!
        @config["serves"].push @args[1]
        MIDB::ServerView.show_serving()

      # Command: unserve
      # Stop serving a JSON file.
      when "unserve"
        # Check if there's a second argument
        MIDB::ErrorsView.die(:syntax) if @args.length < 2
        # Is the server running? It shouldn't
        MIDB::ErrorsView.die(:server_already_started) if @config["status"] == :running
        # Is the file already loaded?
        MIDB::ErrorsView.die(:json_not_exists) unless @config["serves"].include? @args[1]

        # Delete it!
        @config["serves"].delete @args[1]
        MIDB::ServerView.show_serving()

      # Command: stop
      # Stops the server.
      when "stop"
        # Is the server running?
        MIDB::ErrorsView.die(:server_not_running) unless @config["status"] == :running

        @config["status"] = :asleep
        MIDB::ServerView.server_stopped()
      end
    end

    # Method: start
    # Starts the server on the given port (default: 8080)
    def self.start(port=8081)
      serv = TCPServer.new("localhost", port)
      MIDB::ServerView.info(:start, port)

      # Manage the requests
      loop do
        socket = serv.accept
        MIDB::ServerView.info(:incoming_request, socket.addr[3])

        request = self.parse_request(socket.gets)

        # Get a hash with the headers
        headers = {}
        while line = socket.gets.split(' ', 2)
          break if line[0] == "" 
          headers[line[0].chop] = line[1].strip
        end
        data = socket.read(headers["Content-Length"].to_i)


        MIDB::ServerView.info(:request, request)
        response_json = Hash.new()

        # Endpoint syntax: ["", FILE, ID, (ACTION)]
        endpoint = request[1].split("/")
        ep_file = endpoint[1]

        method = request[0]
        endpoints = [] # Valid endpoints

        # Load the JSON served files
        @config["serves"].each do |js|
          # The filename is a valid endpoint
          endpoints.push File.basename(js, ".*")
        end

        # Load the endpoints
        found = false
        endpoints.each do |ep|
          if ep_file == ep
            found = true
            MIDB::ServerView.info(:match_json, ep)
            # Analyze the request and pass it to the model
            if method == "GET"
              case endpoint.length
              when 2
                # No ID has been specified. Return all the entries
                # Pass it to the model and get the JSON
                response_json = MIDB::ServerModel.get_all_entries(@db, ep).to_json
              when 3
                # An ID has been specified. Should it exist, return all of its entries.
                response_json = MIDB::ServerModel.get_entries(@db, ep, endpoint[2]).to_json
              end
            else
              # An action has been specified. We're going to need HTTP authentification here.
              MIDB::ServerView.info(:auth_required)

              if (not headers.has_key? "Authentication") ||
                 (not MIDB::SecurityController.check?(headers["Authentication"], data, @config["apikey"]))
                @http_status = "401 Unauthorized"
                response_json = MIDB::ServerView.json_error(401, "Unauthorized").to_json
                MIDB::ServerView.info(:no_auth)

              else
                MIDB::ServerView.info(:auth_success)
                if method == "POST"
                  response_json = MIDB::ServerModel.post(@db, ep, data).to_json
                else
                  if endpoint.length >= 3
                    if method == "DELETE"
                      response_json = MIDB::ServerModel.delete(@db, ep, endpoint[2]).to_json 
                    elsif method == "PUT"
                      response_json = MIDB::ServerModel.put(@db, ep, endpoint[2], data).to_json
                    end
                  else
                    @http_status = "404 Not Found"
                    response_json = MIDB::ServerView.json_error(404, "Must specify an ID.").to_json
                  end
                end
              end
            end
            MIDB::ServerView.info(:response, response_json)
            # Return the results via HTTP
            socket.print "HTTP/1.1 #{@http_status}\r\n" +
                        "Content-Type: text/json\r\n" +
                        "Content-Length: #{response_json.size}\r\n" +
                        "Connection: close\r\n"
            socket.print "\r\n"
            socket.print response_json
            socket.print "\r\n"
            MIDB::ServerView.info(:success)
          end
        end
        unless found
          MIDB::ServerView.info(:not_found)
          response = MIDB::ServerView.json_error(404, "Invalid API endpoint.").to_json

          socket.print "HTTP/1.1 404 Not Found\r\n" +
                       "Content-Type: text/json\r\n" +
                       "Content-Length: #{response.size}\r\n" +
                       "Connection: close\r\n"
          socket.print "\r\n"
          socket.print response
        end
      end
    end

    # Method: parse_request
    # Parses an HTTP requests and returns an array [method, uri]
    def self.parse_request(req)
      [req.split(" ")[0], req.split(" ")[1]]
    end

    # Method: save
    # Saves config to .midb.yaml
    def self.save()
      File.open(".midb.yaml", 'w') do |l|
        l.write @config.to_yaml
      end
    end
  end
end
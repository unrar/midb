require './app/models/server'
require './app/views/server'
require './app/views/errors'
require './app/controllers/security_controller'

require 'yaml'
require 'socket'
require 'uri'
require 'json'
require 'sqlite3'

# This controller controls the behavior of the midb server.
class ServerController
  # Variable declaration
  class << self
    # args[] => passed by the binary
    # config => configuration array saved and loaded from .midb.yaml
    # db => the database we're using
    # http_status => the HTTP status, sent by the model
    attr_accessor :args, :config, :db, :http_status
  end
  # status => server status
  # serves[] => JSON files served by the API
  @http_status = "200 OK"
  @args = []
  @config = Hash.new()

  # Method: init
  # Decide what to do according to the supplied command!
  def self.init()
    # We should have at least one argument, which can be `run` or `serve`
    ErrorsView.die(:noargs) if @args.length < 1

    # Load the config
    if File.file?(".midb.yaml")
      @config = YAML.load_file(".midb.yaml")
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
    end

    case @args[0]

    # Command: set
    # Sets configuration factors.
    when "set"
      # Check syntax
      ErrorsView.die(:syntax) if @args.length < 2
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
              ErrorsView.die(:unsupported_engine)
              @config["dbengine"] = :sqlite3
            end
          end
          ServerView.out_config(:dbengine)
        when "host"
          @config["dbhost"] = setter if set
          ServerView.out_config(:dbhost)
        when "port"
          @config["dbport"] = setter if set
          ServerView.out_config(:dbport)
        when "user"
          @config["dbuser"] = setter if set
          ServerView.out_config(:dbuser)
        when "password"
          @config["dbpassword"] = setter if set
          ServerView.out_config(:dbpassword)
        else
          ErrorsView.die(:synax)
        end
      when "api"
        case subcmd
        when "key"
          @config["apikey"] = setter if set
          ServerView.out_config(:apikey)
        end
      else
        ErrorsView.die(:syntax)
      end


    # Command: start
    # Starts the server
    when "start"
      # Check syntax
      ErrorsView.die(:syntax) if @args.length < 2
      ErrorsView.die(:syntax) if @args[1].split(":")[0] != "db"
      # Is the server already started?
      ErrorsView.die(:server_already_started) if @config["status"] == :running
      # Are any files being served?
      ErrorsView.die(:no_serves) if @config["serves"].length == 0
      # If it successfully starts, change our status and notify thru view
      @db = @args[1].split(":")[1]
      if self.start()
        @config["status"] = :running
        ServerView.success()
      else
        ErrorsView.die(:server_error)
      end

    # Command: serve
    # Serves a JSON file
    when "serve"
      # Check if there's a second argument
      ErrorsView.die(:syntax) if @args.length < 2
      # Is the server running? It shouldn't
      ErrorsView.die(:server_already_started) if @config["status"] == :running
      # Is there such file as @args[1]?
      ErrorsView.die(:file_404) unless File.file?("./json/" + @args[1])
      # Is the file a JSON file?
      ErrorsView.die(:not_json) unless File.extname(@args[1]) == ".json"
      # Is the file already loaded?
      ErrorsView.die(:json_exists) if @config["serves"].include? @args[1]

      # Tests passed, so let's add the file to the served list!
      @config["serves"].push @args[1]
      ServerView.show_serving()

    # Command: unserve
    # Stop serving a JSON file.
    when "unserve"
      # Check if there's a second argument
      ErrorsView.die(:syntax) if @args.length < 2
      # Is the server running? It shouldn't
      ErrorsView.die(:server_already_started) if @config["status"] == :running
      # Is the file already loaded?
      ErrorsView.die(:json_not_exists) unless @config["serves"].include? @args[1]

      # Delete it!
      @config["serves"].delete @args[1]
      ServerView.show_serving()

    # Command: stop
    # Stops the server.
    when "stop"
      # Is the server running?
      ErrorsView.die(:server_not_running) unless @config["status"] == :running

      @config["status"] = :asleep
      ServerView.server_stopped()
    end
  end

  # Method: start
  # Starts the server on the given port (default: 8080)
  def self.start(port=8081)
    serv = TCPServer.new("localhost", port)
    ServerView.info(:start, port)

    # Manage the requests
    loop do
      socket = serv.accept
      ServerView.info(:incoming_request, socket.addr[3])

      request = self.parse_request(socket.gets)

      # Get a hash with the headers
      headers = {}
      while line = socket.gets.split(' ', 2)
        break if line[0] == "" 
        headers[line[0].chop] = line[1].strip
      end
      data = socket.read(headers["Content-Length"].to_i)


      ServerView.info(:request, request)
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
          ServerView.info(:match_json, ep)
          # Analyze the request and pass it to the model
          if method == "GET"
            case endpoint.length
            when 2
              # No ID has been specified. Return all the entries
              # Pass it to the model and get the JSON
              response_json = ServerModel.get_all_entries(@db, ep).to_json
            when 3
              # An ID has been specified. Should it exist, return all of its entries.
              response_json = ServerModel.get_entries(@db, ep, endpoint[2]).to_json
            end
          else
            # An action has been specified. We're going to need HTTP authentification here.
            unless SecurityController.check?(headers["Authentication"], data, @config["apikey"])
              @http_status = "403 Forbidden"
              jsr = Hash.new()
              jsr["error"] = Hash.new()
              jsr["error"]["errno"] = 403
              jsr["error"]["msg"] = "Unsuccessful authentication - access forbidden."
              response_json = jsr.to_json
            else
              if method == "POST"
                response_json = ServerModel.post(@db, ep, data).to_json
              else
                if endpoint.length >= 3
                  if method == "DELETE"
                    response_json = ServerModel.delete(@db, ep, endpoint[2]) 
                  elsif method == "PUT"
                    response_json = ServerModel.put(@db, ep, endpoint[2], data)
                  end
                else
                  jsr = Hash.new()
                  jsr["error"] = Hash.new()
                  jsr["error"]["errno"] = 404
                  jsr["error"]["msg"] = "ID not specified."
                end
              end
            end
          end
          ServerView.info(:response, response_json)
          # Return the results via HTTP
          socket.print "HTTP/1.1 #{@http_status}\r\n" +
                      "Content-Type: text/json\r\n" +
                      "Content-Length: #{response_json.size}\r\n" +
                      "Connection: close\r\n"
          socket.print "\r\n"
          socket.print response_json
          socket.print "\r\n"
          ServerView.info(:success)
        end
      end
      unless found
        ServerView.info(:not_found)
        message = Hash.new()
        message["error"] = Hash.new()
        message["error"]["errno"] = 404
        message["error"]["msg"] = "The API endpoint isn't valid."
        response = message.to_json


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

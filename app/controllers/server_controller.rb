require './app/models/server'
require './app/views/server'
require './app/views/errors'

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
    attr_accessor :args, :config, :db
  end
  # status => server status
  # serves[] => JSON files served by the API
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
      @config["status"] = :asleep  # The server is initially asleep
      File.open(".midb.yaml", 'w') do |l|
        l.write @config.to_yaml
      end
    end

    case @args[0]

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
      endpoints.each do |ep|
        if ep_file == ep
          ServerView.info(:match_json, ep)
          # Analyze the request and pass it to the model
          case endpoint.length
          when 2
            # No ID has been specified. Return all the entries
            # Pass it to the model and get the JSON
            response_json = ServerModel.get_all_entries(@db, ep).to_json
          end
          ServerView.info(:response, response_json)
          # Return the results via HTTP
          socket.print "HTTP/1.1 200 OK\r\n" +
                      "Content-Type: text/json\r\n" +
                      "Content-Length: #{response_json.size}\r\n" +
                      "Connection: close\r\n"
          socket.print "\r\n"
          socket.print response_json
          socket.print "\r\n"
          ServerView.info(:success)
        end
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

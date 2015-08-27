require './app/models/default'
require './app/views/server'
require './app/views/errors'
require 'yaml'

# This controller controls the behavior of the midb server.
class ServerController
  # Variable declaration
  class << self
    # args[] => passed by the binary
    # config => configuration array saved and loaded from .midb.yaml
    attr_accessor :args, :config
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
      # Is the server already started?
      ErrorsView.die(:server_already_started) if @config["status"] == :running
      # Are any files being served?
      ErrorsView.die(:no_serves) if @config["serves"].length == 0
      # If it successfully starts, change our status and notify thru view
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
      ErrorsView.die(:not_json) unless File.extname(@args[1]) == "json"
      # Is the file already loaded?
      ErrorsView.die(:json_exists) if @config["serves"].include? @args[1]

      # Tests passed, so let's add the file to the served list!
      @config["serves"].push @args[1]
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

  def self.start()
    puts "Im ur server and im on fire"
    return true
  end

  # Method: save
  # Saves config to .midb.yaml
  def self.save()
    File.open(".midb.yaml", 'w') do |l|
      l.write @config.to_yaml
    end
  end
end

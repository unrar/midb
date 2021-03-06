require 'midb/server_model'
require 'midb/server_view'
require 'midb/errors_view'
require 'midb/security_controller'
require 'midb/serverengine_controller'
require 'midb/hooks'

require 'yaml'
require 'socket'
require 'uri'
require 'json'
require 'sqlite3'

module MIDB
  module API
    # This controller controls the behavior of the midb server.
    class Controller
      # Attribute declaration here
      #
      # @!attribute args
      #   @return [Array<String>] Arguments passed to the binary.
      # @!attribute config
      #   @return [Hash] Contains the project's configuration, saved in .midb.yaml
      # @!attribute db
      #   @return [String] Database name (if SQLite is the engine, file name without extension)
      # @!attribute http_status
      #   @return [String] HTTP status code and string representation for the header
      # @!attribute port
      #   @return [Fixnum] Port where the server will listen.
      # @!attribute h
      #   @return [Object] MIDB::API::Hooks instance
      attr_accessor :args, :config, :db, :http_status, :port, :hooks

      # Convert an on/off string to a boolean
      #
      # @param text [String] Text to convert to bool
      def to_bool(text) 
        if text == "on" || text == "true" || text == "yes"
          return true
        elsif text == "off" || text == "false" || text == "no"
          return false
        else
          return nil
        end
      end

      # Constructor for this controller.
      #
      # @param args [Array<String>] Arguments passed to the binary.
      def initialize(args, hooks=nil)
        # Default values
        #
        # @see #http_status
        # @see #args
        # @see #config
        # @see #port
        @http_status = "200 OK"
        @args = args
        @config = Hash.new()
        @port = 8081
        if hooks == nil
          # At some point someone should register this.
          @hooks = MIDB::API::Hooks.new
        else
          @hooks = hooks
        end
      end

      #####################
      #  Server commands  #
      #####################

      # $ midb help
      #
      # Show some help for either midb or a command.
      def do_help()
        if @args.length > 1
          case @args[1]
          when "bootstrap"
            MIDB::Interface::Server.help(:bootstrap)
          when "set"
            MIDB::Interface::Server.help(:set)
          when "start"
            MIDB::Interface::Server.help(:start)
          when "serve"
            MIDB::Interface::Server.help(:serve)
          when "unserve"
            MIDB::Interface::Server.help(:unserve)
          else
            MIDB::Interface::Errors.die(:no_help)
          end
        else
          MIDB::Interface::Server.help(:list)
        end
      end

      # $ midb bootstrap
      #
      # Bootstrap a new midb project in the active directory.
      def do_bootstrap()
        if File.file?(".midb.yaml")
          MIDB::Interface::Errors.die(:already_project)
        else
          # If the file doesn't exist it, create it with the default stuff
          @config["serves"] = []
          @config["status"] = :asleep    # The server is initially asleep
          @config["apikey"] = "midb-api" # This should be changed, it's the private API key
          # Optional API key for GET methods (void by default)
          @config["apigetkey"] = nil
          @config["dbengine"] = :sqlite3  # SQLite is the default engine
          # Default DB configuration for MySQL and other engines
          @config["dbhost"] = "localhost"
          @config["dbport"] = 3306
          @config["dbuser"] = "nobody"
          @config["dbpassword"] = "openaccess" 
          # New settings - privacy
          @config["privacyget"] = false
          @config["privacypost"] = true
          @config["privacyput"] = true
          @config["privacydelete"] = true

          File.open(".midb.yaml", 'w') do |l|
            l.write @config.to_yaml
          end
          # Create json/ and db/ directory if it doesn't exist 
          Dir.mkdir("json") unless File.exists?("json")
          Dir.mkdir("db") unless File.exists?("db")
          MIDB::Interface::Server.info(:bootstrap)
        end
      end

      # $ midb set
      #
      # Set the config for the project.
      # Check syntax
      def do_set()
        MIDB::Interface::Errors.die(:syntax) if @args.length < 2
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
                MIDB::Interface::Errors.die(:unsupported_engine)
                @config["dbengine"] = :sqlite3
              end
            end
            MIDB::Interface::Server.out_config(:dbengine, @config)
          when "host"
            @config["dbhost"] = setter if set
            MIDB::Interface::Server.out_config(:dbhost, @config)
          when "port"
            @config["dbport"] = setter if set
            MIDB::Interface::Server.out_config(:dbport, @config)
          when "user"
            @config["dbuser"] = setter if set
            MIDB::Interface::Server.out_config(:dbuser, @config)
          when "password"
            @config["dbpassword"] = setter if set
            MIDB::Interface::Server.out_config(:dbpassword, @config)
          else
            MIDB::Interface::Errors.die(:syntax)
          end
        when "api"
          case subcmd
          when "key"
            @config["apikey"] = setter if set
            MIDB::Interface::Server.out_config(:apikey, @config)
          when "getkey"
            if setter == "nil"
              @config["apigetkey"] = nil if set
            else
              @config["apigetkey"] = setter if set
            end
            MIDB::Interface::Server.out_config(:apigetkey, @config)
          end
        when "privacy"
          case subcmd
          when "get"
            @config["privacyget"] = self.to_bool(setter) if set
            MIDB::Interface::Server.out_config(:privacyget, @config)
          when "post"
            @config["privacypost"] = self.to_bool(setter) if set
            MIDB::Interface::Server.out_config(:privacypost, @config)
          when "put"
            @config["privacyput"] = self.to_bool(setter) if set
            MIDB::Interface::Server.out_config(:privacyput, @config)
          when "delete"
            @config["privacydelete"] = self.to_bool(setter) if set
            MIDB::Interface::Server.out_config(:privacydelete, @config)
          else 
            MIDB::Interface::Errors.die(:syntax)
          end
        else
          MIDB::Interface::Errors.die(:syntax)
        end
      end

      # $ midb start
      #
      # Start the server (call the loop)
      def do_start()
        # Check syntax
        MIDB::Interface::Errors.die(:syntax) if @args.length < 2
        MMIDB::Interface::Errors.die(:syntax) if @args[1].split(":")[0] != "db"
        # Is the server already started?
        MIDB::Interface::Errors.die(:server_already_started) if @config["status"] == :running
        # Are any files being served?
        MIDB::Interface::Errors.die(:no_serves) if @config["serves"].length == 0
        # If it successfully starts, change our status and notify thru view
        @args.each do |arg|
          if arg.split(":")[0] == "db"
            @db = arg.split(":")[1]
          elsif arg.split(":")[0] == "port"
            @port = arg.split(":")[1]
          end
        end

        # Call the server engine and supply the (non)existing hooks
        eng = MIDB::API::Engine.new(@db, @http_status, @config, @hooks)
        if eng.start(@port)
          @config["status"] = :running
          MIDB::Interface::Server.success()
        else
          MIDB::Interface::Errors.die(:server_error)
        end
      end

      # $ midb serve
      #
      # Serve a JSON file
      def do_serve()
        # Check if there's a second argument
        MIDB::Interface::Errors.die(:syntax) if @args.length < 2
        # Is the server running? It shouldn't
        MIDB::Interface::Errors.die(:server_already_started) if @config["status"] == :running
        # Is there such file as @args[1]?
        MIDB::Interface::Errors.die(:file_404) unless File.file?("./json/" + @args[1])
        # Is the file a JSON file?
        MMIDB::Interface::Errors.die(:not_json) unless File.extname(@args[1]) == ".json"
        # Is the file already loaded?
        MIDB::Interface::Errors.die(:json_exists) if @config["serves"].include? @args[1]

        # Tests passed, so let's add the file to the served list!
        @config["serves"].push @args[1]
        MIDB::Interface::Server.show_serving(@config)
      end

      # $ midb unserve
      #
      # Stop serving a JSON file
      def self.do_unserve()
        # Check if there's a second argument
        MIDB::Interface::Errors.die(:syntax) if @args.length < 2
        # Is the server running? It shouldn't
        MIDB::Interface::Errors.die(:server_already_started) if @config["status"] == :running
        # Is the file already loaded?
        MIDB::Interface::Errors.die(:json_not_exists) unless @config["serves"].include? @args[1]

        # Delete it!
        @config["serves"].delete @args[1]
        MIDB::Interface::Server.show_serving(@config)
      end

      # $ midb stop
      #
      # Stop the server in case it's running in the background.
      def do_stop()
        # Is the server running?
        MIDB::Interface::Errors.die(:server_not_running) unless @config["status"] == :running

        @config["status"] = :asleep
        MIDB::Interface::Server.server_stopped()
      end



      # $ midb
      #
      # Decide the behavior of the server in function of the arguments.
      def init()
        # We should have at least one argument, which can be `run` or `serve`
        MIDB::Interface::Errors.die(:noargs) if @args.length < 1

        # Load the config
        if File.file?(".midb.yaml")
          @config = YAML.load_file(".midb.yaml")
        else
          # If the file doesn't exist, we need to bootstrap
          MIDB::Interface::Errors.die(:bootstrap) if @args[0] != "help" && args[0] != "bootstrap"
        end

        case @args[0]

        # Command: help
        when "help"
          self.do_help()

        # Command: bootstrap
        when "bootstrap"
          self.do_bootstrap()
      
        # Command: set
        when "set"
          self.do_set()


        # Command: start
        when "start"
          self.do_start()

        # Command: serve
        # Serves a JSON file
        when "serve"
          self.do_serve()

        # Command: unserve
        # Stop serving a JSON file.
        when "unserve"
          self.do_unserve()

        # Command: stop
        # Stops the server.
        when "stop"
          self.do_stop()
        end
      end

      # Method: save
      # Saves config to .midb.yaml
      def save()
        File.open(".midb.yaml", 'w') do |l|
          l.write @config.to_yaml
        end
      end
    end
  end
end
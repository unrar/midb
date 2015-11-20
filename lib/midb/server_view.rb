module MIDB
  module Interface
    # View that handles everything from the server
    class Server

      def self.success()
        puts "Success!"
      end

      # Return a JSON error response
      #
      # @param errno [Fixnum] Error number.
      # @param msg [String] Error message.
      def self.json_error(errno, msg)
        return {"error" => {"errno" => errno, "msg" => msg}}
      end

      # Shows the files being served
      #
      # @param cnf [Array<String>] The configuration from the server.
      def self.show_serving(cnf)
        puts "The follow JSON files are being served as APIs:"
        cnf["serves"].each do |serv|
          puts "- #{serv}"
        end
      end

      # Notice that the server has been stopped.
      def self.server_stopped()
        puts "The server has been successfully stopped!"
      end

      # Send some info
      # 
      # @param what [Symbol] What to show the information for.
      # @param info [Array<String>] Extra information needed for the message.
      def self.info(what, info=nil)
        msg = case what
              when :start then "Server started on port #{info}. Listening for connections..."
              when :incoming_request then "> Incoming request from #{info}."
              when :request then ">> Request method: #{info[0]}\n>>> Endpoint: #{info[1]}"
              when :match_json then ">> The request matched a JSON file: #{info}.json\n>> Creating response..."
              when :response then ">> Sending JSON response (RAW):\n#{info}"
              when :success then "> Successfully managed this request!"
              when :not_found then "> Invalid endpoint - sending a 404 error."
              when :auth_required then ">> Authentication required. Checking for the HTTP header..."
              when :no_auth then ">> No authentication header - sending a 401 error."
              when :auth_success then ">> Successfully authenticated the request."
              when :bootstrap then "> Successfully bootstraped!"
              end
        puts msg
      end

      # Output some config
      #
      # @param what [Symbol] What to show the config for.
      # @param cnf [Array<String>] The array for the config.
      def self.out_config(what, cnf)
        msg = case what
              when :dbengine then "Database engine: #{cnf['dbengine']}."
              when :dbhost then "Database server host: #{cnf['dbhost']}."
              when :dbport then "Database server port: #{cnf['dbport']}."
              when :dbuser then "Database server user: #{cnf['dbuser']}."
              when :dbpassword then "Database server password: #{cnf['dbpassword']}."
              when :apikey then "Private API key: #{cnf['apikey']}"
              else "Error??"
              end
        puts msg
      end

      # Shows the help
      #
      # @param what [Symbol] What to show the help for.
      def self.help(what)
        case what
        when :list
          puts "midb has several commands that you can use. For detailed information, see `midb help command`."
          puts " "
          puts "bootstrap\tCreate the basic files and directories that midb needs to be ran in a folder."
          puts "set\tModify this project's settings. See the detailed help for a list of options."
          puts "serve\tServes a JSON file - creates an API endpoint."
          puts "unserve\tStops serving a JSON file - the endpoint is no longer valid."
          puts "start\tStarts an API server. See detailed help for more."
        when :bootstrap
          puts "This command creates the `.midb.yaml` config file, and the `db` and `json` directories if they don't exist."
          puts "You must bootstrap before running any other commands."
        when :set
          puts "Sets config options. If no value is given, it shows the current value."
          puts "db:host\tHost name of the database (for MySQL)"
          puts "db:user\tUsername for the database (for MySQL)"
          puts "db:password\tPassword for the database (for MySQL)"
          puts "db:engine\t(sqlite3, mysql) Changes the database engine."
          puts "api:key\tChanges the private API key, used for authentication over HTTP."
        when :serve
          puts "This command will create an API endpoint pointing to a JSON file in the json/ directory."
          puts "It will support GET, POST, PUT and DELETE requests."
          puts "For detailed information on how to format your file, see the GitHub README and/or wiki."
        when :unserve
          puts "Stops serving a JSON file under the json/ directory."
        when :start
          puts "Starts the server. You must run the serve/unserve commands beforehand, so to set some endpoints."
          puts "Options:"
          puts "db:DATABASE\tSets DATABASE as the database where to get the data. Mandatory."
          puts "port:PORT\tSets PORT as the port where the server will listen to. Default: 8081."
        end
      end
    end
  end
end

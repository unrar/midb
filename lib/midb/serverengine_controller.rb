require 'midb/server_controller'
require 'midb/server_model'
require 'midb/server_view'
require 'midb/errors_view'
require 'midb/security_controller'
require 'midb/hooks'

require 'yaml'
require 'socket'
require 'uri'
require 'json'
require 'sqlite3'

module MIDB
  module API
    # @author unrar
    # This class handles runs the server engine using sockets and a loop.
    class Engine
      # Attribute declaration here
      # @!attribute config
      #   @return [Hash] Contains the project's configuration, saved in .midb.yaml
      # @!attribute db
      #   @return [String] Database name (if SQLite is the engine, file name without extension)
      # @!attribute http_status
      #   @return [String] HTTP status code and string representation for the header
      # @!attribute h
      #   @return [Object] MIDB::API::Hooks instance
      attr_accessor :config, :db, :http_status, :hooks


      # Constructor
      #
      # @param db   [String] Database to which the server will bind.
      # @param stat [Fixnum] HTTP Status
      # @param cnf  [Hash] Config from the server controller.
      def initialize(db, stat, cnf, hooks=nil)
        @config = cnf
        @db = db
        @http_status = stat
        if hooks == nil
          @hooks = MIDB::API::Hooks.new
        else
          @hooks = hooks
        end
      end

      # Starts the server on a given port (default: 8081)
      #
      # @param port [Fixnum] Port to which the server will listen.
      def start(port=8081)
        serv = TCPServer.new("localhost", port)
        MIDB::Interface::Server.info(:start, port)

        # Manage the requests
        loop do
          socket = serv.accept
          MIDB::Interface::Server.info(:incoming_request, socket.addr[3])

          request = self.parse_request(socket.gets)

          # Get a hash with the headers
          headers = {}
          while line = socket.gets.split(' ', 2)
            break if line[0] == "" 
            headers[line[0].chop] = line[1].strip
          end
          data = socket.read(headers["Content-Length"].to_i)


          MIDB::Interface::Server.info(:request, request)
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
              MIDB::Interface::Server.info(:match_json, ep)
              # Create the model
              dbop = MIDB::API::Model.new(ep, @db, self)
              # Analyze the request and pass it to the model
              if method == "GET"
                case endpoint.length
                when 2
                  # No ID has been specified. Return all the entries
                  # Pass it to the model and get the JSON
                  response_json = dbop.get_all_entries().to_json
                when 3
                  # An ID has been specified. Should it exist, return all of its entries.
                  response_json = dbop.get_entries(endpoint[2]).to_json
                end
              else
                # An action has been specified. We're going to need HTTP authentification here.
                MIDB::Interface::Server.info(:auth_required)

                if (not headers.has_key? "Authentication") ||
                   (not MIDB::API::Security.check?(headers["Authentication"], data, @config["apikey"]))
                  @http_status = "401 Unauthorized"
                  response_json = MIDB::Interface::Server.json_error(401, "Unauthorized").to_json
                  MIDB::Interface::Server.info(:no_auth)

                else
                  MIDB::Interface::Server.info(:auth_success)
                  if method == "POST"
                    response_json = dbop.post(data).to_json
                  else
                    if endpoint.length >= 3
                      if method == "DELETE"
                        response_json = dbop.delete(endpoint[2]).to_json 
                      elsif method == "PUT"
                        response_json = dbop.put(endpoint[2], data).to_json
                      end
                    else
                      @http_status = "404 Not Found"
                      response_json = MIDB::Interface::Server.json_error(404, "Must specify an ID.").to_json
                    end
                  end
                end
              end
              MIDB::Interface::Server.info(:response, response_json)
              # Return the results via HTTP
              socket.print "HTTP/1.1 #{@http_status}\r\n" +
                          "Content-Type: text/json\r\n" +
                          "Content-Length: #{response_json.size}\r\n" +
                          "Connection: close\r\n"
              socket.print "\r\n"
              socket.print response_json
              socket.print "\r\n"
              MIDB::Interface::Server.info(:success)
            end
          end
          unless found
            MIDB::Interface::Server.info(:not_found)
            response = MIDB::Interface::Server.json_error(404, "Invalid API endpoint.").to_json

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
      def parse_request(req)
        [req.split(" ")[0], req.split(" ")[1]]
      end
    end
  end
end
require 'midb/server_model'
require 'midb/server_view'
require 'midb/errors_view'
require 'midb/security_controller'
require 'midb/server_controller'

require 'yaml'
require 'socket'
require 'uri'
require 'json'
require 'sqlite3'

module MIDB
  # @author unrar
  # This class handles runs the server engine using sockets and a loop.
  class ServerEngineController
    # Attribute declaration here
    class << self
      # @!attribute config
      #   @return [Hash] Contains the project's configuration, saved in .midb.yaml
      # @!attribute db
      #   @return [String] Database name (if SQLite is the engine, file name without extension)
      # @!attribute http_status
      #   @return [String] HTTP status code and string representation for the header
      attr_accessor :config, :db, :http_status
    end
    # Copy these values from the server controller
    @http_status = MIDB::ServerController.http_status
    @config = MIDB::ServerController.config
    @db = MIDB::ServerController.db

    # Starts the server on a given port (default: 8081)
    #
    # @param port [Fixnum] Port to which the server will listen.
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
  end
end
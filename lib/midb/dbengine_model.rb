require 'midb/server_controller'
require 'sqlite3'
require 'mysql2'

module MIDB
  # @author unrar
  # This class handles engine-dependent database operations
  class DbengineModel

    # @!attribute engine
    #   @return [Symbol] The database engine being used
    # @!attribute host
    #   @return [String] Host name where the database is located
    # @!attribute uname
    #   @return [String] Username for the database
    # @!attribute pwd
    #   @return [String] Password for the database.
    # @!attribute port
    #   @return [Fixnum] Port for the database
    # @!attribute db
    #   @return [String] Name of the database  
    attr_accessor :engine, :host, :uname, :pwd, :port, :db

    # Constructor - initializes the attributes with the configuration from ServerController
    def initialize()
      @engine = MIDB::ServerController.config["dbengine"]
      @host = MIDB::ServerController.config["dbhost"]
      @port = MIDB::ServerController.config["dbport"]
      @uname = MIDB::ServerController.config["dbuser"]
      @pwd = MIDB::ServerController.config["dbpassword"]
      @db = MIDB::ServerController.db
    end

    # Connect to the specified database
    #
    # @return [SQLite3::Database, Mysql2::Client] A resource referencing to the database
    def connect()
      # Connect to an SQLite3 database
      if @engine == :sqlite3
        sq = SQLite3::Database.open("./db/#{@db}.db")
        sq.results_as_hash = true
        return sq
      # Connect to a MySQL database
      elsif @engine == :mysql
        return Mysql2::Client.new(:host => @host, :username => @uname, :password => @pwd, :database => @db)
      end
    end

    # Perform a query to the database.
    #
    # @param res [SQLite3::Database, Mysql2::Client] An existing database resource.
    # @param query [String] The SQL query to be ran.
    #
    # @return [Array, Hash] Returns an array of hashes for SQLite3 or a hash for MySQL
    def query(res, query)
      if @engine == :sqlite3
        return res.execute(query)
      elsif @engine == :mysql
        return res.query(query)
      end
    end

    # Extract a field from a query, because different engines return different types (see #query)
    #
    # @param result [Array, Hash] The result of a query obtained via #query
    # @param field [String] The name of the field to be extracted.
    #
    # @return [String, Fixnum] The field extracted from a query
    def extract(result, field)
      if @engine == :sqlite3
        return result[0][field] || result[field]
      elsif @engine == :mysql
        result.each do |row|
          return row[field]
        end
      end
    end
  end
end